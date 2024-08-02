// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";

import {UUPSProxy} from "./UUPSProxy.sol";
import {Deployment} from "./Deployment.sol";

import {GyroL2GovernanceRelayer} from "../src/GyroL2GovernanceRelayer.sol";

contract DeployArbitrumGov is Deployment {
    // CCIP router (Ethereum)
    // https://etherscan.io/address/0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D
    address ccipRouter = 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D;

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        address l2Governance = _getDeployed(L2_GOVERNANCE);
        console.log("L2 Governance", l2Governance);
        GyroL2GovernanceRelayer impl = new GyroL2GovernanceRelayer();
        bytes memory data =
            abi.encodeWithSelector(GyroL2GovernanceRelayer.initialize.selector, l1Governance, l2Governance, ccipRouter);
        bytes memory creationCode = abi.encodePacked(type(UUPSProxy).creationCode, abi.encode(address(impl), data));
        console.log("L2 Governance relayer", _deploy(L2_GOVERNANCE_RELAYER, creationCode));
    }
}
