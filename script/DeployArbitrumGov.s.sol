// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Deployment} from "./Deployment.sol";

contract DeployArbitrumGov is Deployment {
    // CCIP router (Arbitrum)
    // https://arbiscan.io/address/0x141fa059441E0ca23ce184B6A78bafD2A517DdE8
    address ccipRouter = 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8;

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        _deployL2Governance(ccipRouter);
    }
}
