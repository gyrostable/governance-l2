// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Address} from "oz/utils/Address.sol";
import {OwnableUpgradeable} from "upgradeable/access/OwnableUpgradeable.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {EnumerableSet} from "oz/utils/structs/EnumerableSet.sol";

contract GovernanceRoleManager is OwnableUpgradeable {
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    error NotAuthorized();

    event AuthorizedSelectorAdded(address indexed user, bytes4 indexed selector);
    event AuthorizedSelectorRemoved(address indexed user, bytes4 indexed selector);
    event AuthorizedTargetAdded(address indexed user, address indexed target);
    event AuthorizedTargetRemoved(address indexed user, address indexed target);
    event AuthorizedTargetWithSelectorAdded(address indexed user, address indexed target, bytes4 indexed selector);
    event AuthorizedTargetWithSelectorRemoved(address indexed user, address indexed target, bytes4 indexed selector);
    event ActionExecuted(address indexed user, DataTypes.ProposalAction indexed action);

    struct ParameterRequirement {
        uint256 index;
        bytes32 value;
    }

    struct TargetSet {
        EnumerableSet.Bytes32Set allowedTargets;
        mapping(bytes32 => ParameterRequirement[]) allowedParameters;
    }

    struct TargetSpecification {
        address target;
        bytes4 selector;
        ParameterRequirement[] parameters;
    }

    /// @notice Allows the address to call any target with the given selector
    mapping(address => EnumerableSet.Bytes32Set) internal _authorizedSelectors;

    /// @notice Allows the address to call the target on with any selector
    mapping(address => EnumerableSet.AddressSet) internal _authorizedTargets;

    /// @notice Allows the address to call the target with the given selector
    /// This is encoded as abi.encodePacked(target, selector)
    /// ParameterRequirement can be added to enforce parameter values
    mapping(address => TargetSet) internal _authorizedTargetWithSelectors;

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
    function getPermissions(address user)
        external
        view
        returns (
            bytes4[] memory authorizedSelectors,
            address[] memory authorizedTargets,
            TargetSpecification[] memory authorizedTargetsWithSelectors
        )
    {
        authorizedSelectors = new bytes4[](_authorizedSelectors[user].length());
        for (uint256 i; i < _authorizedSelectors[user].length(); i++) {
            authorizedSelectors[i] = bytes4(_authorizedSelectors[user].at(i));
        }

        TargetSet storage targetSet = _authorizedTargetWithSelectors[user];
        bytes32[] memory allowedTargets = targetSet.allowedTargets.values();
        authorizedTargetsWithSelectors = new TargetSpecification[](allowedTargets.length);
        for (uint256 i; i < allowedTargets.length; i++) {
            (address target, bytes4 selector) = _splitTargetAndSelector(allowedTargets[i]);
            authorizedTargetsWithSelectors[i] = TargetSpecification({
                target: target,
                selector: selector,
                parameters: targetSet.allowedParameters[allowedTargets[i]]
            });
        }
        authorizedTargets = _authorizedTargets[user].values();
    }

    function addAuthorizedSelector(address user, bytes4 selector) external onlyOwnerOrThis {
        _authorizedSelectors[user].add(selector);
        emit AuthorizedSelectorAdded(user, selector);
    }

    function addAuthorizedTarget(address user, address target) external onlyOwnerOrThis {
        _authorizedTargets[user].add(target);
        emit AuthorizedTargetAdded(user, target);
    }

    function addAuthorizedTargetWithSelector(
        address user,
        address target,
        bytes4 selector,
        ParameterRequirement[] calldata parameters
    ) external onlyOwnerOrThis {
        bytes32 targetWithSelector = _encodeTargetWithSelector(target, selector);
        _authorizedTargetWithSelectors[user].allowedTargets.add(targetWithSelector);
        for (uint256 i; i < parameters.length; i++) {
            _authorizedTargetWithSelectors[user].allowedParameters[targetWithSelector].push(parameters[i]);
        }
        emit AuthorizedTargetWithSelectorAdded(user, target, selector);
    }

    function removeAuthorizedSelector(address user, bytes4 selector) external onlyOwnerOrThis {
        _authorizedSelectors[user].remove(selector);
        emit AuthorizedSelectorRemoved(user, selector);
    }

    function removeAuthorizedTarget(address user, address target) external onlyOwnerOrThis {
        _authorizedTargets[user].remove(target);
        emit AuthorizedTargetRemoved(user, target);
    }

    function removeAuthorizedTargetWithSelector(address user, address target, bytes4 selector)
        external
        onlyOwnerOrThis
    {
        bytes32 targetWithSelector = _encodeTargetWithSelector(target, selector);
        _authorizedTargetWithSelectors[user].allowedTargets.remove(targetWithSelector);
        delete _authorizedTargetWithSelectors[user].allowedParameters[targetWithSelector];
        emit AuthorizedTargetWithSelectorRemoved(user, target, selector);
    }

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
        bytes4 selector = _extractSelector(action.data);
        if (
            _authorizedSelectors[sender].contains(bytes32(selector))
                || _authorizedTargets[sender].contains(action.target)
        ) {
            return true;
        }
        bytes32 targetWithSelector = _encodeTargetWithSelector(action.target, selector);
        if (!_authorizedTargetWithSelectors[sender].allowedTargets.contains(targetWithSelector)) {
            return false;
        }
        ParameterRequirement[] memory parameters =
            _authorizedTargetWithSelectors[sender].allowedParameters[targetWithSelector];
        for (uint256 i; i < parameters.length; i++) {
            if ((parameters[i].index + 1) * 32 > action.data.length) {
                return false;
            }
            bytes32 parameterValue = bytes32(action.data[parameters[i].index * 32:(parameters[i].index + 1) * 32]);
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
