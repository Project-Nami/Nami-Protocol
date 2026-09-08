// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BatcherAccountProxy} from "contracts/batcher/BatcherAccountProxy.sol";
import {BatcherAccountProxyFactory} from "contracts/batcher/BatcherAccountProxyFactory.sol";
import {SwapFacet} from "contracts/batcher/facets/versions/v1/SwapFacet.sol";
import {IBatcherAccountProxyFactory} from "contracts/batcher/interfaces/IBatcherAccountProxyFactory.sol";
import {AddressSetRegistry} from "contracts/utils/AddressSetRegistry.sol";
import {Test} from "forge-std/Test.sol";
import {MockWETH} from "test/mocks/MockWETH.sol";

/// @dev Lean fixture: registry, factory, SwapFacet and a wrapped native mock, owned by the test contract.
///      Version 1 mirrors the live deployment, one selector (swap_call) and no initializer.
abstract contract BatcherTestBase is Test {
    address internal deployer;
    address internal user1 = address(0x1001);
    address internal user2 = address(0x1002);
    address internal unauthorized = address(0x1003);

    address internal wNativeToken;
    BatcherAccountProxyFactory internal batcherFactory;
    AddressSetRegistry internal batcherSharedStorage;
    SwapFacet internal swapFacet;

    bytes4[] internal swapSelectors;
    uint256 internal constant DEFAULT_VERSION_ID = 1;

    bytes[] internal multicall_datas;

    // ═══════════════════════════════════════════════════════════════════════════
    // SETUP HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    function _setupBatcher() internal {
        deployer = address(this);
        wNativeToken = address(new MockWETH());
        batcherSharedStorage = new AddressSetRegistry(deployer);
        batcherFactory = new BatcherAccountProxyFactory(wNativeToken, deployer);
        swapFacet = new SwapFacet(address(batcherSharedStorage));

        swapSelectors.push(SwapFacet.swap_call.selector);
        _buildVersion(DEFAULT_VERSION_ID);
    }

    /// @dev Builds a draft with the SwapFacet and finalizes it. Asserts the finalized id matches
    ///      `expectedId` so callers can rely on stable ids.
    function _buildVersion(uint256 expectedId) internal {
        IBatcherAccountProxyFactory.FacetSelectors[] memory groups = new IBatcherAccountProxyFactory.FacetSelectors[](1);
        groups[0] = IBatcherAccountProxyFactory.FacetSelectors(address(swapFacet), swapSelectors);
        batcherFactory.addSelectorsToVersion(groups);
        uint256 id = batcherFactory.finalizeVersion();
        require(id == expectedId, "version id mismatch");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DEPLOYMENT HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    function _deployBatcherInstance(address _user) internal returns (BatcherAccountProxy) {
        return _deployBatcherInstanceForVersion(_user, DEFAULT_VERSION_ID);
    }

    function _deployBatcherInstanceForVersion(address _user, uint256 versionId) internal returns (BatcherAccountProxy) {
        // Compose deploy + setVersion atomically via the factory's Multicall.
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IBatcherAccountProxyFactory.deploy, ());
        data[1] = abi.encodeCall(IBatcherAccountProxyFactory.setVersion, (versionId));

        vm.prank(_user);
        batcherFactory.multicall(data);

        return BatcherAccountProxy(payable(batcherFactory.batchers(_user)));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TOKEN TRANSFER HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    function _pullTokensToBatcher(BatcherAccountProxy batcher, address token, uint256 amount) internal {
        address _user = batcher.user();
        vm.startPrank(_user);
        IERC20(token).approve(address(batcher), amount);
        batcher.pull(token, amount);
        vm.stopPrank();
    }

    function _dealAndApprove(address token, address user, address to, uint256 amount) internal {
        deal(address(token), user, amount);

        if (to != address(0)) {
            vm.prank(user);
            IERC20(token).approve(address(to), amount);
        }
    }

    function _fundBatcher(BatcherAccountProxy batcher, address token, uint256 amount) internal {
        deal(token, address(batcher), amount);
    }

    function _fundUserAndPull(BatcherAccountProxy batcher, address token, uint256 amount) internal {
        address _user = batcher.user();
        deal(token, _user, amount);
        _pullTokensToBatcher(batcher, token, amount);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MULTICALL DATA BUILDERS
    // ═══════════════════════════════════════════════════════════════════════════

    function _mc_clear() internal {
        delete multicall_datas;
    }

    function _mc_pull(address token, uint256 amount) internal {
        multicall_datas.push(abi.encodeCall(BatcherAccountProxy.pull, (token, amount)));
    }

    function _mc_push(address token, uint256 amount) internal {
        multicall_datas.push(abi.encodeCall(BatcherAccountProxy.push, (token, amount)));
    }

    function _mc_sweep(address token, uint256 minAmount) internal {
        multicall_datas.push(abi.encodeCall(BatcherAccountProxy.sweep, (token, minAmount)));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MULTICALL EXECUTION
    // ═══════════════════════════════════════════════════════════════════════════

    function _mc_execute(BatcherAccountProxy batcher)
        internal
        returns (bool[] memory successes, bytes[] memory results)
    {
        address _user = batcher.user();
        vm.prank(_user);
        (successes, results) = batcher.multicall(multicall_datas);
        _mc_clear();
    }

    function _mc_execute(BatcherAccountProxy batcher, bool[] memory allowRevert)
        internal
        returns (bool[] memory successes, bytes[] memory results)
    {
        address _user = batcher.user();
        vm.prank(_user);
        (successes, results) = batcher.multicall(multicall_datas, allowRevert);
        _mc_clear();
    }
}
