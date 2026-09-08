// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBatcherAccountProxy {
    error UnauthorizedCall();
    error NotWrappedNative();
    error NoFacetForSelector();
    error VersionPaused();
    error MinAmountViolated(uint256 actual, uint256 minimum);
    error LengthMismatch();

    function user() external view returns (address);

    function multicall(bytes[] calldata data) external payable returns (bool[] memory successes, bytes[] memory results);

    function multicall(bytes[] calldata data, bool[] calldata allowRevert)
        external
        payable
        returns (bool[] memory successes, bytes[] memory results);

    function runInit(address init) external;
}
