// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Deployment} from "./Deployment.sol";

contract DeployBaseGov is Deployment {
    // CCIP router (Base)
    // https://basescan.org/address/0x881e3A65B4d4a04dD529061dd0071cf975F58bCD
    address ccipRouter = 0x881e3A65B4d4a04dD529061dd0071cf975F58bCD;

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        _deployL2Governance(ccipRouter);
    }
}
