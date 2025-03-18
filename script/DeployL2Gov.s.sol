// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Deployment} from "./Deployment.sol";

contract DeployL2Gov is Deployment {
    mapping(uint256 => address) public ccipRouters;

    function setUp() public override {
        super.setUp();

        // https://optimistic.etherscan.io/address/0x3206695CaE29952f4b0c22a169725a865bc8Ce0f
        ccipRouters[10] = 0x3206695CaE29952f4b0c22a169725a865bc8Ce0f;

        // https://gnosisscan.io/address/0x4aAD6071085df840abD9Baf1697d5D5992bDadce
        ccipRouters[100] = 0x4aAD6071085df840abD9Baf1697d5D5992bDadce;

        // https://polygonscan.com/address/0x849c5ED5a80F5B408Dd4969b78c2C8fdf0565Bfe
        ccipRouters[137] = 0x849c5ED5a80F5B408Dd4969b78c2C8fdf0565Bfe;

        // https://sonicscan.org/address/0xB4e1Ff7882474BB93042be9AD5E1fA387949B860
        ccipRouters[146] = 0xB4e1Ff7882474BB93042be9AD5E1fA387949B860;

        // https://zkevm.polygonscan.com/address/0xA9999937159B293c72e2367Ce314cb3544e7C1a3
        ccipRouters[1101] = 0xA9999937159B293c72e2367Ce314cb3544e7C1a3;

        // https://seitrace.com/address/0xAba60dA7E88F7E8f5868C2B6dE06CB759d693af0
        ccipRouters[1329] = 0xAba60dA7E88F7E8f5868C2B6dE06CB759d693af0;

        // https://basescan.org/address/0x881e3A65B4d4a04dD529061dd0071cf975F58bCD
        ccipRouters[8453] = 0x881e3A65B4d4a04dD529061dd0071cf975F58bCD;

        // https://arbiscan.io/address/0x141fa059441E0ca23ce184B6A78bafD2A517DdE8
        ccipRouters[42161] = 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8;

        // https://snowtrace.io/address/0xF4c7E640EdA248ef95972845a62bdC74237805dB
        ccipRouters[43114] = 0xF4c7E640EdA248ef95972845a62bdC74237805dB;
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        address ccipRouter = ccipRouters[block.chainid];
        if (ccipRouter == address(0)) {
            revert("L2 governance not found");
        }
        _deployL2Governance(ccipRouter);
    }
}
