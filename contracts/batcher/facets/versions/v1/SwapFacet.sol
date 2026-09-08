// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FacetBase} from "contracts/batcher/facets/base/FacetBase.sol";
import {AddressLib} from "contracts/batcher/libraries/AddressLib.sol";
import {AddressSetRegistryIds} from "contracts/utils/constants/AddressSetRegistryIds.sol";
import {IAddressSetRegistry} from "contracts/utils/interfaces/IAddressSetRegistry.sol";

/// @dev Deployed on Hub & Spoke chains
contract SwapFacet is FacetBase {
    using AddressLib for address;
    using SafeERC20 for IERC20;

    IAddressSetRegistry public immutable registry;

    constructor(address _registry) {
        registry = IAddressSetRegistry(_registry);
    }

    error NotRouter();
    error NotApproveTarget();
    error FailedSwap();
    error MinAmountViolated(uint256 actual, uint256 minimum);
    error InsufficientValue(uint256 available, uint256 required);

    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        address swapRouter;
        address approveTarget;
        bool toThis;
        uint256 minAmountOut;
        uint256 value;
        bytes swapData;
    }

    /// @dev Address bits sit below the offset bit so the OR matches an add, and flat ids never collide.
    function approveSetId(address _swapRouter) public pure returns (uint256) {
        return AddressSetRegistryIds.ROUTER_APPROVE_OFFSET | uint256(uint160(_swapRouter));
    }

    function swap_call(SwapParams memory params) external payable onlyDelegateCall returns (uint256 received) {
        if (!registry.contains(AddressSetRegistryIds.SWAP_ROUTER_ID, params.swapRouter)) {
            revert NotRouter();
        }

        address spender = params.approveTarget;
        if (spender == address(0)) {
            spender = params.swapRouter;
        } else if (spender != params.swapRouter && !registry.contains(approveSetId(params.swapRouter), spender)) {
            revert NotApproveTarget();
        }

        if (params.value != 0 && address(this).balance < params.value) {
            revert InsufficientValue(address(this).balance, params.value);
        }

        address recipient = resolveReceiver(params.toThis);
        uint256 preBalance = params.minAmountOut == 0 ? 0 : params.tokenOut.resolveBalance(recipient);

        // Native input rides as `value`, so there is nothing to approve.
        if (params.tokenIn != address(0)) {
            params.amountIn = params.tokenIn.resolveAmount(params.amountIn);
            // +1 keeps the allowance slot warm across swaps, saves the cold SSTORE.
            IERC20(params.tokenIn).forceApprove(spender, params.amountIn + 1);
        }

        // Execute swap
        (bool success,) = params.swapRouter.call{value: params.value}(params.swapData);
        if (!success) revert FailedSwap();

        if (params.minAmountOut != 0) {
            received = params.tokenOut.resolveBalance(recipient) - preBalance;
            if (received < params.minAmountOut) revert MinAmountViolated(received, params.minAmountOut);
        }
    }
}
