// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BatcherAccountProxy} from "contracts/batcher/BatcherAccountProxy.sol";
import {FacetBase} from "contracts/batcher/facets/base/FacetBase.sol";
import {SwapFacet} from "contracts/batcher/facets/versions/v1/SwapFacet.sol";
import {BatcherConstants} from "contracts/batcher/libraries/BatcherConstants.sol";
import {AddressSetRegistryIds} from "contracts/utils/constants/AddressSetRegistryIds.sol";
import {BatcherTestBase} from "test/base/BatcherTestBase.sol";
import "test/mocks/MockERC20.sol";

contract SwapFacetTest is BatcherTestBase {
    BatcherAccountProxy batcher1;

    MockERC20 tokenA;
    MockERC20 tokenB;
    address mockRouter;

    uint256 constant SWAP_AMOUNT = 1000 ether;
    uint256 constant FEE = 0.001 ether;

    function setUp() public {
        _setupBatcher();

        batcher1 = _deployBatcherInstance(user1);

        tokenA = new MockERC20();
        tokenB = new MockERC20();

        mockRouter = address(0x1234);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ACCESS CONTROL TESTS
    // ══════════════════════════════════════════════════════════════════════════

    function test_swap_revert_notRouter() external {
        tokenA.mint(address(batcher1), SWAP_AMOUNT);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: address(0x9999),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: 0,
            value: 0,
            swapData: ""
        });

        vm.prank(user1);
        vm.expectRevert(SwapFacet.NotRouter.selector);
        SwapFacet(address(batcher1)).swap_call(params);
    }

    function test_swap_revert_notWhitelistedRouter() external {
        tokenA.mint(address(batcher1), SWAP_AMOUNT);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: mockRouter,
            approveTarget: address(0),
            toThis: false,
            minAmountOut: 0,
            value: 0,
            swapData: ""
        });

        vm.prank(user1);
        vm.expectRevert(SwapFacet.NotRouter.selector);
        SwapFacet(address(batcher1)).swap_call(params);
    }

    function test_swap_revert_directCall() external {
        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: mockRouter,
            approveTarget: address(0),
            toThis: false,
            minAmountOut: 0,
            value: 0,
            swapData: ""
        });

        vm.expectRevert(FacetBase.NotDelegateCall.selector);
        swapFacet.swap_call(params);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // SWAP WITH WHITELISTED ROUTER TESTS
    // ══════════════════════════════════════════════════════════════════════════

    function test_swap_revert_failedSwap() external {
        FailingRouter failingRouter = new FailingRouter();
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(failingRouter), true);

        tokenA.mint(address(batcher1), SWAP_AMOUNT);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: address(failingRouter),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: 0,
            value: 0,
            swapData: abi.encodeWithSignature("swap()")
        });

        vm.prank(user1);
        vm.expectRevert(SwapFacet.FailedSwap.selector);
        SwapFacet(address(batcher1)).swap_call(params);
    }

    function test_swap_revert_minAmountViolated() external {
        MockSwapRouter router = new MockSwapRouter(address(tokenB));
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);

        tokenA.mint(address(batcher1), SWAP_AMOUNT);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: address(router),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: 2000 ether,
            value: 0,
            swapData: abi.encodeCall(router.swap, (address(tokenA), address(tokenB), SWAP_AMOUNT, user1))
        });

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(SwapFacet.MinAmountViolated.selector, SWAP_AMOUNT, 2000 ether));
        SwapFacet(address(batcher1)).swap_call(params);
    }

    function test_swap_success() external {
        MockSwapRouter router = new MockSwapRouter(address(tokenB));
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);

        tokenA.mint(address(batcher1), SWAP_AMOUNT);

        uint256 balanceBefore = tokenB.balanceOf(user1);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: address(router),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: SWAP_AMOUNT,
            value: 0,
            swapData: abi.encodeCall(router.swap, (address(tokenA), address(tokenB), SWAP_AMOUNT, user1))
        });

        vm.prank(user1);
        SwapFacet(address(batcher1)).swap_call(params);

        uint256 balanceAfter = tokenB.balanceOf(user1);
        assertEq(balanceAfter - balanceBefore, SWAP_AMOUNT);
        assertEq(tokenA.balanceOf(address(batcher1)), 0);
    }

    function test_swap_contractBalance() external {
        MockSwapRouter router = new MockSwapRouter(address(tokenB));
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);

        tokenA.mint(address(batcher1), SWAP_AMOUNT);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: BatcherConstants.CONTRACT_BALANCE,
            swapRouter: address(router),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: SWAP_AMOUNT,
            value: 0,
            swapData: abi.encodeCall(router.swap, (address(tokenA), address(tokenB), SWAP_AMOUNT, user1))
        });

        vm.prank(user1);
        SwapFacet(address(batcher1)).swap_call(params);

        assertEq(tokenB.balanceOf(user1), SWAP_AMOUNT);
        assertEq(tokenA.balanceOf(address(batcher1)), 0);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // MEASURED OUTPUT
    // ══════════════════════════════════════════════════════════════════════════

    function test_swap_returnsMeasuredOutput() external {
        MockSwapRouter router = new MockSwapRouter(address(tokenB));
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);

        tokenA.mint(address(batcher1), SWAP_AMOUNT);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: address(router),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: SWAP_AMOUNT,
            value: 0,
            swapData: abi.encodeCall(router.swap, (address(tokenA), address(tokenB), SWAP_AMOUNT, user1))
        });

        vm.prank(user1);
        uint256 received = SwapFacet(address(batcher1)).swap_call(params);

        assertEq(received, SWAP_AMOUNT, "return value must be the measured delta");
        assertEq(received, tokenB.balanceOf(user1));
    }

    function test_swap_attributesEachLegSeparately() external {
        MockSwapRouter router = new MockSwapRouter(address(tokenB));
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);

        tokenA.mint(address(batcher1), SWAP_AMOUNT * 3);

        uint256 first = _swapTo(router, SWAP_AMOUNT);
        uint256 second = _swapTo(router, SWAP_AMOUNT * 2);

        assertEq(first, SWAP_AMOUNT);
        assertEq(second, SWAP_AMOUNT * 2);
        assertEq(tokenB.balanceOf(user1), SWAP_AMOUNT * 3);
    }

    function test_swap_returnsZeroWhenNotMeasured() external {
        MockSwapRouter router = new MockSwapRouter(address(tokenB));
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);

        tokenA.mint(address(batcher1), SWAP_AMOUNT);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: address(router),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: 0,
            value: 0,
            swapData: abi.encodeCall(router.swap, (address(tokenA), address(tokenB), SWAP_AMOUNT, user1))
        });

        vm.prank(user1);
        uint256 received = SwapFacet(address(batcher1)).swap_call(params);

        assertEq(received, 0, "unmeasured must report 0, not a guess");
        assertEq(tokenB.balanceOf(user1), SWAP_AMOUNT, "the swap still happened");
    }

    // ══════════════════════════════════════════════════════════════════════════
    // NATIVE INPUT
    // ══════════════════════════════════════════════════════════════════════════

    function test_swap_nativeInNeedsNoApproval() external {
        NativeInRouter router = new NativeInRouter(address(tokenB));
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);

        vm.deal(address(batcher1), SWAP_AMOUNT);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(0),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: address(router),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: SWAP_AMOUNT,
            value: SWAP_AMOUNT,
            swapData: abi.encodeCall(router.buy, (user1))
        });

        vm.prank(user1);
        uint256 received = SwapFacet(address(batcher1)).swap_call(params);

        assertEq(received, SWAP_AMOUNT, "native-in swap measured like any other");
        assertEq(address(router).balance, SWAP_AMOUNT, "the input itself is the value");
        assertEq(address(batcher1).balance, 0);
    }

    function test_swap_nativeInIgnoresAmountInSentinel() external {
        NativeInRouter router = new NativeInRouter(address(tokenB));
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);

        vm.deal(address(batcher1), SWAP_AMOUNT);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(0),
            tokenOut: address(tokenB),
            amountIn: BatcherConstants.CONTRACT_BALANCE,
            swapRouter: address(router),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: SWAP_AMOUNT,
            value: SWAP_AMOUNT,
            swapData: abi.encodeCall(router.buy, (user1))
        });

        vm.prank(user1);
        uint256 received = SwapFacet(address(batcher1)).swap_call(params);

        assertEq(received, SWAP_AMOUNT);
        assertEq(address(router).balance, SWAP_AMOUNT, "`value` is the input, not amountIn");
    }

    function test_swap_nativeInAndNativeOut() external {
        NativeBothRouter router = new NativeBothRouter();
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);

        vm.deal(address(batcher1), SWAP_AMOUNT);
        vm.deal(address(router), SWAP_AMOUNT);
        uint256 before = user1.balance;

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(0),
            tokenOut: address(0),
            amountIn: SWAP_AMOUNT,
            swapRouter: address(router),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: SWAP_AMOUNT,
            value: SWAP_AMOUNT,
            swapData: abi.encodeCall(router.forward, (user1))
        });

        vm.prank(user1);
        uint256 received = SwapFacet(address(batcher1)).swap_call(params);

        assertEq(received, SWAP_AMOUNT);
        assertEq(user1.balance - before, SWAP_AMOUNT);
    }

    function test_swap_crossChainShapeMustNotBeMeasured() external {
        MockSwapRouter router = new MockSwapRouter(address(tokenB));
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);

        tokenA.mint(address(batcher1), SWAP_AMOUNT);
        address foreignToken = address(0xDeaD00000000000000000000000000000000BEEf);
        assertEq(foreignToken.code.length, 0, "fixture must have no code on this chain");

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: foreignToken,
            amountIn: SWAP_AMOUNT,
            swapRouter: address(router),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: 1,
            value: 0,
            swapData: abi.encodeCall(router.swap, (address(tokenA), address(tokenB), SWAP_AMOUNT, user1))
        });

        vm.prank(user1);
        vm.expectRevert();
        SwapFacet(address(batcher1)).swap_call(params);

        params.minAmountOut = 0;
        vm.prank(user1);
        uint256 received = SwapFacet(address(batcher1)).swap_call(params);
        assertEq(received, 0);
        assertEq(tokenB.balanceOf(user1), SWAP_AMOUNT, "the swap itself still happened");
    }

    function test_swap_minimalFloorStillMeasures() external {
        MockSwapRouter router = new MockSwapRouter(address(tokenB));
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);

        tokenA.mint(address(batcher1), SWAP_AMOUNT);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: address(router),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: 1,
            value: 0,
            swapData: abi.encodeCall(router.swap, (address(tokenA), address(tokenB), SWAP_AMOUNT, user1))
        });

        vm.prank(user1);
        uint256 received = SwapFacet(address(batcher1)).swap_call(params);

        assertEq(received, SWAP_AMOUNT, "a 1-wei floor still yields the full measurement");
    }

    function test_swap_measuredResultIsNeverZero() external {
        ZeroOutRouter router = new ZeroOutRouter();
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);

        tokenA.mint(address(batcher1), SWAP_AMOUNT);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: address(router),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: 1,
            value: 0,
            swapData: abi.encodeCall(router.takeAndGiveNothing, (address(tokenA), SWAP_AMOUNT))
        });

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(SwapFacet.MinAmountViolated.selector, 0, 1));
        SwapFacet(address(batcher1)).swap_call(params);
    }

    function _swapTo(MockSwapRouter router, uint256 amount) internal returns (uint256) {
        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: amount,
            swapRouter: address(router),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: amount,
            value: 0,
            swapData: abi.encodeCall(router.swap, (address(tokenA), address(tokenB), amount, user1))
        });
        vm.prank(user1);
        return SwapFacet(address(batcher1)).swap_call(params);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // NATIVE VALUE FORWARDING
    // ══════════════════════════════════════════════════════════════════════════

    function test_swap_forwardsValueToRouter() external {
        PayableRouter router = new PayableRouter(address(tokenB));
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);

        tokenA.mint(address(batcher1), SWAP_AMOUNT);
        vm.deal(address(batcher1), FEE);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: address(router),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: SWAP_AMOUNT,
            value: FEE,
            swapData: abi.encodeCall(router.swapWithFee, (address(tokenA), address(tokenB), SWAP_AMOUNT, user1))
        });

        vm.prank(user1);
        SwapFacet(address(batcher1)).swap_call(params);

        assertEq(address(router).balance, FEE, "router did not receive the fee");
        assertEq(address(batcher1).balance, 0, "proxy kept native it should have forwarded");
        assertEq(tokenB.balanceOf(user1), SWAP_AMOUNT);
    }

    function test_swap_revert_payableRouterWithoutValue() external {
        PayableRouter router = new PayableRouter(address(tokenB));
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);

        tokenA.mint(address(batcher1), SWAP_AMOUNT);
        vm.deal(address(batcher1), FEE);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: address(router),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: 0,
            value: 0,
            swapData: abi.encodeCall(router.swapWithFee, (address(tokenA), address(tokenB), SWAP_AMOUNT, user1))
        });

        vm.prank(user1);
        vm.expectRevert(SwapFacet.FailedSwap.selector);
        SwapFacet(address(batcher1)).swap_call(params);
    }

    function test_swap_revert_insufficientValue() external {
        PayableRouter router = new PayableRouter(address(tokenB));
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);

        tokenA.mint(address(batcher1), SWAP_AMOUNT);
        vm.deal(address(batcher1), FEE - 1);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: address(router),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: 0,
            value: FEE,
            swapData: abi.encodeCall(router.swapWithFee, (address(tokenA), address(tokenB), SWAP_AMOUNT, user1))
        });

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(SwapFacet.InsufficientValue.selector, FEE - 1, FEE));
        SwapFacet(address(batcher1)).swap_call(params);
    }

    function test_swap_forwardsOnlyWhatItWasGiven() external {
        PayableRouter router = new PayableRouter(address(tokenB));
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);

        tokenA.mint(address(batcher1), SWAP_AMOUNT);
        vm.deal(address(batcher1), FEE * 10);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: address(router),
            approveTarget: address(0),
            toThis: false,
            minAmountOut: SWAP_AMOUNT,
            value: FEE,
            swapData: abi.encodeCall(router.swapWithFee, (address(tokenA), address(tokenB), SWAP_AMOUNT, user1))
        });

        vm.prank(user1);
        SwapFacet(address(batcher1)).swap_call(params);

        assertEq(address(router).balance, FEE);
        assertEq(address(batcher1).balance, FEE * 9, "proxy's remaining native must be untouched");
    }

    // ══════════════════════════════════════════════════════════════════════════
    // SPLIT SPENDER ROUTER TESTS
    // ══════════════════════════════════════════════════════════════════════════

    function test_swap_revert_unregisteredApproveTarget() external {
        SplitSpenderRouter router = new SplitSpenderRouter(address(tokenB));
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);

        tokenA.mint(address(batcher1), SWAP_AMOUNT);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: address(router),
            approveTarget: address(router.approver()),
            toThis: false,
            minAmountOut: 0,
            value: 0,
            swapData: abi.encodeCall(router.swap, (address(tokenA), address(tokenB), SWAP_AMOUNT, user1))
        });

        vm.prank(user1);
        vm.expectRevert(SwapFacet.NotApproveTarget.selector);
        SwapFacet(address(batcher1)).swap_call(params);
    }

    function test_swap_revert_approveTargetOfAnotherRouter() external {
        SplitSpenderRouter routerA = new SplitSpenderRouter(address(tokenB));
        SplitSpenderRouter routerB = new SplitSpenderRouter(address(tokenB));
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(routerA), true);
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(routerB), true);
        batcherSharedStorage.add(swapFacet.approveSetId(address(routerA)), address(routerA.approver()), true);

        tokenA.mint(address(batcher1), SWAP_AMOUNT);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: address(routerB),
            approveTarget: address(routerA.approver()),
            toThis: false,
            minAmountOut: 0,
            value: 0,
            swapData: abi.encodeCall(routerB.swap, (address(tokenA), address(tokenB), SWAP_AMOUNT, user1))
        });

        vm.prank(user1);
        vm.expectRevert(SwapFacet.NotApproveTarget.selector);
        SwapFacet(address(batcher1)).swap_call(params);
    }

    function test_swap_splitSpender_success() external {
        SplitSpenderRouter router = new SplitSpenderRouter(address(tokenB));
        address approver = address(router.approver());
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);
        batcherSharedStorage.add(swapFacet.approveSetId(address(router)), approver, true);

        tokenA.mint(address(batcher1), SWAP_AMOUNT);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: address(router),
            approveTarget: approver,
            toThis: false,
            minAmountOut: SWAP_AMOUNT,
            value: 0,
            swapData: abi.encodeCall(router.swap, (address(tokenA), address(tokenB), SWAP_AMOUNT, user1))
        });

        vm.prank(user1);
        uint256 received = SwapFacet(address(batcher1)).swap_call(params);

        assertEq(received, SWAP_AMOUNT);
        assertEq(tokenB.balanceOf(user1), SWAP_AMOUNT);
        assertEq(tokenA.allowance(address(batcher1), address(router)), 0, "router never holds an allowance");
        assertEq(tokenA.allowance(address(batcher1), approver), 1, "approve target keeps the warm dust only");
    }

    function test_swap_splitSpender_leavesUnpulledAllowance() external {
        SplitSpenderRouter router = new SplitSpenderRouter(address(tokenB));
        address approver = address(router.approver());
        batcherSharedStorage.add(AddressSetRegistryIds.SWAP_ROUTER_ID, address(router), true);
        batcherSharedStorage.add(swapFacet.approveSetId(address(router)), approver, true);

        tokenA.mint(address(batcher1), SWAP_AMOUNT);

        SwapFacet.SwapParams memory params = SwapFacet.SwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: SWAP_AMOUNT,
            swapRouter: address(router),
            approveTarget: approver,
            toThis: false,
            minAmountOut: SWAP_AMOUNT / 2,
            value: 0,
            swapData: abi.encodeCall(router.swapPartial, (address(tokenA), address(tokenB), SWAP_AMOUNT, user1))
        });

        vm.prank(user1);
        SwapFacet(address(batcher1)).swap_call(params);

        assertEq(tokenA.balanceOf(address(batcher1)), SWAP_AMOUNT / 2, "unspent input stays put");
        assertEq(tokenA.allowance(address(batcher1), approver), SWAP_AMOUNT / 2 + 1, "unpulled input stays approved");
    }
}

contract PayableRouter {
    error NoValue();

    address public tokenOut;

    constructor(address _tokenOut) {
        tokenOut = _tokenOut;
    }

    function swapWithFee(address tokenIn, address, uint256 amount, address recipient) external payable {
        if (msg.value == 0) revert NoValue();
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amount);
        MockERC20(tokenOut).mint(recipient, amount);
    }
}

contract MockSwapRouter {
    address public tokenOut;

    constructor(address _tokenOut) {
        tokenOut = _tokenOut;
    }

    function swap(address tokenIn, address, uint256 amount, address recipient) external {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amount);
        MockERC20(tokenOut).mint(recipient, amount);
    }
}

contract FailingRouter {
    fallback() external {
        revert();
    }
}

contract NativeInRouter {
    error NoValue();

    address public tokenOut;

    constructor(address _tokenOut) {
        tokenOut = _tokenOut;
    }

    function buy(address recipient) external payable {
        if (msg.value == 0) revert NoValue();
        MockERC20(tokenOut).mint(recipient, msg.value);
    }
}

contract NativeBothRouter {
    error NoValue();

    function forward(address recipient) external payable {
        if (msg.value == 0) revert NoValue();
        (bool ok,) = recipient.call{value: msg.value}("");
        require(ok, "payout failed");
    }

    receive() external payable {}
}

contract ZeroOutRouter {
    function takeAndGiveNothing(address tokenIn, uint256 amount) external {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amount);
    }
}

contract MockTokenApprove {
    error NotRouter();

    address public immutable router;

    constructor(address _router) {
        router = _router;
    }

    function claimTokens(address token, address from, address to, uint256 amount) external {
        if (msg.sender != router) revert NotRouter();
        IERC20(token).transferFrom(from, to, amount);
    }
}

contract SplitSpenderRouter {
    address public tokenOut;
    MockTokenApprove public approver;

    constructor(address _tokenOut) {
        tokenOut = _tokenOut;
        approver = new MockTokenApprove(address(this));
    }

    function swap(address tokenIn, address, uint256 amount, address recipient) external {
        approver.claimTokens(tokenIn, msg.sender, address(this), amount);
        MockERC20(tokenOut).mint(recipient, amount);
    }

    function swapPartial(address tokenIn, address, uint256 amount, address recipient) external {
        approver.claimTokens(tokenIn, msg.sender, address(this), amount / 2);
        MockERC20(tokenOut).mint(recipient, amount / 2);
    }
}
