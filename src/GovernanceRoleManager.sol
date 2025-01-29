// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Address} from "oz/utils/Address.sol";
import {OwnableUpgradeable} from "upgradeable/access/OwnableUpgradeable.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {EnumerableSet} from "oz/utils/structs/EnumerableSet.sol";

contract GovernanceRoleManager {
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    struct AddressWithSelector {
        address target;
        bytes4 selector;
    }

    /// @notice Allows the address to call any target with the given selector
    mapping(address => EnumerableSet.Bytes32Set) internal _authorizedSelectors;

    /// @notice Allows the address to call the target on with any selector
    mapping(address => EnumerableSet.AddressSet) internal _authorizedTargets;

    /// @notice Allows the address to call the target with the given selector
    /// This is encoded as abi.encodePacked(target, selector) to prevent collisions
    mapping(address => EnumerableSet.Bytes32Set) internal _authorizedTargetWithSelectors;

    /// @notice Returns the permissions for the given user
    function getPermissions(address user)
        external
        view
        returns (
            bytes4[] memory authorizedSelectors,
            address[] memory authorizedTargets,
            AddressWithSelector[] memory authorizedTargetsWithSelectors
        )
    {
        authorizedSelectors = new bytes4[](_authorizedSelectors[user].length());
        for (uint256 i; i < _authorizedSelectors[user].length(); i++) {
            authorizedSelectors[i] = bytes4(_authorizedSelectors[user].at(i));
        }

        authorizedTargetsWithSelectors = new AddressWithSelector[](_authorizedTargetWithSelectors[user].length());
        for (uint256 i; i < _authorizedTargetWithSelectors[user].length(); i++) {
            (address target, bytes4 selector) = _splitTargetAndSelector(_authorizedTargetWithSelectors[user].at(i));
            authorizedTargetsWithSelectors[i] = AddressWithSelector({target: target, selector: selector});
        }
        authorizedTargets = _authorizedTargets[user].values();
    }

    /// @dev value is encoded as:
    /// Value-Type (8 bits), 0 = Selector, 1 = Target, 2 = TargetWithSelector
    /// If the value is 0, then the last 4 bytes are the selector
    /// If the value is 1, then the last 20 bytes are the address
    /// If the value is 2, then the last 4 bytes are the selector and the preceding 20 bytes are the address
    /// Can be encoded using:
    /// abi.encodePacked(uint8(0), uint216(0), bytes4(SELECTOR))
    /// abi.encodePacked(uint8(1), uint88(0), address(ADDRESS))
    /// abi.encodePacked(uint8(2), uint56(0), address(ADDRESS), bytes4(SELECTOR))
    function _authorize(address user, bytes32 value) internal {
        uint8 valueType = uint8(bytes1(value >> 248));
        if (valueType == 0) {
            bytes4 selector =
                bytes4(uint32(uint256(value) & 0x00000000000000000000000000000000000000000000000000000000ffffffff));
            _authorizedSelectors[user].add(selector);
        } else if (valueType == 1) {
            address target =
                address(uint160(uint256(value) & 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff));
            _authorizedTargets[user].add(target);
        } else if (valueType == 2) {
            bytes4 selector =
                bytes4(uint32(uint256(value) & 0x00000000000000000000000000000000000000000000000000000000ffffffff));
            address target = address(
                uint160((uint256(value) >> 4) & 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff)
            );
            _authorizedTargetWithSelectors[user].add(_encodeTargetWithSelector(target, selector));
        }
    }

    function _isAuthorizedAction(address sender, DataTypes.ProposalAction calldata action)
        internal
        view
        returns (bool)
    {
        bytes4 selector = _extractSelector(action.data);
        return _authorizedSelectors[sender].contains(bytes32(selector))
            || _authorizedTargets[sender].contains(action.target)
            || _authorizedTargetWithSelectors[sender].contains(_encodeTargetWithSelector(action.target, selector));
    }

    function _executeAction(DataTypes.ProposalAction calldata action) internal {
        action.target.functionCallWithValue(action.data, action.value);
    }

    function _extractSelector(bytes memory data) internal pure returns (bytes4 selector) {
        assembly {
            selector := and(mload(add(data, 0x20)), 0xffffffff00000000000000000000000000000000000000000000000000000000)
        }
    }

    function _encodeTargetWithSelector(address target, bytes4 selector)
        internal
        pure
        returns (bytes32 targetWithSelector)
    {
        targetWithSelector = bytes32((uint256(uint160(target)) << 32) | uint256(bytes32(selector)));
    }

    function _splitTargetAndSelector(bytes32 targetWithSelector)
        internal
        pure
        returns (address target, bytes4 selector)
    {
        target = address(bytes20(targetWithSelector >> 32));
        selector = bytes4(bytes32(uint256(targetWithSelector) & 0xffffffff));
    }
}
