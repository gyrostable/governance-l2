// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Address} from "oz/utils/Address.sol";
import {Initializable} from "upgradeable/proxy/utils/Initializable.sol";
import {CCIPReceiverUpgradeable} from "./CCIPReceiverUpgradeable.sol";
import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Client} from "ccip/libraries/Client.sol";
import {IRouterClient} from "ccip/interfaces/IRouterClient.sol";

import {DataTypes} from "./libraries/DataTypes.sol";

contract GyroL2Governance is CCIPReceiverUpgradeable, Initializable, UUPSUpgradeable {
    using Address for address;

    /// @notice This error is raised if message from the bridge is invalid
    error MessageInvalid();

    /// @notice The CCIP router contract
    IRouterClient public router;

    /// @notice The address of the Gyroscope governance relayer on Ethereum mainnet
    address public l1GovernanceRelayer;

    /// @notice Chain selector of Ethereum mainnet on CCIP
    uint64 public mainnetChainSelector;

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice L2Gyd initializer
     * @dev This initializer should be called via UUPSProxy constructor
     * @param routerAddress_ The CCIP router address
     * @param l1GovernanceRelayer_ the address of the Gyroscope governance contract on Ethereum mainnet
     * @param mainnetChainSelector_ The chain selector of Ethereum mainnet on CCIP
     */
    function initialize(address routerAddress_, address l1GovernanceRelayer_, uint64 mainnetChainSelector_)
        public
        initializer
    {
        __UUPSUpgradeable_init();
        __CCIPReceiverUpgradeable_init(routerAddress_);

        router = IRouterClient(routerAddress_);
        l1GovernanceRelayer = l1GovernanceRelayer_;
        mainnetChainSelector = mainnetChainSelector_;
    }

    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal virtual override {
        if (any2EvmMessage.sourceChainSelector != mainnetChainSelector) {
            revert MessageInvalid();
        }
        address actualSender = abi.decode(any2EvmMessage.sender, (address));
        if (actualSender != l1GovernanceRelayer) {
            revert MessageInvalid();
        }
        DataTypes.ProposalAction[] memory actions = abi.decode(any2EvmMessage.data, (DataTypes.ProposalAction[]));
        for (uint256 i; i < actions.length; i++) {
            actions[i].target.functionCallWithValue(actions[i].data, actions[i].value);
        }
    }

    /// @dev Only L1 governance can upgrade this contract
    /// by having `upgradeToAndCall` as a proposal action,
    /// which will cause this contract to call `upgradeToAndCall`
    /// on itself, effectively setting the `msg.sender` to `address(this)`
    /// when called
    function _authorizeUpgrade(address) internal virtual override {
        if (msg.sender != address(this)) revert UUPSUnauthorizedCallContext();
    }

    receive() external payable {}
}
