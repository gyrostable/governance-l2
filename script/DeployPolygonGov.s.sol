// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Deployment} from "./Deployment.sol";

contract DeployPolygonGov is Deployment {
    // CCIP router (Polygon)
    // https://polygonscan.com/address/0x849c5ED5a80F5B408Dd4969b78c2C8fdf0565Bfe
    address ccipRouter = 0x849c5ED5a80F5B408Dd4969b78c2C8fdf0565Bfe;

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        _deployL2Governance(ccipRouter);
    }
}
