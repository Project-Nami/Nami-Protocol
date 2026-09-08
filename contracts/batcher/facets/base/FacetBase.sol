// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBatcherAccountProxy} from "contracts/batcher/interfaces/IBatcherAccountProxy.sol";
import {IBatcherFacet} from "contracts/batcher/interfaces/IBatcherFacet.sol";
import {BatcherConstants} from "contracts/batcher/libraries/BatcherConstants.sol";

/// @dev Facet entrypoints should be payable since proxy multicall uses delegatecall and preserves msg.value.
abstract contract FacetBase is IBatcherFacet {
    using SafeERC20 for IERC20;

    address internal immutable self = address(this);

    error NotUserOrThis();
    error NotDelegateCall();

    function batcherFacetId() external pure returns (bytes4) {
        return BatcherConstants.BATCHER_FACET_ID;
    }

    modifier onlyDelegateCall() {
        if (address(this) == self) revert NotDelegateCall();
        _;
    }

    function user() internal view returns (address) {
        return IBatcherAccountProxy(address(this)).user();
    }

    function validateUserOrAddressThis(address _addr) internal view {
        address _user = user();
        if (_addr != _user && _addr != address(this)) revert NotUserOrThis();
    }

    function resolveReceiver(bool toThis) internal view returns (address) {
        return toThis ? address(this) : user();
    }
}
