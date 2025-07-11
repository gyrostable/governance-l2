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
        } else if (block.chainid == 1) { // Mainnet
            gyroConfig = 0xaC89cc9d78BBAd7EB3a02601B4D65dAa1f908aA6;
        } else if (block.chainid == 1329) { // Sei
            gyroConfig = 0x194941B55555Afd751285B8b792C7538152DeAdd;
        } else if (block.chainid == 43114) { // Avalanche
            gyroConfig = 0x8A5eB9A5B726583a213c7e4de2403d2DfD42C8a6;
        } else if (block.chainid == 137) { // Polygon
            gyroConfig = 0xFdc2e9E03f515804744A40d0f8d25C16e93fbE67;
        } else if (block.chainid == 146) {// Sonic
            gyroConfig = 0xEeceE50a4333C8B8a8f76c81b6092477AE8Ea81b;
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
