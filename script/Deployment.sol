// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Strings} from "oz/utils/Strings.sol";
import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

import {UUPSProxy} from "./UUPSProxy.sol";
import {ICREATE3Factory} from "../src/interfaces/ICREATE3Factory.sol";
import {GyroL2Governance} from "../src/GyroL2Governance.sol";

contract Deployment is Script {
    // key to compute the L2 governance relayer deployment address
    string public L2_GOVERNANCE_RELAYER = "GyroscopeL2GovernanceRelayer";
    // key to compute the L2 governance deployment address
    string public L2_GOVERNANCE = "GyroscopeL2Governance";

    // https://etherscan.io/address/0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1
    ICREATE3Factory public factory = ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1);

    // https://etherscan.io/address/0x78EcF97572c3890eD02221A611014F30219f6219
    address public l1Governance = 0x78EcF97572c3890eD02221A611014F30219f6219;

    // https://docs.chain.link/ccip/supported-networks/v1_2_0/mainnet#ethereum-mainnet
    uint64 public mainnetChainSelector = 5_009_297_550_715_157_269;

    // https://etherscan.io/address/0x8bc920001949589258557412a32f8d297a74f244
    address public deployer = 0x8bc920001949589258557412A32F8d297A74F244;

    uint256 public deployerPrivateKey;

    function setUp() public virtual {
        deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
    }

    function _deployL2Governance(address ccipRouter_) internal {
        address l2GovernanceRelayer = _getDeployed(L2_GOVERNANCE_RELAYER);
        console.log("L2 Governance Relayer", l2GovernanceRelayer);
        GyroL2Governance impl = new GyroL2Governance();
        bytes memory data = abi.encodeWithSelector(
            GyroL2Governance.initialize.selector, ccipRouter_, l2GovernanceRelayer, mainnetChainSelector
        );
        bytes memory creationCode = abi.encodePacked(type(UUPSProxy).creationCode, abi.encode(address(impl), data));
        console.log("L2 Governance", _deploy(L2_GOVERNANCE, creationCode));
    }

    function _deploy(string memory name, bytes memory creationCode) internal returns (address) {
        bytes32 salt = keccak256(bytes(name));
        return factory.deploy(salt, creationCode);
    }

    function _getDeployed(string memory name) internal view returns (address) {
        bytes32 salt = keccak256(bytes(name));
        return factory.getDeployed(deployer, salt);
    }
}
