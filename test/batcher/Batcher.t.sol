// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {BatcherAccountProxy} from "contracts/batcher/BatcherAccountProxy.sol";
import {FacetBase} from "contracts/batcher/facets/base/FacetBase.sol";
import {SwapFacet} from "contracts/batcher/facets/versions/v1/SwapFacet.sol";
import {IBatcherAccountProxy} from "contracts/batcher/interfaces/IBatcherAccountProxy.sol";
import {
    Funding,
    IBatcherAccountProxyFactory,
    NFTFunding
} from "contracts/batcher/interfaces/IBatcherAccountProxyFactory.sol";
import {BatcherConstants} from "contracts/batcher/libraries/BatcherConstants.sol";
import {AddressSetRegistryIds} from "contracts/utils/constants/AddressSetRegistryIds.sol";
import {IAddressSetRegistry} from "contracts/utils/interfaces/IAddressSetRegistry.sol";
import {BatcherTestBase} from "test/base/BatcherTestBase.sol";
import "test/mocks/MockERC20.sol";
import {MockERC20Permit} from "test/mocks/MockERC20Permit.sol";

contract MockBatcherFacet {
    function batcherFacetId() external pure returns (bytes4) {
        return BatcherConstants.BATCHER_FACET_ID;
    }
}

contract MarkedFacet is FacetBase {
    function markedCall() external pure returns (uint256) {
        return 1;
    }
}

contract WrongMarkerFacet {
    function batcherFacetId() external pure returns (bytes4) {
        return 0xffffffff;
    }

    function wrongMarkerCall() external pure returns (uint256) {
        return 1;
    }
}

contract MissingMarkerFacet {
    function missingMarkerCall() external pure returns (uint256) {
        return 1;
    }
}

contract BatcherTest is BatcherTestBase {
    BatcherAccountProxy internal batcher1;
    BatcherAccountProxy internal batcher2;

    MockERC20 internal tokenA;
    MockERC20 internal tokenB;
    MockERC20Permit internal permitToken;

    MarkedFacet internal markedFacet;
    WrongMarkerFacet internal wrongMarkerFacet;
    MissingMarkerFacet internal missingMarkerFacet;

    // Funding fixture: accounts deployed without a version, approvals granted to the factory only.
    BatcherAccountProxy internal aliceAccount;
    BatcherAccountProxy internal bobAccount;
    MockERC721 internal collection;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA401);

    uint256 internal constant MINTED = 1000 ether;
    uint256 internal constant PULLED = 100 ether;
    uint256 internal constant ALICE_NFT = 1;
    uint256 internal constant BOB_NFT = 99;

    function setUp() public {
        _setupBatcher();

        address mockFacet = address(new MockBatcherFacet());
        vm.etch(address(0xABCD), mockFacet.code);
        vm.etch(address(0xAAAA), mockFacet.code);
        vm.etch(address(0xBBBB), mockFacet.code);
        vm.etch(address(0x1234), mockFacet.code);

        _mc_clear();

        tokenA = new MockERC20();
        tokenB = new MockERC20();
        permitToken = new MockERC20Permit();

        markedFacet = new MarkedFacet();
        wrongMarkerFacet = new WrongMarkerFacet();
        missingMarkerFacet = new MissingMarkerFacet();

        _setupFunding();
    }

    function _setupFunding() internal {
        vm.prank(alice);
        batcherFactory.deploy();
        aliceAccount = BatcherAccountProxy(payable(batcherFactory.batchers(alice)));

        vm.prank(bob);
        batcherFactory.deploy();
        bobAccount = BatcherAccountProxy(payable(batcherFactory.batchers(bob)));

        collection = new MockERC721();

        address[3] memory holders = [alice, bob, carol];
        for (uint256 i; i < holders.length; ++i) {
            tokenA.mint(holders[i], MINTED);
            tokenB.mint(holders[i], MINTED);
            vm.startPrank(holders[i]);
            tokenA.approve(address(batcherFactory), type(uint256).max);
            tokenB.approve(address(batcherFactory), type(uint256).max);
            collection.setApprovalForAll(address(batcherFactory), true);
            vm.stopPrank();
        }

        collection.mint(alice, ALICE_NFT);
        collection.mint(alice, ALICE_NFT + 1);
        collection.mint(bob, BOB_NFT);
    }

    /// @dev A swap against an unregistered router, so a routed call reaches the facet and stops there.
    function _unroutedSwap() internal view returns (SwapFacet.SwapParams memory) {
        return SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: 1,
            swapRouter: address(0x9999),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: 0,
            value: 0,
            swapData: ""
        });
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FACTORY TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_factory_deploy_andSetVersion_viaMulticall() external {
        batcher1 = _deployBatcherInstance(user1);

        assertEq(batcher1.user(), user1);
        assertEq(batcher1.owner(), address(batcherFactory));
        assertEq(batcherFactory.batchers(user1), address(batcher1));
        assertEq(batcherFactory.users(address(batcher1)), user1);
        assertEq(batcherFactory.proxyVersion(address(batcher1)), DEFAULT_VERSION_ID);
    }

    function test_factory_deploy_idempotent() external {
        batcher1 = _deployBatcherInstance(user1);

        vm.prank(user1);
        address instance = batcherFactory.deploy();
        assertEq(instance, address(batcher1));
    }

    function test_factory_deploy_doesNotAssignVersion() external {
        vm.prank(user1);
        address instance = batcherFactory.deploy();
        assertEq(batcherFactory.proxyVersion(instance), 0);
    }

    function test_factory_deploy_differentUsers() external {
        batcher1 = _deployBatcherInstance(user1);
        batcher2 = _deployBatcherInstance(user2);

        assertTrue(address(batcher1) != address(batcher2));
        assertEq(batcher1.user(), user1);
        assertEq(batcher2.user(), user2);
    }

    function test_factory_setVersion_revertVersionNotFinalized() external {
        batcher1 = _deployBatcherInstance(user1);

        // Force a new draft (id 2) by adding a no-op selector; never finalize it.
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("foo()"));
        batcherFactory.addSelectorsToVersion(_singletonGroup(address(0xABCD), selectors));
        uint256 id = batcherFactory.draftVersion();

        vm.prank(user1);
        vm.expectRevert(IBatcherAccountProxyFactory.VersionNotFinalized.selector);
        batcherFactory.setVersion(id);
    }

    function test_factory_setVersion_revertNoBatcher() external {
        vm.prank(user1);
        vm.expectRevert(IBatcherAccountProxyFactory.NoBatcher.selector);
        batcherFactory.setVersion(DEFAULT_VERSION_ID);
    }

    function test_factory_computeBatcherAddress() external {
        address predicted = batcherFactory.computeBatcherAddress(user1);
        batcher1 = _deployBatcherInstance(user1);

        assertEq(predicted, address(batcher1));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // VERSION LIFECYCLE TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_version_addSelectors_autoCreatesDraft() external {
        assertEq(batcherFactory.totalVersions(), 1);
        assertEq(batcherFactory.draftVersion(), 0);

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("foo()"));
        batcherFactory.addSelectorsToVersion(_singletonGroup(address(0xABCD), selectors));

        assertEq(batcherFactory.totalVersions(), 2);
        assertEq(batcherFactory.draftVersion(), 2);
    }

    function test_version_setVersionInitializer_autoCreatesDraft() external {
        assertEq(batcherFactory.draftVersion(), 0);
        batcherFactory.setVersionInitializer(address(0xABCD));
        assertEq(batcherFactory.draftVersion(), 2);
        (address init,,) = batcherFactory.versionInfo(2);
        assertEq(init, address(0xABCD));
    }

    function test_version_finalizeVersion_returnsIdAndClearsDraft() external {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("foo()"));
        batcherFactory.addSelectorsToVersion(_singletonGroup(address(0xABCD), selectors));
        assertEq(batcherFactory.draftVersion(), 2);

        uint256 finalizedId = batcherFactory.finalizeVersion();
        assertEq(finalizedId, 2);
        (, bool isFinalized,) = batcherFactory.versionInfo(2);
        assertTrue(isFinalized);
        assertEq(batcherFactory.draftVersion(), 0);
    }

    function test_version_finalizeVersion_revertNoDraft() external {
        vm.expectRevert(IBatcherAccountProxyFactory.NoDraft.selector);
        batcherFactory.finalizeVersion();
    }

    function test_version_addSelectorsThenFinalize_thenAddAgainStartsNewDraft() external {
        bytes4[] memory s1 = new bytes4[](1);
        s1[0] = bytes4(keccak256("foo()"));
        batcherFactory.addSelectorsToVersion(_singletonGroup(address(0xAAAA), s1));
        batcherFactory.finalizeVersion();

        bytes4[] memory s2 = new bytes4[](1);
        s2[0] = bytes4(keccak256("bar()"));
        batcherFactory.addSelectorsToVersion(_singletonGroup(address(0xBBBB), s2));
        assertEq(batcherFactory.draftVersion(), 3);
        assertEq(batcherFactory.totalVersions(), 3);
    }

    function _singletonGroup(address facet, bytes4[] memory selectors)
        internal
        pure
        returns (IBatcherAccountProxyFactory.FacetSelectors[] memory groups)
    {
        groups = new IBatcherAccountProxyFactory.FacetSelectors[](1);
        groups[0] = IBatcherAccountProxyFactory.FacetSelectors(facet, selectors);
    }

    function _singletonGroup(address facet, bytes4 selector)
        internal
        pure
        returns (IBatcherAccountProxyFactory.FacetSelectors[] memory groups)
    {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = selector;
        return _singletonGroup(facet, selectors);
    }

    function test_facet_batcherFacetIdReturnsBytes4Marker() external view {
        assertEq(markedFacet.batcherFacetId(), BatcherConstants.BATCHER_FACET_ID);
        assertEq(markedFacet.batcherFacetId(), bytes4(0x00000001));
    }

    function test_version_addSelectorsToVersion_acceptsMarkedFacet() external {
        bytes4 selector = MarkedFacet.markedCall.selector;

        batcherFactory.addSelectorsToVersion(_singletonGroup(address(markedFacet), selector));

        uint256 versionId = batcherFactory.draftVersion();
        assertEq(versionId, 2);
        assertEq(batcherFactory.versionSelectorToFacet(versionId, selector), address(markedFacet));
    }

    function test_version_addSelectorsToVersion_revertWrongMarker() external {
        vm.expectRevert(
            abi.encodeWithSelector(IBatcherAccountProxyFactory.InvalidBatcherFacet.selector, address(wrongMarkerFacet))
        );
        batcherFactory.addSelectorsToVersion(
            _singletonGroup(address(wrongMarkerFacet), WrongMarkerFacet.wrongMarkerCall.selector)
        );
    }

    function test_version_addSelectorsToVersion_revertMissingMarker() external {
        vm.expectRevert();
        batcherFactory.addSelectorsToVersion(
            _singletonGroup(address(missingMarkerFacet), MissingMarkerFacet.missingMarkerCall.selector)
        );
    }

    function test_version_addSelectorsToVersion_bindsSelectorAndPushesArray() external {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(keccak256("foo()"));
        selectors[1] = bytes4(keccak256("bar()"));

        batcherFactory.addSelectorsToVersion(_singletonGroup(address(0xABCD), selectors));
        uint256 id = batcherFactory.draftVersion();

        assertEq(batcherFactory.versionSelectorToFacet(id, selectors[0]), address(0xABCD));
        assertEq(batcherFactory.versionSelectorToFacet(id, selectors[1]), address(0xABCD));

        bytes4[] memory all = batcherFactory.versionSelectors(id, 0, 100);
        assertEq(all.length, 2);
        assertEq(all[0], selectors[0]);
        assertEq(all[1], selectors[1]);
    }

    function test_version_addSelectorsToVersion_batchedMultipleFacets() external {
        bytes4[] memory selectorsA = new bytes4[](1);
        selectorsA[0] = bytes4(keccak256("foo()"));
        bytes4[] memory selectorsB = new bytes4[](2);
        selectorsB[0] = bytes4(keccak256("bar()"));
        selectorsB[1] = bytes4(keccak256("baz()"));

        IBatcherAccountProxyFactory.FacetSelectors[] memory groups = new IBatcherAccountProxyFactory.FacetSelectors[](2);
        groups[0] = IBatcherAccountProxyFactory.FacetSelectors(address(0xAAAA), selectorsA);
        groups[1] = IBatcherAccountProxyFactory.FacetSelectors(address(0xBBBB), selectorsB);

        batcherFactory.addSelectorsToVersion(groups);
        uint256 id = batcherFactory.draftVersion();

        assertEq(batcherFactory.versionSelectorToFacet(id, selectorsA[0]), address(0xAAAA));
        assertEq(batcherFactory.versionSelectorToFacet(id, selectorsB[0]), address(0xBBBB));
        assertEq(batcherFactory.versionSelectorToFacet(id, selectorsB[1]), address(0xBBBB));
        assertEq(batcherFactory.versionSelectors(id, 0, 100).length, 3);
    }

    function test_version_addSelectorsToVersion_revertEmptyFacetGroups() external {
        IBatcherAccountProxyFactory.FacetSelectors[] memory groups = new IBatcherAccountProxyFactory.FacetSelectors[](0);

        vm.expectRevert(IBatcherAccountProxyFactory.EmptyFacetGroups.selector);
        batcherFactory.addSelectorsToVersion(groups);
    }

    function test_version_addSelectorsToVersion_revertEmptySelectors() external {
        bytes4[] memory selectors = new bytes4[](0);

        vm.expectRevert(IBatcherAccountProxyFactory.EmptySelectors.selector);
        batcherFactory.addSelectorsToVersion(_singletonGroup(address(0xABCD), selectors));
    }

    function test_version_addSelectorsToVersion_revertZeroFacet() external {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("foo()"));

        vm.expectRevert(IBatcherAccountProxyFactory.ZeroAddress.selector);
        batcherFactory.addSelectorsToVersion(_singletonGroup(address(0), selectors));
    }

    function test_version_addSelectorsToVersion_revertDuplicateAcrossFacets() external {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("foo()"));

        batcherFactory.addSelectorsToVersion(_singletonGroup(address(0xABCD), selectors));

        vm.expectRevert(
            abi.encodeWithSelector(IBatcherAccountProxyFactory.SelectorAlreadyInVersion.selector, selectors[0])
        );
        batcherFactory.addSelectorsToVersion(_singletonGroup(address(0x1234), selectors));
    }

    function test_version_removeSelectorsFromVersion_clearsBothMappingAndArray() external {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(keccak256("foo()"));
        selectors[1] = bytes4(keccak256("bar()"));
        batcherFactory.addSelectorsToVersion(_singletonGroup(address(0xABCD), selectors));
        uint256 id = batcherFactory.draftVersion();

        bytes4[] memory toRemove = new bytes4[](1);
        toRemove[0] = selectors[0];
        batcherFactory.removeSelectorsFromVersion(toRemove);

        // Mapping cleared
        assertEq(batcherFactory.versionSelectorToFacet(id, selectors[0]), address(0));
        // The other binding survives
        assertEq(batcherFactory.versionSelectorToFacet(id, selectors[1]), address(0xABCD));

        // Array no longer contains the removed selector
        bytes4[] memory all = batcherFactory.versionSelectors(id, 0, 100);
        assertEq(all.length, 1);
        assertEq(all[0], selectors[1]);
    }

    function test_version_removeSelectorsFromVersion_revertMissing() external {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("nonexistent()"));

        vm.expectRevert(abi.encodeWithSelector(IBatcherAccountProxyFactory.SelectorNotInVersion.selector, selectors[0]));
        batcherFactory.removeSelectorsFromVersion(selectors);
    }

    function test_version_setVersionPaused_revertNotFinalized() external {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("foo()"));
        batcherFactory.addSelectorsToVersion(_singletonGroup(address(0xABCD), selectors));
        uint256 id = batcherFactory.draftVersion();

        vm.expectRevert(IBatcherAccountProxyFactory.VersionNotFinalized.selector);
        batcherFactory.setVersionPaused(id, true);
    }

    function test_version_setVersionPaused_revertInvalidVersionId() external {
        vm.expectRevert(IBatcherAccountProxyFactory.InvalidVersionId.selector);
        batcherFactory.setVersionPaused(99, true);
    }

    function test_version_setVersionPaused_blocksFallbackRouting() external {
        batcher1 = _deployBatcherInstance(user1);

        // Pause the bound version
        batcherFactory.setVersionPaused(DEFAULT_VERSION_ID, true);

        // Any facet selector now reverts VersionPaused
        vm.prank(user1);
        vm.expectRevert(IBatcherAccountProxy.VersionPaused.selector);
        SwapFacet(address(batcher1)).swap_call(_unroutedSwap());
    }

    function test_version_setVersionPaused_directOpsStillWork() external {
        batcher1 = _deployBatcherInstance(user1);

        // Fund + approve
        uint256 amount = 100e18;
        deal(address(tokenA), user1, amount);
        vm.prank(user1);
        tokenA.approve(address(batcher1), amount);

        // Pause v1
        batcherFactory.setVersionPaused(DEFAULT_VERSION_ID, true);

        // Direct token ops still go through (top-level proxy functions, bypass fallback)
        vm.prank(user1);
        batcher1.pull(address(tokenA), amount);

        assertEq(IERC20(address(tokenA)).balanceOf(address(batcher1)), amount);
    }

    function test_version_setVersionPaused_unpauseRestoresRouting() external {
        batcher1 = _deployBatcherInstance(user1);

        batcherFactory.setVersionPaused(DEFAULT_VERSION_ID, true);
        batcherFactory.setVersionPaused(DEFAULT_VERSION_ID, false);

        // The call reaches the facet again, which rejects the unregistered router.
        vm.prank(user1);
        vm.expectRevert(SwapFacet.NotRouter.selector);
        SwapFacet(address(batcher1)).swap_call(_unroutedSwap());
    }

    function test_version_setVersionRescueSelector_keepsSelectorCallableWhilePaused() external {
        batcher1 = _deployBatcherInstance(user1);

        batcherFactory.setVersionPaused(DEFAULT_VERSION_ID, true);
        batcherFactory.setVersionRescueSelector(DEFAULT_VERSION_ID, SwapFacet.swap_call.selector, true);
        assertTrue(batcherFactory.versionRescueSelector(DEFAULT_VERSION_ID, SwapFacet.swap_call.selector));

        bytes4[] memory rescue = batcherFactory.versionRescueSelectors(DEFAULT_VERSION_ID, 0, 10);
        assertEq(rescue.length, 1);
        assertEq(rescue[0], SwapFacet.swap_call.selector);

        // Dispatch goes through to the facet despite the pause.
        vm.prank(user1);
        vm.expectRevert(SwapFacet.NotRouter.selector);
        SwapFacet(address(batcher1)).swap_call(_unroutedSwap());

        batcherFactory.setVersionRescueSelector(DEFAULT_VERSION_ID, SwapFacet.swap_call.selector, false);
        assertFalse(batcherFactory.versionRescueSelector(DEFAULT_VERSION_ID, SwapFacet.swap_call.selector));

        vm.prank(user1);
        vm.expectRevert(IBatcherAccountProxy.VersionPaused.selector);
        SwapFacet(address(batcher1)).swap_call(_unroutedSwap());
    }

    function test_version_setVersionRescueSelector_revertSelectorNotInVersion() external {
        bytes4 unknown = bytes4(keccak256("unknown()"));
        vm.expectRevert(abi.encodeWithSelector(IBatcherAccountProxyFactory.SelectorNotInVersion.selector, unknown));
        batcherFactory.setVersionRescueSelector(DEFAULT_VERSION_ID, unknown, true);
    }

    function test_version_setVersion_revertVersionPaused() external {
        batcher1 = _deployBatcherInstance(user1);

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("foo()"));
        batcherFactory.addSelectorsToVersion(_singletonGroup(address(0xABCD), selectors));
        uint256 id2 = batcherFactory.finalizeVersion();
        batcherFactory.setVersionPaused(id2, true);

        vm.prank(user1);
        vm.expectRevert(IBatcherAccountProxyFactory.VersionPaused.selector);
        batcherFactory.setVersion(id2);
    }

    function test_version_setVersion_switchEmitsTransition() external {
        batcher1 = _deployBatcherInstance(user1);

        // Build a finalized v2 (no init)
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("noop()"));
        batcherFactory.addSelectorsToVersion(_singletonGroup(address(0xABCD), selectors));
        uint256 id2 = batcherFactory.finalizeVersion();

        vm.expectEmit(true, true, true, true);
        emit IBatcherAccountProxyFactory.UserVersionSet(user1, DEFAULT_VERSION_ID, id2);

        vm.prank(user1);
        batcherFactory.setVersion(id2);

        assertEq(batcherFactory.proxyVersion(address(batcher1)), id2);
    }

    function test_proxy_noFacetForSelector_revertsBeforeDelegatecall() external {
        batcher1 = _deployBatcherInstance(user1);

        vm.prank(user1);
        vm.expectRevert(IBatcherAccountProxy.NoFacetForSelector.selector);
        (bool ok,) = address(batcher1).call(abi.encodeWithSignature("unknown()"));
        ok;
    }

    function test_proxy_runInit_revertNonFactory() external {
        batcher1 = _deployBatcherInstance(user1);

        vm.prank(user1);
        vm.expectRevert(IBatcherAccountProxy.UnauthorizedCall.selector);
        batcher1.runInit(address(0xABCD));
    }

    function test_proxy_runInit_viaFactoryExecute_revertNotAuthorized() external {
        batcher1 = _deployBatcherInstance(user1);

        bytes memory payload = abi.encodeCall(IBatcherAccountProxy.runInit, (address(0xDEADBEEF)));

        vm.prank(user1);
        vm.expectRevert(IBatcherAccountProxy.UnauthorizedCall.selector);
        batcherFactory.execute(payload);
    }

    function test_factory_isInitAuthorized_falseOutsideSetVersion() external {
        batcher1 = _deployBatcherInstance(user1);
        assertFalse(batcherFactory.isInitAuthorized());
    }

    function test_factory_versionSelectors_returnsAllRegisteredSelectors() external view {
        bytes4[] memory all = batcherFactory.versionSelectors(DEFAULT_VERSION_ID, 0, 200);
        assertEq(all.length, swapSelectors.length);
        assertEq(all[0], SwapFacet.swap_call.selector);
    }

    function test_factory_versionSelectorToFacet_resolvesKnownSelector() external view {
        bytes4 sel = SwapFacet.swap_call.selector;
        assertEq(batcherFactory.versionSelectorToFacet(DEFAULT_VERSION_ID, sel), address(swapFacet));
    }

    function test_factory_renounceOwnership_disabled() external {
        vm.expectRevert("disabled");
        batcherFactory.renounceOwnership();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PROXY TOKEN OPERATIONS TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_proxy_pull() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 100e18;

        deal(address(tokenA), user1, amount);

        vm.startPrank(user1);
        tokenA.approve(address(batcher1), amount);
        batcher1.pull(address(tokenA), amount);
        vm.stopPrank();

        assertEq(tokenA.balanceOf(address(batcher1)), amount);
        assertEq(tokenA.balanceOf(user1), 0);
    }

    function test_proxy_push() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 100e18;

        _fundBatcher(batcher1, address(tokenA), amount);

        vm.prank(user1);
        batcher1.push(address(tokenA), amount);

        assertEq(tokenA.balanceOf(address(batcher1)), 0);
        assertEq(tokenA.balanceOf(user1), amount);
    }

    function test_proxy_push_contractBalanceSentinel() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 100e18;

        _fundBatcher(batcher1, address(tokenA), amount);

        vm.prank(user1);
        batcher1.push(address(tokenA), BatcherConstants.CONTRACT_BALANCE);

        assertEq(tokenA.balanceOf(address(batcher1)), 0);
        assertEq(tokenA.balanceOf(user1), amount);
    }

    function test_proxy_push_percentageSentinel() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 100e18;

        _fundBatcher(batcher1, address(tokenA), amount);

        // Top bit set, remaining bits are millionths: 25%.
        uint256 quarter = (1 << 255) | 250_000;
        vm.prank(user1);
        batcher1.push(address(tokenA), quarter);

        assertEq(tokenA.balanceOf(user1), amount / 4);
        assertEq(tokenA.balanceOf(address(batcher1)), amount - amount / 4);
    }

    function test_proxy_sweep() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 100e18;

        _fundBatcher(batcher1, address(tokenA), amount);

        vm.prank(user1);
        batcher1.sweep(address(tokenA), 0);

        assertEq(tokenA.balanceOf(address(batcher1)), 0);
        assertEq(tokenA.balanceOf(user1), amount);
    }

    function test_proxy_sweep_revertMinAmountViolated() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 100e18;

        _fundBatcher(batcher1, address(tokenA), amount);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IBatcherAccountProxy.MinAmountViolated.selector, amount, amount + 1));
        batcher1.sweep(address(tokenA), amount + 1);
    }

    function test_proxy_revertUnauthorizedCall() external {
        batcher1 = _deployBatcherInstance(user1);

        vm.prank(user2);
        vm.expectRevert(IBatcherAccountProxy.UnauthorizedCall.selector);
        batcher1.pull(address(tokenA), 100e18);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SHARED STORAGE TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_sharedStorage_addVault() external {
        address mockVault = address(0x1234);

        batcherSharedStorage.add(AddressSetRegistryIds.VAULT_ID, mockVault, true);
        assertTrue(batcherSharedStorage.contains(AddressSetRegistryIds.VAULT_ID, mockVault));
        assertEq(batcherSharedStorage.length(AddressSetRegistryIds.VAULT_ID), 1);

        batcherSharedStorage.add(AddressSetRegistryIds.VAULT_ID, mockVault, false);
        assertFalse(batcherSharedStorage.contains(AddressSetRegistryIds.VAULT_ID, mockVault));
        assertEq(batcherSharedStorage.length(AddressSetRegistryIds.VAULT_ID), 0);
    }

    function test_sharedStorage_addSwapRouter() external {
        address mockRouter = address(0x5678);

        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, mockRouter, true);
        assertTrue(batcherSharedStorage.contains(AddressSetRegistryIds.SWAP_ROUTER_ID, mockRouter));
        assertEq(batcherSharedStorage.length(AddressSetRegistryIds.SWAP_ROUTER_ID), 1);

        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, mockRouter, false);
        assertFalse(batcherSharedStorage.contains(AddressSetRegistryIds.SWAP_ROUTER_ID, mockRouter));
        assertEq(batcherSharedStorage.length(AddressSetRegistryIds.SWAP_ROUTER_ID), 0);
    }

    function test_sharedStorage_vaultsPagination() external {
        address vault1 = address(0x1111);
        address vault2 = address(0x2222);
        address vault3 = address(0x3333);

        batcherSharedStorage.add(AddressSetRegistryIds.VAULT_ID, vault1, true);
        batcherSharedStorage.add(AddressSetRegistryIds.VAULT_ID, vault2, true);
        batcherSharedStorage.add(AddressSetRegistryIds.VAULT_ID, vault3, true);

        address[] memory vaults = batcherSharedStorage.getPage(AddressSetRegistryIds.VAULT_ID, 0, 2);
        assertEq(vaults.length, 2);

        vaults = batcherSharedStorage.getPage(AddressSetRegistryIds.VAULT_ID, 2, 10);
        assertEq(vaults.length, 1);

        vaults = batcherSharedStorage.getPage(AddressSetRegistryIds.VAULT_ID, 10, 10);
        assertEq(vaults.length, 0);
    }

    function test_sharedStorage_revertNonOwner() external {
        vm.prank(user1);
        vm.expectRevert();
        batcherSharedStorage.add(AddressSetRegistryIds.VAULT_ID, address(0x1234), true);
    }

    function test_sharedStorage_setName() external {
        assertEq(batcherSharedStorage.name(AddressSetRegistryIds.VAULT_ID), "");

        vm.expectEmit(true, true, true, true);
        emit IAddressSetRegistry.NameSet(AddressSetRegistryIds.VAULT_ID, "vaults");
        batcherSharedStorage.setName(AddressSetRegistryIds.VAULT_ID, "vaults");
        assertEq(batcherSharedStorage.name(AddressSetRegistryIds.VAULT_ID), "vaults");

        batcherSharedStorage.setName(AddressSetRegistryIds.VAULT_ID, "vaults-v2");
        assertEq(batcherSharedStorage.name(AddressSetRegistryIds.VAULT_ID), "vaults-v2");
    }

    function test_sharedStorage_setName_revertNonOwner() external {
        vm.prank(user1);
        vm.expectRevert();
        batcherSharedStorage.setName(AddressSetRegistryIds.VAULT_ID, "vaults");
    }

    function test_sharedStorage_renounceOwnership_disabled() external {
        vm.expectRevert("Renounce disabled");
        batcherSharedStorage.renounceOwnership();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ACCESS CONTROL TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_proxy_onlyUser_pull() external {
        batcher1 = _deployBatcherInstance(user1);

        vm.prank(unauthorized);
        vm.expectRevert(IBatcherAccountProxy.UnauthorizedCall.selector);
        batcher1.pull(address(tokenA), 100e18);
    }

    function test_proxy_onlyUser_push() external {
        batcher1 = _deployBatcherInstance(user1);

        vm.prank(unauthorized);
        vm.expectRevert(IBatcherAccountProxy.UnauthorizedCall.selector);
        batcher1.push(address(tokenA), 100e18);
    }

    function test_proxy_onlyUser_sweep() external {
        batcher1 = _deployBatcherInstance(user1);

        vm.prank(unauthorized);
        vm.expectRevert(IBatcherAccountProxy.UnauthorizedCall.selector);
        batcher1.sweep(address(tokenA), 0);
    }

    function test_proxy_onlyUser_multicall() external {
        batcher1 = _deployBatcherInstance(user1);
        bytes[] memory data = new bytes[](0);

        vm.prank(unauthorized);
        vm.expectRevert(IBatcherAccountProxy.UnauthorizedCall.selector);
        batcher1.multicall(data);
    }

    function test_proxy_onlyUser_fallback() external {
        batcher1 = _deployBatcherInstance(user1);

        vm.prank(unauthorized);
        vm.expectRevert(IBatcherAccountProxy.UnauthorizedCall.selector);
        SwapFacet(address(batcher1)).swap_call(_unroutedSwap());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // NATIVE TOKEN TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_proxy_wrapNative() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 1 ether;

        vm.deal(user1, amount);

        vm.prank(user1);
        batcher1.wrapNative{value: amount}(amount);

        assertEq(IERC20(wNativeToken).balanceOf(address(batcher1)), amount);
    }

    function test_proxy_unwrapNative() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 1 ether;

        vm.deal(user1, amount);
        vm.prank(user1);
        batcher1.wrapNative{value: amount}(amount);

        vm.prank(user1);
        batcher1.unwrapNative(amount);

        assertEq(IERC20(wNativeToken).balanceOf(address(batcher1)), 0);
        assertEq(address(batcher1).balance, amount);
    }

    function test_proxy_receive_acceptsNativeAndPushesToUser() external {
        batcher1 = _deployBatcherInstance(user1);

        vm.deal(user1, 1 ether);

        vm.prank(user1);
        (bool success,) = address(batcher1).call{value: 1 ether}("");

        assertTrue(success);
        assertEq(address(batcher1).balance, 1 ether);

        vm.prank(user1);
        batcher1.push(address(0), 1 ether);

        assertEq(address(batcher1).balance, 0);
        assertEq(user1.balance, 1 ether);
    }

    function test_multicall_wrapNativeThenPushWrappedNative() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 1 ether;
        vm.deal(user1, amount);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(BatcherAccountProxy.wrapNative, (amount));
        data[1] = abi.encodeCall(BatcherAccountProxy.push, (wNativeToken, BatcherConstants.CONTRACT_BALANCE));

        vm.prank(user1);
        batcher1.multicall{value: amount}(data);

        assertEq(IERC20(wNativeToken).balanceOf(user1), amount);
        assertEq(IERC20(wNativeToken).balanceOf(address(batcher1)), 0);
        assertEq(address(batcher1).balance, 0);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUNDING VIA FACTORY TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_pullViaFactory_fundsCallerAccount() external {
        vm.prank(alice);
        aliceAccount.pullViaFactory(_funding(address(tokenA), PULLED));

        assertEq(tokenA.balanceOf(address(aliceAccount)), PULLED);
        assertEq(tokenA.balanceOf(alice), MINTED - PULLED);
        assertEq(tokenA.allowance(alice, address(aliceAccount)), 0, "clone never needs an allowance");
    }

    function test_pullViaFactory_movesMultipleTokens() external {
        Funding[] memory funding = new Funding[](2);
        funding[0] = Funding(address(tokenA), PULLED);
        funding[1] = Funding(address(tokenB), PULLED * 2);

        vm.prank(alice);
        aliceAccount.pullViaFactory(funding);

        assertEq(tokenA.balanceOf(address(aliceAccount)), PULLED);
        assertEq(tokenB.balanceOf(address(aliceAccount)), PULLED * 2);
    }

    function test_multicall_fundsAndRunsInOneTransaction() external {
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(BatcherAccountProxy.pullViaFactory, (_funding(address(tokenA), PULLED)));
        data[1] = abi.encodeCall(BatcherAccountProxy.push, (address(tokenA), PULLED / 4));

        vm.prank(alice);
        aliceAccount.multicall(data);

        assertEq(tokenA.balanceOf(address(aliceAccount)), PULLED - PULLED / 4, "batch kept the remainder");
        assertEq(tokenA.balanceOf(alice), MINTED - PULLED + PULLED / 4, "quarter pushed back");
    }

    function test_factory_deployExecute_deploysFundsAndRunsForNewUser() external {
        assertEq(batcherFactory.batchers(carol), address(0), "no account yet");

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(BatcherAccountProxy.pullViaFactory, (_funding(address(tokenA), PULLED)));
        data[1] = abi.encodeCall(BatcherAccountProxy.push, (address(tokenA), PULLED / 4));

        vm.prank(carol);
        (address proxy,) = batcherFactory.deployExecute(0, abi.encodeWithSignature("multicall(bytes[])", data));

        assertEq(batcherFactory.batchers(carol), proxy);
        assertEq(tokenA.balanceOf(proxy), PULLED - PULLED / 4, "deployed, funded and run in one transaction");
    }

    function test_multicall_revertsAtomically() external {
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(BatcherAccountProxy.pullViaFactory, (_funding(address(tokenA), PULLED / 4)));
        data[1] = abi.encodeCall(BatcherAccountProxy.push, (address(tokenA), PULLED));

        vm.prank(alice);
        vm.expectRevert();
        aliceAccount.multicall(data);

        assertEq(tokenA.balanceOf(address(aliceAccount)), 0, "nothing moved");
        assertEq(tokenA.balanceOf(alice), MINTED, "caller made whole");
    }

    function test_pullViaFactory_cannotReachAnotherUsersFunds() external {
        uint256 aliceBefore = tokenA.balanceOf(alice);

        vm.prank(bob);
        bobAccount.pullViaFactory(_funding(address(tokenA), PULLED));

        assertEq(tokenA.balanceOf(address(bobAccount)), PULLED, "funds come from the batcher own user");
        assertEq(tokenA.balanceOf(address(aliceAccount)), 0, "another user account is untouched");
        assertEq(tokenA.balanceOf(alice), aliceBefore, "another user balance is untouched");
    }

    function test_pullViaFactory_revert_notUserOrOwner() external {
        vm.prank(bob);
        vm.expectRevert(IBatcherAccountProxy.UnauthorizedCall.selector);
        aliceAccount.pullViaFactory(_funding(address(tokenA), PULLED));
    }

    function test_pullFor_revert_callerIsNotABatcher() external {
        vm.prank(alice);
        vm.expectRevert(IBatcherAccountProxyFactory.NoBatcher.selector);
        batcherFactory.pullFor(_funding(address(tokenA), PULLED));
    }

    function test_pullViaFactory_revert_withoutFactoryApproval() external {
        vm.prank(alice);
        tokenA.approve(address(batcherFactory), 0);

        vm.prank(alice);
        vm.expectRevert();
        aliceAccount.pullViaFactory(_funding(address(tokenA), PULLED));
    }

    function test_pullFor_reentrantTokenIsNotABatcher() external {
        ReentrantToken hostile = new ReentrantToken(address(batcherFactory));
        hostile.mint(alice, MINTED);
        vm.prank(alice);
        hostile.approve(address(batcherFactory), type(uint256).max);

        vm.prank(alice);
        aliceAccount.pullViaFactory(_funding(address(hostile), PULLED));

        assertTrue(hostile.reentryReverted(), "re-entry was rejected");
        assertEq(bytes4(hostile.lastReentryError()), IBatcherAccountProxyFactory.NoBatcher.selector);
        assertEq(hostile.balanceOf(address(aliceAccount)), PULLED, "outer funding still completed");
    }

    function test_pullNFTViaFactory_movesTokens() external {
        NFTFunding[] memory funding = new NFTFunding[](2);
        funding[0] = NFTFunding(address(collection), ALICE_NFT);
        funding[1] = NFTFunding(address(collection), ALICE_NFT + 1);

        vm.prank(alice);
        aliceAccount.pullNFTViaFactory(funding);

        assertEq(collection.ownerOf(ALICE_NFT), address(aliceAccount));
        assertEq(collection.ownerOf(ALICE_NFT + 1), address(aliceAccount));
        assertFalse(collection.isApprovedForAll(alice, address(aliceAccount)), "clone never needs an operator right");
    }

    function test_multicall_pullsNFTAndPushesItBack() external {
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(BatcherAccountProxy.pullNFTViaFactory, (_nftFunding(ALICE_NFT)));
        data[1] = abi.encodeWithSignature("pushNFT(address,uint256)", address(collection), ALICE_NFT);

        vm.prank(alice);
        aliceAccount.multicall(data);

        assertEq(collection.ownerOf(ALICE_NFT), alice, "round tripped without a standing approval");
    }

    function test_pullNFTViaFactory_cannotReachAnotherUsersNFT() external {
        vm.prank(bob);
        bobAccount.pullNFTViaFactory(_nftFunding(BOB_NFT));

        assertEq(collection.ownerOf(BOB_NFT), address(bobAccount), "funds come from the batcher own user");
        assertEq(collection.ownerOf(ALICE_NFT), alice, "another user token is untouched");
    }

    function test_pullNFTFor_revert_callerIsNotABatcher() external {
        vm.prank(alice);
        vm.expectRevert(IBatcherAccountProxyFactory.NoBatcher.selector);
        batcherFactory.pullNFTFor(_nftFunding(ALICE_NFT));
    }

    function test_pullNFTViaFactory_revert_notUserOrOwner() external {
        vm.prank(bob);
        vm.expectRevert(IBatcherAccountProxy.UnauthorizedCall.selector);
        aliceAccount.pullNFTViaFactory(_nftFunding(ALICE_NFT));
    }

    function test_pullNFTViaFactory_revert_withoutFactoryApproval() external {
        vm.prank(alice);
        collection.setApprovalForAll(address(batcherFactory), false);

        vm.prank(alice);
        vm.expectRevert();
        aliceAccount.pullNFTViaFactory(_nftFunding(ALICE_NFT));
    }

    function _nftFunding(uint256 tokenId) internal view returns (NFTFunding[] memory funding) {
        funding = new NFTFunding[](1);
        funding[0] = NFTFunding(address(collection), tokenId);
    }

    function _funding(address token, uint256 amount) internal pure returns (Funding[] memory funding) {
        funding = new Funding[](1);
        funding[0] = Funding(token, amount);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MULTICALL WITH ALLOW REVERT TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_multicallAllowRevert_allSucceed() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 100 ether;

        tokenA.mint(user1, amount);
        tokenB.mint(user1, amount);

        vm.startPrank(user1);
        tokenA.approve(address(batcher1), amount);
        tokenB.approve(address(batcher1), amount);
        vm.stopPrank();

        _mc_pull(address(tokenA), amount);
        _mc_pull(address(tokenB), amount);

        bool[] memory allowRevert = new bool[](2);
        allowRevert[0] = false;
        allowRevert[1] = false;

        (bool[] memory successes,) = _mc_execute(batcher1, allowRevert);

        assertTrue(successes[0]);
        assertTrue(successes[1]);
        assertEq(tokenA.balanceOf(address(batcher1)), amount);
        assertEq(tokenB.balanceOf(address(batcher1)), amount);
    }

    function test_multicallAllowRevert_continuesOnAllowedRevert() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 100 ether;

        tokenA.mint(user1, amount);

        vm.startPrank(user1);
        tokenA.approve(address(batcher1), amount);
        vm.stopPrank();

        _mc_pull(address(tokenA), amount);
        // This will fail - trying to pull tokenB without approval/balance
        _mc_pull(address(tokenB), amount);
        // This should still execute - sweep tokenA back to user
        _mc_sweep(address(tokenA), 0);

        bool[] memory allowRevert = new bool[](3);
        allowRevert[0] = false;
        allowRevert[1] = true; // Allow this to revert
        allowRevert[2] = false;

        (bool[] memory successes,) = _mc_execute(batcher1, allowRevert);

        assertTrue(successes[0]);
        assertFalse(successes[1]); // This failed but was allowed
        assertTrue(successes[2]); // This still executed
        assertEq(tokenA.balanceOf(user1), amount); // Swept back
        assertEq(tokenA.balanceOf(address(batcher1)), 0);
    }

    function test_multicallAllowRevert_revertsOnDisallowedRevert() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 100 ether;

        _mc_pull(address(tokenA), amount);

        bool[] memory allowRevert = new bool[](1);
        allowRevert[0] = false; // Don't allow revert

        vm.prank(user1);
        vm.expectRevert();
        batcher1.multicall(multicall_datas, allowRevert);
    }

    function test_multicallAllowRevert_revert_lengthMismatch() external {
        batcher1 = _deployBatcherInstance(user1);

        _mc_pull(address(tokenA), 100 ether);
        _mc_pull(address(tokenB), 100 ether);

        bool[] memory allowRevert = new bool[](1); // Wrong length

        vm.prank(user1);
        vm.expectRevert(IBatcherAccountProxy.LengthMismatch.selector);
        batcher1.multicall(multicall_datas, allowRevert);
    }

    function test_multicallAllowRevert_multipleFailuresAllowed() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 100 ether;

        tokenA.mint(user1, amount);

        vm.startPrank(user1);
        tokenA.approve(address(batcher1), amount);
        vm.stopPrank();

        _mc_pull(address(tokenB), amount); // Will fail
        _mc_pull(address(tokenA), amount); // Will succeed
        _mc_pull(address(tokenB), amount); // Will fail again

        bool[] memory allowRevert = new bool[](3);
        allowRevert[0] = true;
        allowRevert[1] = false;
        allowRevert[2] = true;

        (bool[] memory successes,) = _mc_execute(batcher1, allowRevert);

        assertFalse(successes[0]);
        assertTrue(successes[1]);
        assertFalse(successes[2]);
        assertEq(tokenA.balanceOf(address(batcher1)), amount);
    }

    function test_multicallAllowRevert_emptyArray() external {
        batcher1 = _deployBatcherInstance(user1);

        bytes[] memory data = new bytes[](0);
        bool[] memory allowRevert = new bool[](0);

        vm.prank(user1);
        (bool[] memory successes, bytes[] memory results) = batcher1.multicall(data, allowRevert);

        assertEq(successes.length, 0);
        assertEq(results.length, 0);
    }

    function test_multicallAllowRevert_revert_notUser() external {
        batcher1 = _deployBatcherInstance(user1);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(BatcherAccountProxy.pull, (address(tokenA), 100));
        bool[] memory allowRevert = new bool[](1);

        vm.prank(user2);
        vm.expectRevert(IBatcherAccountProxy.UnauthorizedCall.selector);
        batcher1.multicall(data, allowRevert);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FACTORY EXECUTE TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    bytes4 internal constant SEL_MULTICALL_REVERT = bytes4(keccak256("multicall(bytes[],bool[])"));

    function test_factory_execute_revertNoBatcher() external {
        vm.prank(user1);
        vm.expectRevert(IBatcherAccountProxyFactory.NoBatcher.selector);
        batcherFactory.execute(abi.encodeWithSelector(BatcherAccountProxy.pull.selector, address(tokenA), 0));
    }

    function test_factory_execute_forwardsMulticall() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 100e18;
        deal(address(tokenA), user1, amount);

        vm.prank(user1);
        tokenA.approve(address(batcher1), amount);

        bytes[] memory innerData = new bytes[](2);
        innerData[0] = abi.encodeCall(BatcherAccountProxy.pull, (address(tokenA), amount));
        innerData[1] = abi.encodeCall(BatcherAccountProxy.sweep, (address(tokenA), 0));
        bool[] memory allowRevert = new bool[](2);

        bytes memory payload = abi.encodeWithSelector(SEL_MULTICALL_REVERT, innerData, allowRevert);

        vm.prank(user1);
        batcherFactory.execute(payload);

        assertEq(tokenA.balanceOf(address(batcher1)), 0);
        assertEq(tokenA.balanceOf(user1), amount);
    }

    function test_factory_execute_forwardsMsgValue_wrapNative() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 1 ether;
        vm.deal(user1, amount);

        bytes[] memory innerData = new bytes[](1);
        innerData[0] = abi.encodeCall(BatcherAccountProxy.wrapNative, (amount));
        bool[] memory allowRevert = new bool[](1);

        bytes memory payload = abi.encodeWithSelector(SEL_MULTICALL_REVERT, innerData, allowRevert);

        vm.prank(user1);
        batcherFactory.execute{value: amount}(payload);

        assertEq(IERC20(wNativeToken).balanceOf(address(batcher1)), amount);
    }

    function test_factory_execute_pullUsesUserImmutable() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 100e18;
        deal(address(tokenA), user1, amount);

        vm.prank(user1);
        tokenA.approve(address(batcher1), amount);

        bytes memory payload = abi.encodeCall(BatcherAccountProxy.pull, (address(tokenA), amount));

        vm.prank(user1);
        batcherFactory.execute(payload);

        assertEq(tokenA.balanceOf(address(batcher1)), amount);
        assertEq(tokenA.balanceOf(user1), 0);
    }

    function test_factory_execute_bubbleUpRevert() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 100e18;
        _fundBatcher(batcher1, address(tokenA), amount);

        bytes memory payload = abi.encodeCall(BatcherAccountProxy.sweep, (address(tokenA), amount + 1));

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IBatcherAccountProxy.MinAmountViolated.selector, amount, amount + 1));
        batcherFactory.execute(payload);
    }

    function test_factory_execute_atomicWithSetup_viaOzMulticall() external {
        uint256 amount = 100e18;
        deal(address(tokenA), user1, amount);

        address predicted = batcherFactory.computeBatcherAddress(user1);
        vm.prank(user1);
        tokenA.approve(predicted, amount);

        bytes[] memory innerData = new bytes[](1);
        innerData[0] = abi.encodeCall(BatcherAccountProxy.pull, (address(tokenA), amount));
        bool[] memory allowRevert = new bool[](1);
        bytes memory payload = abi.encodeWithSelector(SEL_MULTICALL_REVERT, innerData, allowRevert);

        bytes[] memory outerData = new bytes[](3);
        outerData[0] = abi.encodeCall(IBatcherAccountProxyFactory.deploy, ());
        outerData[1] = abi.encodeCall(IBatcherAccountProxyFactory.setVersion, (DEFAULT_VERSION_ID));
        outerData[2] = abi.encodeCall(IBatcherAccountProxyFactory.execute, (payload));

        vm.prank(user1);
        batcherFactory.multicall(outerData);

        address batcher = batcherFactory.batchers(user1);
        assertEq(batcher, predicted);
        assertEq(tokenA.balanceOf(batcher), amount);
        assertEq(tokenA.balanceOf(user1), 0);
    }

    function test_factory_deployExecute_fundedOnboarding() external {
        uint256 amount = 1 ether;
        vm.deal(user1, amount);

        bytes[] memory innerData = new bytes[](1);
        innerData[0] = abi.encodeCall(BatcherAccountProxy.wrapNative, (amount));
        bool[] memory allowRevert = new bool[](1);
        bytes memory payload = abi.encodeWithSelector(SEL_MULTICALL_REVERT, innerData, allowRevert);

        address predicted = batcherFactory.computeBatcherAddress(user1);

        vm.prank(user1);
        (address instance,) = batcherFactory.deployExecute{value: amount}(DEFAULT_VERSION_ID, payload);

        assertEq(instance, predicted);
        assertEq(batcherFactory.batchers(user1), predicted);
        assertEq(batcherFactory.proxyVersion(instance), DEFAULT_VERSION_ID);
        assertEq(IERC20(wNativeToken).balanceOf(instance), amount);
        assertEq(address(batcherFactory).balance, 0);
    }

    function test_factory_deployExecute_reusesBatcherAndSkipsZeroVersion() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 100e18;
        _fundBatcher(batcher1, address(tokenA), amount);

        bytes memory payload = abi.encodeCall(BatcherAccountProxy.sweep, (address(tokenA), 0));

        vm.prank(user1);
        (address instance,) = batcherFactory.deployExecute(0, payload);

        assertEq(instance, address(batcher1));
        assertEq(batcherFactory.proxyVersion(address(batcher1)), DEFAULT_VERSION_ID);
        assertEq(tokenA.balanceOf(user1), amount);
    }

    function test_factory_multicall_rejectsValueOnNonPayableSteps() external {
        vm.deal(user1, 1 ether);

        bytes[] memory outerData = new bytes[](2);
        outerData[0] = abi.encodeCall(IBatcherAccountProxyFactory.deploy, ());
        outerData[1] = abi.encodeCall(IBatcherAccountProxyFactory.setVersion, (DEFAULT_VERSION_ID));

        vm.prank(user1);
        (bool ok,) =
            address(batcherFactory).call{value: 1 ether}(abi.encodeWithSignature("multicall(bytes[])", outerData));
        assertFalse(ok);
    }

    function test_proxy_multicall_acceptsOwner() external {
        batcher1 = _deployBatcherInstance(user1);
        uint256 amount = 100e18;
        _fundBatcher(batcher1, address(tokenA), amount);

        bytes[] memory innerData = new bytes[](1);
        innerData[0] = abi.encodeCall(BatcherAccountProxy.sweep, (address(tokenA), 0));
        bool[] memory allowRevert = new bool[](1);

        vm.prank(address(batcherFactory));
        batcher1.multicall(innerData, allowRevert);

        assertEq(tokenA.balanceOf(address(batcher1)), 0);
        assertEq(tokenA.balanceOf(user1), amount);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PERMIT TESTS (EIP-2612)
    // ═══════════════════════════════════════════════════════════════════════════

    bytes32 internal constant _PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /// @dev Build an EIP-2612 permit signature for `token`. Token must expose
    ///      DOMAIN_SEPARATOR() and nonces(address) (solady ERC20 + OZ ERC20Permit do).
    function _signPermit(
        uint256 privateKey,
        address token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        uint256 nonce = IERC20Permit(token).nonces(owner);
        bytes32 structHash = keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, value, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", IERC20Permit(token).DOMAIN_SEPARATOR(), structHash));
        (v, r, s) = vm.sign(privateKey, digest);
    }

    function test_permit_pull_compose_succeeds() external {
        (address permitUser, uint256 pk) = makeAddrAndKey("permitUser");
        // Need a proxy for this user; the factory only lets `msg.sender` deploy their own.
        vm.prank(permitUser);
        batcherFactory.deploy();
        vm.prank(permitUser);
        batcherFactory.setVersion(DEFAULT_VERSION_ID);
        BatcherAccountProxy permitProxy = BatcherAccountProxy(payable(batcherFactory.batchers(permitUser)));

        uint256 amount = 100e18;
        permitToken.mint(permitUser, amount);

        // Sign permit (owner=permitUser, spender=permitProxy)
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) =
            _signPermit(pk, address(permitToken), permitUser, address(permitProxy), amount, deadline);

        // Compose permit + pull in a single multicall from the user.
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(BatcherAccountProxy.permit, (address(permitToken), amount, deadline, v, r, s));
        data[1] = abi.encodeCall(BatcherAccountProxy.pull, (address(permitToken), amount));

        assertEq(permitToken.balanceOf(permitUser), amount);
        assertEq(permitToken.balanceOf(address(permitProxy)), 0);

        vm.prank(permitUser);
        permitProxy.multicall(data);

        assertEq(permitToken.balanceOf(permitUser), 0);
        assertEq(permitToken.balanceOf(address(permitProxy)), amount);
    }

    function test_permit_revert_wrongSpender() external {
        (address permitUser, uint256 pk) = makeAddrAndKey("permitUserB");
        vm.prank(permitUser);
        batcherFactory.deploy();
        vm.prank(permitUser);
        batcherFactory.setVersion(DEFAULT_VERSION_ID);
        BatcherAccountProxy permitProxy = BatcherAccountProxy(payable(batcherFactory.batchers(permitUser)));

        uint256 amount = 100e18;
        permitToken.mint(permitUser, amount);

        // Sign permit naming an ATTACKER as spender (not the proxy).
        uint256 deadline = block.timestamp + 1 hours;
        address attacker = address(0xBADBAD);
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(pk, address(permitToken), permitUser, attacker, amount, deadline);

        // The proxy's permit hardcodes spender=address(this); the token will
        // reject this signature because it was signed for a different spender.
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(BatcherAccountProxy.permit, (address(permitToken), amount, deadline, v, r, s));

        vm.prank(permitUser);
        vm.expectRevert();
        permitProxy.multicall(data);
    }

    function test_permit_revert_expiredDeadline() external {
        (address permitUser, uint256 pk) = makeAddrAndKey("permitUserC");
        vm.prank(permitUser);
        batcherFactory.deploy();
        vm.prank(permitUser);
        batcherFactory.setVersion(DEFAULT_VERSION_ID);
        BatcherAccountProxy permitProxy = BatcherAccountProxy(payable(batcherFactory.batchers(permitUser)));

        uint256 amount = 100e18;
        permitToken.mint(permitUser, amount);

        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) =
            _signPermit(pk, address(permitToken), permitUser, address(permitProxy), amount, deadline);

        // Fast-forward past the deadline; permit must revert.
        vm.warp(deadline + 1);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(BatcherAccountProxy.permit, (address(permitToken), amount, deadline, v, r, s));

        vm.prank(permitUser);
        vm.expectRevert();
        permitProxy.multicall(data);
    }

    function test_permit_revert_notUserOrOwner() external {
        batcher1 = _deployBatcherInstance(user1);
        bytes32 dummyR = bytes32(0);
        bytes32 dummyS = bytes32(0);

        // Random third party can't invoke permit on user1's proxy.
        vm.prank(address(0xC0FFEE));
        vm.expectRevert(IBatcherAccountProxy.UnauthorizedCall.selector);
        batcher1.permit(address(permitToken), 1, block.timestamp + 1, 27, dummyR, dummyS);
    }
}

contract MockERC721 is ERC721("mock", "MOCK") {
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract ReentrantToken is MockERC20 {
    IBatcherAccountProxyFactory internal immutable factory;

    bool public reentryReverted;
    bytes public lastReentryError;

    constructor(address _factory) {
        factory = IBatcherAccountProxyFactory(_factory);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        try factory.pullFor(new Funding[](0)) {
            reentryReverted = false;
        } catch (bytes memory err) {
            reentryReverted = true;
            lastReentryError = err;
        }
        return super.transferFrom(from, to, amount);
    }
}
