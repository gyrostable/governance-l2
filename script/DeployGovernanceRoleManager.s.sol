// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Deployment} from "./Deployment.sol";

import {console} from "forge-std/console.sol";

contract DeployGovernanceRoleManager is Deployment {
    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        // For now, we leave ownership with the deployer.
        // TODO Ultimately, this should be owned by L2 governance.
        address owner = vm.addr(deployerPrivateKey);
        console.log("owner", owner);
        _deployGovernanceRoleManager(owner);
    }
}
