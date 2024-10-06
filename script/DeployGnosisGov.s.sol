// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Deployment} from "./Deployment.sol";

contract DeployGnosisGov is Deployment {
    // CCIP router (Gnosis)
    // https://gnosisscan.io/address/0x4aAD6071085df840abD9Baf1697d5D5992bDadce
    address ccipRouter = 0x4aAD6071085df840abD9Baf1697d5D5992bDadce;

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        _deployL2Governance(ccipRouter);
    }
}
