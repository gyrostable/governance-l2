// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Address} from "oz/utils/Address.sol";
import {OwnableUpgradeable} from "upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {EnumerableSet} from "oz/utils/structs/EnumerableSet.sol";

contract GovernanceRoleManager is OwnableUpgradeable, UUPSUpgradeable {
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    error NotAuthorized();

    event AuthorizedTargetAdded(
        address indexed user, address indexed target, bytes4 indexed selector, ParameterRequirement[] parameters
    );
    event AuthorizedTargetRemoved(address indexed user, address indexed target, bytes4 indexed selector);
    event ActionExecuted(address indexed user, DataTypes.ProposalAction indexed action);

    /// @notice A parameter requirement for a target/selector
    /// Dictates that the parameter at the given index must match the given abi-encoded value
    struct ParameterRequirement {
        uint256 index;
        bytes32 value;
    }

    struct TargetSet {
        /// This is encoded as (uint256(uint160(target)) << 32) | (uint256(bytes32(selector)) >> 224)
        /// Which means the first 8 bytes are unused, the next 20 bytes are the target, and the last 4 bytes are the selector
        /// If target is address(0), any target is allowed with the selector
        /// If selector is 0, any selector is allowed with the target
        EnumerableSet.Bytes32Set allowedTargets;
        /// Defines required parameters for a target/selector
        mapping(bytes32 => ParameterRequirement[]) allowedParameters;
    }

    /// @notice A permission for a user
    /// @dev This is only used for the view function
    struct Permission {
        address target;
        bytes4 selector;
        ParameterRequirement[] parameters;
    }

    /// @notice Stores the permissions for each user
    /// @dev See TargetSet for the encoding of target/selector
    mapping(address => TargetSet) internal _permissions;

    modifier onlyOwnerOrThis() {
        if (msg.sender != owner() && msg.sender != address(this)) {
            revert NotAuthorized();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner) public initializer {
        __Ownable_init(owner);
    }

    /// @notice Returns the permissions for the given user
    function getPermissions(address user) external view returns (Permission[] memory permissions) {
        TargetSet storage targetSet = _permissions[user];
        bytes32[] memory allowedTargets = targetSet.allowedTargets.values();
        permissions = new Permission[](allowedTargets.length);
        for (uint256 i; i < allowedTargets.length; i++) {
            (address target, bytes4 selector) = _splitTargetAndSelector(allowedTargets[i]);
            permissions[i] = Permission({
                target: target,
                selector: selector,
                parameters: targetSet.allowedParameters[allowedTargets[i]]
            });
        }
    }

    /// @notice Adds a permission for a user
    /// @param user The user to add the permission for
    /// @param target The target to add the permission for, or address(0) for any target
    /// @param selector The selector to add the permission for, or 0 for any selector
    /// @param parameters The parameters to add the permission for, or an empty array for any parameters
    function addPermission(address user, address target, bytes4 selector, ParameterRequirement[] calldata parameters)
        external
        onlyOwnerOrThis
    {
        bytes32 targetWithSelector = _encodeTargetWithSelector(target, selector);
        _permissions[user].allowedTargets.add(targetWithSelector);
        for (uint256 i; i < parameters.length; i++) {
            _permissions[user].allowedParameters[targetWithSelector].push(parameters[i]);
        }
        emit AuthorizedTargetAdded(user, target, selector, parameters);
    }

    /// @notice Removes a permission for a user
    function removePermission(address user, address target, bytes4 selector) external onlyOwnerOrThis {
        bytes32 targetWithSelector = _encodeTargetWithSelector(target, selector);
        _permissions[user].allowedTargets.remove(targetWithSelector);
        delete _permissions[user].allowedParameters[targetWithSelector];
        emit AuthorizedTargetRemoved(user, target, selector);
    }

    /// @notice Executes a list of actions
    /// @param actions The actions to execute
    function executeActions(DataTypes.ProposalAction[] calldata actions) external {
        for (uint256 i; i < actions.length; i++) {
            if (!_isAuthorizedAction(msg.sender, actions[i])) {
                revert NotAuthorized();
            }
            _executeAction(actions[i]);
            emit ActionExecuted(msg.sender, actions[i]);
        }
    }

    function _isAuthorizedAction(address sender, DataTypes.ProposalAction calldata action)
        internal
        view
        returns (bool)
    {
        TargetSet storage targetSet = _permissions[sender];

        bytes4 selector = _extractSelector(action.data);

        // Check for wildcard target (address(0)) with specific selector
        bytes32 wildcardTargetWithSelector = _encodeTargetWithSelector(address(0), selector);
        if (targetSet.allowedTargets.contains(wildcardTargetWithSelector)) {
            return _validateParameters(targetSet.allowedParameters[wildcardTargetWithSelector], action.data);
        }

        // Check for specific target with wildcard selector (bytes4(0))
        bytes32 targetWithWildcardSelector = _encodeTargetWithSelector(action.target, bytes4(0));
        if (targetSet.allowedTargets.contains(targetWithWildcardSelector)) {
            return true;
        }

        // Check for specific target and selector
        bytes32 targetWithSelector = _encodeTargetWithSelector(action.target, selector);
        if (!targetSet.allowedTargets.contains(targetWithSelector)) {
            return false;
        }
        return _validateParameters(targetSet.allowedParameters[targetWithSelector], action.data);
    }

    function _validateParameters(ParameterRequirement[] memory parameters, bytes calldata data)
        internal
        pure
        returns (bool)
    {
        for (uint256 i; i < parameters.length; i++) {
            uint256 parameterOffset = 4 + parameters[i].index * 32;
            if (parameterOffset + 32 > data.length) {
                return false;
            }
            bytes32 parameterValue = bytes32(data[parameterOffset:parameterOffset + 32]);
            if (parameterValue != parameters[i].value) {
                return false;
            }
        }
        return true;
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
        targetWithSelector = bytes32((uint256(uint160(target)) << 32) | (uint256(bytes32(selector)) >> 224));
    }

    function _splitTargetAndSelector(bytes32 targetWithSelector)
        internal
        pure
        returns (address target, bytes4 selector)
    {
        target = address(uint160(uint256(targetWithSelector) >> 32));
        selector = bytes4(uint32(uint256(targetWithSelector) & 0xffffffff));
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner {}
}
