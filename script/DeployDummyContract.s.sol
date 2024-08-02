// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";

import {Deployment} from "./Deployment.sol";
import {DummyContract} from "../test/support/DummyContract.sol";

contract DeployDummyContract is Deployment {
    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        address l2Governance = _getDeployed(L2_GOVERNANCE);
        console.log("L2 governance", l2Governance);
        address dummyContract = address(new DummyContract(l2Governance));
        console.log("Dummy Contract", dummyContract);
    }
}
