// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BatcherConstants} from "contracts/batcher/libraries/BatcherConstants.sol";
import {Constants} from "contracts/libraries/Constants.sol";

library AddressLib {
    uint256 internal constant PERCENTAGE_FLAG = 1 << 255;
    uint256 internal constant PERCENTAGE_MASK = PERCENTAGE_FLAG - 1;

    function defaultToSender(address addr) internal view returns (address) {
        return addr == address(0) ? msg.sender : addr;
    }

    function resolveRecipient(address recipient) internal view returns (address) {
        if (recipient == BatcherConstants.MSG_SENDER) {
            return msg.sender;
        }
        if (recipient == BatcherConstants.ADDRESS_THIS) return address(this);
        return recipient;
    }

    function resolveBalance(address token) internal view returns (uint256) {
        return resolveBalance(token, address(this));
    }

    function resolveBalance(address token, address user) internal view returns (uint256) {
        return token == address(0) ? user.balance : IERC20(token).balanceOf(user);
    }

    function resolveAmount(address token, uint256 amount) internal view returns (uint256) {
        return resolveAmount(token, amount, address(this));
    }

    function resolveAmount(address token, uint256 amount, address account) internal view returns (uint256) {
        if (amount == BatcherConstants.CONTRACT_BALANCE) {
            return resolveBalance(token, account);
        }

        if (amount & PERCENTAGE_FLAG != 0) {
            // Extract percentage value (0 to FEE, representing 0% to 100%)
            uint256 percentage = amount & PERCENTAGE_MASK;

            // Validate percentage is within bounds
            require(percentage <= Constants.FEE, "Invalid percentage");

            uint256 _balance = resolveBalance(token, account);
            return (_balance * percentage) / Constants.FEE;
        }

        return amount;
    }
}
