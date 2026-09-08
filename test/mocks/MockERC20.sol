// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    uint8 private _decimals = 18;

    constructor() ERC20("", "") {
        _decimals = 18;
    }

    /// @notice Mints tokens to an address. Public for testing.
    /// @param to Recipient address
    /// @param amount Amount to mint (in token's smallest unit)
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @notice Burns tokens from an address. Public for testing.
    /// @param from Address whose tokens will be burned
    /// @param amount Amount to burn
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    /// @notice Override decimals if user provided non-standard decimals.
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
