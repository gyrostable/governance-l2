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

    function someOtherFunction(bytes32 _value, uint256 b, address c) external {}

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

    function test_recursiveRule() public {
        address otherUser = makeAddr("otherUser");

        bytes4 selector = MockTarget.someOtherFunction.selector;
        GovernanceRoleManager.ParameterRequirement[] memory params = new GovernanceRoleManager.ParameterRequirement[](4);
        params[0] =
            GovernanceRoleManager.ParameterRequirement({index: 1, value: bytes32(uint256(uint160(address(target))))});
        params[1] = GovernanceRoleManager.ParameterRequirement({index: 2, value: bytes32(selector)});
        // abi.encode([(0, "foo")]) will be encoded as:
        // offset + length + 0 + "foo" (all as 32 bytes values)
        // so the offset of 0 is 5 * 32 and "foo" is 6 * 32
        // see https://docs.soliditylang.org/en/develop/abi-spec.html#use-of-dynamic-types for details
        params[2] = GovernanceRoleManager.ParameterRequirement({index: 5, value: bytes32(uint256(0))});
        params[3] = GovernanceRoleManager.ParameterRequirement({index: 6, value: bytes32("foo")});

        vm.prank(owner);
        manager.addPermission(user, address(manager), GovernanceRoleManager.addPermission.selector, params);

        params = new GovernanceRoleManager.ParameterRequirement[](1);
        params[0] = GovernanceRoleManager.ParameterRequirement({index: 0, value: bytes32("foo")});

        DataTypes.ProposalAction[] memory actions = new DataTypes.ProposalAction[](1);
        actions[0] = DataTypes.ProposalAction({
            target: address(manager),
            value: 0,
            data: abi.encodeWithSelector(
                GovernanceRoleManager.addPermission.selector, otherUser, address(target), selector, params
            )
        });

        vm.prank(user);
        manager.executeActions(actions);

        actions[0] = DataTypes.ProposalAction({
            target: address(target),
            value: 0,
            data: abi.encodeWithSelector(selector, bytes32("foo"), 20, address(0))
        });

        vm.prank(otherUser);
        manager.executeActions(actions);

        actions[0] = DataTypes.ProposalAction({
            target: address(target),
            value: 0,
            data: abi.encodeWithSelector(selector, bytes32("bar"), 20, address(0))
        });

        vm.expectRevert(GovernanceRoleManager.NotAuthorized.selector);
        vm.prank(otherUser);
        manager.executeActions(actions);
    }
}
