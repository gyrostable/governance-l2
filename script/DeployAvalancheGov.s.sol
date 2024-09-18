// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Deployment} from "./Deployment.sol";

contract DeployAvalanceGov is Deployment {
    // CCIP router (Avalance)
    // https://snowtrace.io/address/0xF4c7E640EdA248ef95972845a62bdC74237805dB
    address ccipRouter = 0xF4c7E640EdA248ef95972845a62bdC74237805dB;

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        _deployL2Governance(ccipRouter);
    }
}
