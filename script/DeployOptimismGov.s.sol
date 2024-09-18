// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Deployment} from "./Deployment.sol";

contract DeployOptimismGov is Deployment {
    // CCIP router (Optimism)
    // https://optimistic.etherscan.io/address/0x3206695CaE29952f4b0c22a169725a865bc8Ce0f
    address ccipRouter = 0x3206695CaE29952f4b0c22a169725a865bc8Ce0f;

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        _deployL2Governance(ccipRouter);
    }
}
