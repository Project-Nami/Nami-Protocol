// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAddressSetRegistry {
    error ZeroAddress();

    event NameSet(uint256 indexed id, string name);

    function add(uint256 _id, address _addr, bool _isAdd) external;

    function setName(uint256 _id, string calldata _name) external;

    function name(uint256 _id) external view returns (string memory);

    function length(uint256 _id) external view returns (uint256);

    function contains(uint256 _id, address _addr) external view returns (bool);

    function getPage(uint256 _id, uint256 _index, uint256 _length) external view returns (address[] memory);
}
