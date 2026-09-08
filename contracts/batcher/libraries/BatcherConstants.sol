// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library BatcherConstants {
    /// @dev Marker returned by valid batcher facets during factory registration.
    bytes4 internal constant BATCHER_FACET_ID = 0x00000001;

    /// @dev Used as a flag for resolving to this contract's balance of a token
    uint256 internal constant CONTRACT_BALANCE = type(uint256).max;

    /// @dev Used as a flag for identifying msg.sender, saves gas by sending more 0 bytes
    address internal constant MSG_SENDER = address(1);

    /// @dev Used as a flag for identifying address(this), saves gas by sending more 0 bytes
    address internal constant ADDRESS_THIS = address(2);
}
