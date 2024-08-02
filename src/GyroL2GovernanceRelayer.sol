// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Address} from "oz/utils/Address.sol";
import {OwnableUpgradeable} from "upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Client} from "ccip/libraries/Client.sol";
import {IRouterClient} from "ccip/interfaces/IRouterClient.sol";

import {DataTypes} from "./libraries/DataTypes.sol";

contract GyroL2GovernanceRelayer is OwnableUpgradeable, UUPSUpgradeable {
    using Address for address payable;

    IRouterClient public ccipRouter;
    address public l2Governance;

    constructor() {
        _disableInitializers();
    }

    function initialize(address l1Governance, address l2Governance_, IRouterClient ccipRouter_) public initializer {
        __Ownable_init(l1Governance);
        ccipRouter = ccipRouter_;
        l2Governance = l2Governance_;
    }

    function executeL2Proposal(uint64 chainSelector, DataTypes.ProposalAction[] memory actions, uint256 gasLimit)
        external
        payable
        onlyOwner
    {
        Client.EVM2AnyMessage memory message = _makeMessage(actions, gasLimit);
        uint256 fees = ccipRouter.getFee(chainSelector, message);
        ccipRouter.ccipSend{value: fees}(chainSelector, message);
        if (msg.value > fees) {
            payable(msg.sender).sendValue(msg.value - fees);
        }
    }

    function getFees(uint64 chainSelector, DataTypes.ProposalAction[] memory actions, uint256 gasLimit)
        external
        view
        returns (uint256)
    {
        Client.EVM2AnyMessage memory message = _makeMessage(actions, gasLimit);
        return ccipRouter.getFee(chainSelector, message);
    }

    function _makeMessage(DataTypes.ProposalAction[] memory actions, uint256 gasLimit)
        internal
        view
        returns (Client.EVM2AnyMessage memory)
    {
        return Client.EVM2AnyMessage({
            receiver: abi.encode(l2Governance),
            data: abi.encode(actions),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            feeToken: address(0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: gasLimit}))
        });
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner {}

    receive() external payable {}
}
