// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @dev EIP-2612 token for the proxy permit tests.
contract MockERC20Permit is ERC20, ERC20Permit {
    constructor() ERC20("Mock Permit", "MPT") ERC20Permit("Mock Permit") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
