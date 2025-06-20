// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {ERC1967Proxy} from "oz/proxy/ERC1967/ERC1967Proxy.sol";
import {Test, console} from "forge-std/Test.sol";
import {Client} from "ccip/libraries/Client.sol";

import {CCIPReceiverUpgradeable} from "../src/CCIPReceiverUpgradeable.sol";
import {DataTypes} from "../src/libraries/DataTypes.sol";
import {GyroL2Governance} from "../src/GyroL2Governance.sol";
import {DummyContract} from "./support/DummyContract.sol";

contract UpgradedGovernance is GyroL2Governance {
    bool public iAmUpgraded;

    function runUpgrade() public {
        iAmUpgraded = true;
    }
}

contract GyroL2GovernanceTest is Test {
    GyroL2Governance public l2Governance;
    DummyContract public dummy;
    DataTypes.ProposalAction public setValueAction;

    address ccipRouter = makeAddr("ccipRouter");
    address l1Governance = makeAddr("l1Governance");
    uint64 mainnetChainSelector = 11111111;

    function setUp() public {
        GyroL2Governance impl = new GyroL2Governance();
        bytes memory data =
            abi.encodeWithSelector(GyroL2Governance.initialize.selector, ccipRouter, l1Governance, mainnetChainSelector);
        l2Governance = GyroL2Governance(payable(address(new ERC1967Proxy(address(impl), data))));
        dummy = new DummyContract(address(l2Governance));
        setValueAction = _makeAction(address(dummy), abi.encodeWithSelector(dummy.setValue.selector, 42));
    }

    function test_receive_invalidMsgSender() external {
        Client.Any2EVMMessage memory message = _makeMessage(mainnetChainSelector, l1Governance, setValueAction);
        bytes memory err = abi.encodeWithSelector(CCIPReceiverUpgradeable.InvalidRouter.selector, address(this));
        vm.expectRevert(err);
        l2Governance.ccipReceive(message);
    }

    function test_receive_invalidSender() external {
        Client.Any2EVMMessage memory message = _makeMessage(mainnetChainSelector, address(this), setValueAction);
        vm.prank(ccipRouter);
        vm.expectRevert(GyroL2Governance.MessageInvalid.selector);
        l2Governance.ccipReceive(message);
    }

    function test_receive_invalidChain() external {
        Client.Any2EVMMessage memory message = _makeMessage(0, l1Governance, setValueAction);
        vm.prank(ccipRouter);
        vm.expectRevert(GyroL2Governance.MessageInvalid.selector);
        l2Governance.ccipReceive(message);
    }

    function test_receive() external {
        Client.Any2EVMMessage memory message = _makeMessage(mainnetChainSelector, l1Governance, setValueAction);
        vm.prank(ccipRouter);
        l2Governance.ccipReceive(message);
        assertEq(dummy.value(), 42);
    }

    function test_receive_multiActions() external {
        DataTypes.ProposalAction[] memory actions = new DataTypes.ProposalAction[](2);
        actions[0] = setValueAction;
        actions[1] = _makeAction(address(dummy), abi.encodeWithSelector(dummy.enableFlag.selector));
        Client.Any2EVMMessage memory message = _makeMessage(mainnetChainSelector, l1Governance, actions);
        vm.prank(ccipRouter);
        l2Governance.ccipReceive(message);
        assertEq(dummy.value(), 42);
        assertTrue(dummy.flag());
    }

    function test_upgrade() external {
        UpgradedGovernance upgraded = new UpgradedGovernance();
        DataTypes.ProposalAction memory action = _makeAction(
            address(l2Governance),
            abi.encodeWithSelector(
                l2Governance.upgradeToAndCall.selector,
                address(upgraded),
                abi.encodeWithSelector(upgraded.runUpgrade.selector)
            )
        );
        Client.Any2EVMMessage memory message = _makeMessage(mainnetChainSelector, l1Governance, action);
        vm.prank(ccipRouter);
        l2Governance.ccipReceive(message);
        assertTrue(UpgradedGovernance(payable(address(l2Governance))).iAmUpgraded());
    }

    function _makeAction(address target, bytes memory data) internal pure returns (DataTypes.ProposalAction memory) {
        return DataTypes.ProposalAction({target: target, data: data, value: 0});
    }

    function _makeMessage(uint64 chainSelector, address sender, DataTypes.ProposalAction memory action)
        internal
        pure
        returns (Client.Any2EVMMessage memory)
    {
        DataTypes.ProposalAction[] memory actions = new DataTypes.ProposalAction[](1);
        actions[0] = action;
        return _makeMessage(chainSelector, sender, actions);
    }

    function _makeMessage(uint64 chainSelector, address sender, DataTypes.ProposalAction[] memory actions)
        internal
        pure
        returns (Client.Any2EVMMessage memory)
    {
        return Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: chainSelector,
            sender: abi.encode(sender),
            data: abi.encode(actions),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });
    }
}
