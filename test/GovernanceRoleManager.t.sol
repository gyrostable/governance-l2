// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {GovernanceRoleManager} from "../src/GovernanceRoleManager.sol";
import {DataTypes} from "../src/libraries/DataTypes.sol";
import {ERC1967Proxy} from "oz/proxy/ERC1967/ERC1967Proxy.sol";

contract MockTarget {
    uint256 public value;
    string public message;

    function setValue(uint256 _value) external payable {
        value = _value;
    }

    function setMessage(string calldata _message) external {
        message = _message;
    }

    receive() external payable {}
}

contract GovernanceRoleManagerTest is Test {
    GovernanceRoleManager public manager;
    MockTarget public target;
    address public owner;
    address public user;

    event AuthorizedTargetAdded(
        address indexed user,
        address indexed target,
        bytes4 indexed selector,
        GovernanceRoleManager.ParameterRequirement[] parameters
    );
    event AuthorizedTargetRemoved(address indexed user, address indexed target, bytes4 indexed selector);
    event ActionExecuted(address indexed user, DataTypes.ProposalAction indexed action);

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");

        GovernanceRoleManager implementation = new GovernanceRoleManager();
        bytes memory initData = abi.encodeCall(GovernanceRoleManager.initialize, (owner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        manager = GovernanceRoleManager(address(proxy));
        target = new MockTarget();
    }

    function test_Initialize() public view {
        assertEq(manager.owner(), owner);
    }

    function test_AddPermission() public {
        vm.startPrank(owner);

        bytes4 selector = MockTarget.setValue.selector;
        GovernanceRoleManager.ParameterRequirement[] memory params = new GovernanceRoleManager.ParameterRequirement[](1);
        params[0] = GovernanceRoleManager.ParameterRequirement({index: 0, value: bytes32(uint256(100))});

        vm.expectEmit(true, true, true, true);
        emit AuthorizedTargetAdded(user, address(target), selector, params);

        manager.addPermission(user, address(target), selector, params);

        GovernanceRoleManager.Permission[] memory permissions = manager.getPermissions(user);
        assertEq(permissions.length, 1);
        assertEq(permissions[0].target, address(target));
        assertEq(permissions[0].selector, selector);
        assertEq(permissions[0].parameters.length, 1);
        assertEq(permissions[0].parameters[0].index, 0);
        assertEq(permissions[0].parameters[0].value, bytes32(uint256(100)));
    }

    function test_RemovePermission() public {
        vm.startPrank(owner);

        bytes4 selector = MockTarget.setValue.selector;
        GovernanceRoleManager.ParameterRequirement[] memory params = new GovernanceRoleManager.ParameterRequirement[](0);

        manager.addPermission(user, address(target), selector, params);

        vm.expectEmit(true, true, true, true);
        emit AuthorizedTargetRemoved(user, address(target), selector);

        manager.removePermission(user, address(target), selector);

        GovernanceRoleManager.Permission[] memory permissions = manager.getPermissions(user);
        assertEq(permissions.length, 0);
    }

    function test_ExecuteAction() public {
        vm.startPrank(owner);

        bytes4 selector = MockTarget.setValue.selector;
        GovernanceRoleManager.ParameterRequirement[] memory params = new GovernanceRoleManager.ParameterRequirement[](1);
        params[0] = GovernanceRoleManager.ParameterRequirement({index: 0, value: bytes32(uint256(100))});

        manager.addPermission(user, address(target), selector, params);

        vm.stopPrank();
        vm.startPrank(user);

        DataTypes.ProposalAction[] memory actions = new DataTypes.ProposalAction[](1);
        actions[0] =
            DataTypes.ProposalAction({target: address(target), value: 0, data: abi.encodeWithSelector(selector, 100)});

        manager.executeActions(actions);

        assertEq(target.value(), 100);
    }

    function test_ExecuteAction_WithValue() public {
        vm.startPrank(owner);

        bytes4 selector = MockTarget.setValue.selector;
        GovernanceRoleManager.ParameterRequirement[] memory params = new GovernanceRoleManager.ParameterRequirement[](0);

        manager.addPermission(user, address(target), selector, params);

        vm.deal(address(manager), 1 ether);

        vm.stopPrank();
        vm.startPrank(user);

        DataTypes.ProposalAction[] memory actions = new DataTypes.ProposalAction[](1);
        actions[0] = DataTypes.ProposalAction({
            target: address(target),
            value: 1 ether,
            data: abi.encodeWithSelector(selector, 100)
        });

        manager.executeActions(actions);

        assertEq(address(target).balance, 1 ether);
        assertEq(target.value(), 100);
    }

    function test_WildcardTarget() public {
        vm.startPrank(owner);

        bytes4 selector = MockTarget.setValue.selector;
        GovernanceRoleManager.ParameterRequirement[] memory params = new GovernanceRoleManager.ParameterRequirement[](0);

        manager.addPermission(user, address(0), selector, params);

        vm.stopPrank();
        vm.startPrank(user);

        DataTypes.ProposalAction[] memory actions = new DataTypes.ProposalAction[](1);
        actions[0] =
            DataTypes.ProposalAction({target: address(target), value: 0, data: abi.encodeWithSelector(selector, 100)});

        manager.executeActions(actions);

        assertEq(target.value(), 100);
    }

    function test_WildcardSelector() public {
        vm.startPrank(owner);

        GovernanceRoleManager.ParameterRequirement[] memory params = new GovernanceRoleManager.ParameterRequirement[](0);

        manager.addPermission(user, address(target), bytes4(0), params);

        vm.stopPrank();
        vm.startPrank(user);

        DataTypes.ProposalAction[] memory actions = new DataTypes.ProposalAction[](2);
        actions[0] = DataTypes.ProposalAction({
            target: address(target),
            value: 0,
            data: abi.encodeWithSelector(MockTarget.setValue.selector, 100)
        });
        actions[1] = DataTypes.ProposalAction({
            target: address(target),
            value: 0,
            data: abi.encodeWithSelector(MockTarget.setMessage.selector, "Hello")
        });

        manager.executeActions(actions);

        assertEq(target.value(), 100);
        assertEq(target.message(), "Hello");
    }

    function test_UnauthorizedAction_reverts() public {
        vm.prank(user);

        DataTypes.ProposalAction[] memory actions = new DataTypes.ProposalAction[](1);
        actions[0] = DataTypes.ProposalAction({
            target: address(target),
            value: 0,
            data: abi.encodeWithSelector(MockTarget.setValue.selector, 100)
        });

        vm.expectRevert(GovernanceRoleManager.NotAuthorized.selector);
        manager.executeActions(actions);
    }

    function test_UnauthorizedParameter_reverts() public {
        vm.startPrank(owner);

        bytes4 selector = MockTarget.setValue.selector;
        GovernanceRoleManager.ParameterRequirement[] memory params = new GovernanceRoleManager.ParameterRequirement[](1);
        params[0] = GovernanceRoleManager.ParameterRequirement({index: 0, value: bytes32(uint256(100))});

        manager.addPermission(user, address(target), selector, params);

        vm.stopPrank();
        vm.prank(user);

        DataTypes.ProposalAction[] memory actions = new DataTypes.ProposalAction[](1);
        actions[0] =
            DataTypes.ProposalAction({target: address(target), value: 0, data: abi.encodeWithSelector(selector, 100)});

        manager.executeActions(actions);
        assertEq(target.value(), 100);

        actions[0] = DataTypes.ProposalAction({
            target: address(target),
            value: 0,
            data: abi.encodeWithSelector(selector, 200) // Wrong parameter value
        });

        vm.expectRevert(GovernanceRoleManager.NotAuthorized.selector);
        manager.executeActions(actions);
    }
}
