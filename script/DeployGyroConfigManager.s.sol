// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Deployment} from "./Deployment.sol";

contract DeployGyroConfigManager is Deployment {
    address gyroConfig;

    function setUp() public override {
        Deployment.setUp();

        if (block.chainid == 8453) {  // Base
            gyroConfig = 0x8A5eB9A5B726583a213c7e4de2403d2DfD42C8a6;
        } else if (block.chainid == 10) {  // Optimism
            gyroConfig = 0x32Acb44fC929339b9F16F0449525cC590D2a23F3;
        } else if (block.chainid == 42161) { // Arbitrum 
            gyroConfig = 0x9b683cA24B0e013512E2566b68704dBe9677413c;
        // TODO more chains
        } else {
            revert("Unknown chain");
        }
    }

    // Requires a deployed GovernanceRoleManager in this form.
    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        _deployGyroConfigManager(gyroConfig, _getDeployed(GOVERNANCE_ROLE_MANAGER));
    }
}
