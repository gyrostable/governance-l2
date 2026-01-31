// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Address} from "oz/utils/Address.sol";
import {console} from "forge-std/console.sol";
import {console2} from "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {DataTypes} from "src/libraries/DataTypes.sol";
import {GyroL2Governance} from "../src/GyroL2Governance.sol";
import {GyroL2GovernanceRelayer} from "../src/GyroL2GovernanceRelayer.sol";

interface MultisigTimelock {
    function queueProposal(DataTypes.ProposalAction[] calldata actions) external;
    function executeProposal() external;
}

/// @notice Generates calldata for use in L1 governance proposals for various actions. Doesn't
/// broadcast.
contract GenerateCalldata is Script {
    using Address for address;

    // Same on all
    address public constant L2_GOVERNANCE = 0xd62bb3c3D6C7BD5C6bA64aA4D7BF05aE6AD10568;

    // On Mainnet
    address payable public constant L1_L2_GOVERNANCE_RELAYER = payable(0xD04163582C4F6CCcBd3B0188d44cB62a9ce44B9F);

    address govMultisig = 0x2d9FaF0b633FF6c4170E171dAe80909f3D03453C;

    address mainnetGydProxy = 0xe07F9D810a48ab5c3c914BA3cA53AF14E4491e8A;
    address mainnetGydPaused = 0x511cc903377EF0FffC10434a8eaA06E63E563471;
    address mainnetProxyAdmin = 0x581aE43498196e3Dc274F3F23FF7718d287BC2C6;

    address l2GydProxy = 0xCA5d8F8a8d49439357d3CF46Ca2e720702F132b8;
    address l2GyfiProxy = 0xc63529297dE076eB15fcbE873AE9136E446cFbB9;

    mapping(string => uint64) chainSelectors;

    mapping(string => address) l2GydPaused;
    mapping(string => address) l2GyfiPaused;

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
        chainSelectors["bsc"] = 11344663589394136015;
        chainSelectors["sonic"] = 1673871237479749969;
        chainSelectors["sei"] = 9027416829622342829;

        // ## GYD
        l2GydPaused["arbitrum"] = 0xe3D633fBBd137C78E188D3e8358D4e7747361645;
        l2GydPaused["base"] = 0xA08c6089e2A0DCadc42CDb1c03DfDb3cd2098FF9;
        l2GydPaused["avalanche"] = 0x0DE28b95913134F55c4A8e75c24393B29F526a53;
        l2GydPaused["optimism"] = 0x0f19cf6c3c7e480183DCFaC919a0c6F90d667579;
        l2GydPaused["polygon"] = 0x2531F5FcfBcF803308AFc4F1442F6674034Af4e0;
        l2GydPaused["gnosis"] = 0x7313d18C41F767B0358Bcab345992cF0a3a79030;
        l2GydPaused["bsc"] = 0x253652109B6aD856621BAD8a55c1c565F5B8734B;

        // ## GYFI
        l2GyfiPaused["arbitrum"] = 0xe4Be2cFB5Ec44c33a9C9A1C9290D495A484bC889;
        l2GyfiPaused["base"] = 0x41c205Ef2f2E7FA709d297f64E3D785A8c1eC0F7;
        l2GyfiPaused["avalanche"] = 0x5FCc7c7AaFa841591ab3226F1B3648800F6b0344;
        l2GyfiPaused["optimism"] = 0x9C5a5225967865C4AD53f679c8E735CA78A97e1A;
        l2GyfiPaused["polygon"] = 0x6528025A03842c58d7ffd5e571F877C971bE3f96;
        l2GyfiPaused["gnosis"] = 0x2Df9Fca046dCbf2c91960490c9B409DBF5c8ccb0;
        l2GyfiPaused["sonic"] = 0x194941B55555Afd751285B8b792C7538152DeAdd;
        l2GyfiPaused["sei"] = 0xf7f808e3eA7E7AB00938db17C622b07C40ffA38C;
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
        l2Actions[0] = DataTypes.ProposalAction({target: tokenAddress, data: transferData, value: 0});

        bytes memory relayerData = abi.encodeWithSelector(
            GyroL2GovernanceRelayer.executeL2Proposal.selector, chainSelector, l2Actions, GAS_LIMIT
        );

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

    function _createL1Action(string memory chainName) public view returns (DataTypes.ProposalAction memory) {
        bytes4 selector = UUPSUpgradeable.upgradeToAndCall.selector;

        uint256 actionsCount = 0;
        address l2GyfiAddress = l2GyfiPaused[chainName];
        address l2GydAddress = l2GydPaused[chainName];
        if (l2GyfiAddress != address(0)) {
            actionsCount++;
        }
        if (l2GydAddress != address(0)) {
            actionsCount++;
        }

        uint256 index = 0;
        DataTypes.ProposalAction[] memory l2Actions = new DataTypes.ProposalAction[](actionsCount);
        if (l2GyfiAddress != address(0)) {
            l2Actions[index++] = DataTypes.ProposalAction({
                target: l2GyfiProxy, data: abi.encodeWithSelector(selector, l2GyfiAddress, ""), value: 0
            });
        }
        if (l2GydAddress != address(0)) {
            l2Actions[index++] = DataTypes.ProposalAction({
                target: l2GydProxy, data: abi.encodeWithSelector(selector, l2GydAddress, ""), value: 0
            });
        }

        uint64 chainSelector = getChainSelector(chainName);
        GyroL2GovernanceRelayer governanceRelayer = GyroL2GovernanceRelayer(L1_L2_GOVERNANCE_RELAYER);
        uint256 fee = governanceRelayer.getFees(chainSelector, l2Actions, GAS_LIMIT) * 2;
        DataTypes.ProposalAction memory l1Action = DataTypes.ProposalAction({
            target: L1_L2_GOVERNANCE_RELAYER,
            data: abi.encodeWithSelector(
                GyroL2GovernanceRelayer.executeL2Proposal.selector, chainSelector, l2Actions, GAS_LIMIT
            ),
            value: fee
        });

        console.log("Running on chain:", chainName);
        console.log("L2 actions length:", l2Actions.length);
        console.log("Fee:", fee);

        return l1Action;
    }

    // forge script script/GenerateCalldata.s.sol -s 'pauseL2Tokens()' --rpc-url mainnet
    // Paste data output in custom data of the Safe UI
    function pauseL2Tokens() public view returns (bytes memory) {
        string[9] memory chainNames =
            ["arbitrum", "base", "avalanche", "optimism", "polygon", "gnosis", "bsc", "sonic", "sei"];
        DataTypes.ProposalAction[] memory l1Actions = new DataTypes.ProposalAction[](chainNames.length + 1);
        for (uint256 i = 0; i < chainNames.length; i++) {
            l1Actions[i] = _createL1Action(chainNames[i]);
        }

        DataTypes.ProposalAction memory upgradeMainnetGyd = DataTypes.ProposalAction({
            target: mainnetProxyAdmin,
            data: abi.encodeWithSignature("upgrade(address,address)", mainnetGydProxy, mainnetGydPaused),
            value: 0
        });
        l1Actions[chainNames.length] = upgradeMainnetGyd;

        console.log("Use the following ProposalAction attributes in a governance proposal:");
        bytes memory data = abi.encodeWithSelector(MultisigTimelock.queueProposal.selector, l1Actions);
        console.log("data:");
        console2.logBytes(data);
        return data;
    }

    // forge script script/GenerateCalldata.s.sol -s 'testPauseL2Tokens()' --fork-url mainnet
    function testPauseL2Tokens() public {
        MultisigTimelock multisigTimelock = MultisigTimelock(0xD59fA68cA9fD50eE79D1a0028910Fe71C6df4dC1);
        bytes memory data = pauseL2Tokens();
        vm.prank(govMultisig);
        address(multisigTimelock).functionCall(data);

        vm.warp(block.timestamp + 3601);
        vm.prank(govMultisig);
        multisigTimelock.executeProposal();
    }
}
