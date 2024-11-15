// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {console2} from "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {DataTypes} from "src/libraries/DataTypes.sol";
import {GyroL2Governance} from "../src/GyroL2Governance.sol";
import {GyroL2GovernanceRelayer } from "../src/GyroL2GovernanceRelayer.sol";

/// @notice Generates calldata for use in L1 governance proposals for various actions. Doesn't
/// broadcast.
contract GenerateCalldata is Script {
    // Same on all 
    address public constant L2_GOVERNANCE = 0xd62bb3c3D6C7BD5C6bA64aA4D7BF05aE6AD10568;

    // On Mainnet
    address payable public constant L1_L2_GOVERNANCE_RELAYER = payable(0xD04163582C4F6CCcBd3B0188d44cB62a9ce44B9F);

    mapping(string => uint64) chainSelectors;

    // Just something large. It doesn't really matter.
    // NOTE This *can* matter if we're doing a complicated contract call! Or a larger proposal action!
    // E.g., the one-sided pool joiner takes ~4M gas. But if it fails we can execute externally so w/e.
    uint256 public constant GAS_LIMIT = 200e3;

    function setUp() public virtual {
        // chainSelectors["mainnet"] = 5009297550715157269;
        chainSelectors["arbitrum"] = 4949039107694359620;
        chainSelectors["optimism"] = 3734403246176062136;
        chainSelectors["avalanche"] = 6433500567565415381;
        chainSelectors["polygon"] = 4051577828743386545;
        chainSelectors["base"] = 15971525489660198786;
        chainSelectors["gnosis"] = 465200170687744372;
    }

    function getChainSelector(string memory chainName) public view returns (uint64 selector) {
        selector = chainSelectors[chainName];
        require(selector != 0, "Chain name not found");
    }

    /// @notice Generate a token transfer from the L2 governance contract to some recipient.
    function transfer(string memory chainName, address tokenAddress, address recipient, uint256 amountRaw) public view {
        uint64 chainSelector = getChainSelector(chainName);
        bytes memory transferData = abi.encodeWithSelector(IERC20.transfer.selector, recipient, amountRaw);
        DataTypes.ProposalAction[] memory l2Actions = new DataTypes.ProposalAction[](1);
        l2Actions[0] = DataTypes.ProposalAction({
            target: tokenAddress,
            data: transferData,
            value: 0
        });

        bytes memory relayerData = abi.encodeWithSelector(GyroL2GovernanceRelayer.executeL2Proposal.selector, chainSelector, l2Actions, GAS_LIMIT);

        GyroL2GovernanceRelayer governanceRelayer = GyroL2GovernanceRelayer(L1_L2_GOVERNANCE_RELAYER);
        uint256 fee = governanceRelayer.getFees(chainSelector, l2Actions, GAS_LIMIT);

        // Safety margin of * 2. We get reimbursed for too high fees and also, fees are small (< $1).
        fee = fee * 2;

        console.log("Use the following ProposalAction attributes in a governance proposal:");
        console.log("target:", L1_L2_GOVERNANCE_RELAYER);
        // console.log("data", relayerData);
        console.log("data:");
        console2.logBytes(relayerData);
        console.log("value:", fee);
    }
}
