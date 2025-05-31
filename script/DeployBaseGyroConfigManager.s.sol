// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Deployment} from "./Deployment.sol";

contract DeployBaseGyroConfigManager is Deployment {
    address gyroConfig = 0x8A5eB9A5B726583a213c7e4de2403d2DfD42C8a6;

    // Requires a deployed GovernanceRoleManager in this form.
    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        _deployGyroConfigManager(gyroConfig, _getDeployed(GOVERNANCE_ROLE_MANAGER));
    }
}
