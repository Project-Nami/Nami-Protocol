// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IAddressSetRegistry} from "contracts/utils/interfaces/IAddressSetRegistry.sol";

contract AddressSetRegistry is IAddressSetRegistry, Ownable2Step, Multicall {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(uint256 => EnumerableSet.AddressSet) internal _sets;

    mapping(uint256 => string) public name;

    constructor(address _owner) Ownable(_owner) {
        if (_owner == address(0)) revert ZeroAddress();
    }

    function add(uint256 _id, address _addr, bool _isAdd) external onlyOwner {
        if (_isAdd) _sets[_id].add(_addr);
        else _sets[_id].remove(_addr);
    }

    function setName(uint256 _id, string calldata _name) external onlyOwner {
        emit NameSet(_id, name[_id] = _name);
    }

    function length(uint256 _id) external view returns (uint256) {
        return _sets[_id].length();
    }

    function contains(uint256 _id, address _addr) external view returns (bool) {
        return _sets[_id].contains(_addr);
    }

    function getPage(uint256 _id, uint256 _index, uint256 _length) external view returns (address[] memory array) {
        uint256 totalLength = _sets[_id].length();
        if (_index >= totalLength) return new address[](0);

        uint256 endIndex = _index + _length;
        if (endIndex > totalLength) endIndex = totalLength;

        uint256 actualLength = endIndex - _index;
        array = new address[](actualLength);

        for (uint256 i = 0; i < actualLength; i++) {
            array[i] = _sets[_id].at(_index + i);
        }
    }

    /// @dev Renouncing ownership is disabled
    function renounceOwnership() public view override onlyOwner {
        revert("Renounce disabled");
    }
}
