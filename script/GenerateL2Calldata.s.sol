// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

import {GyroConfigManager} from "src/GyroConfigManager.sol";

/// @notice Generates calldata for use in GovernanceRoleManager interactions. Doesn't use the message bridge or broadcast.
contract GenerateL2Calldata is Script {
    function setPoolConfigUint(address pool, string memory key, uint256 value) public view {
        bytes32 keyBytes = bytes32(bytes(key));
        bytes memory cdata = abi.encodeWithSelector(GyroConfigManager.setPoolConfigUint.selector, pool, keyBytes, value);
        console.logBytes(cdata);
    }

    function setPoolConfigAddress(address pool, string memory key, address value) public view {
        bytes32 keyBytes = bytes32(bytes(key));
        bytes memory cdata = abi.encodeWithSelector(GyroConfigManager.setPoolConfigAddress.selector, pool, keyBytes, value);
        console.logBytes(cdata);
    }

    function setProtocolFee(address pool, uint256 value) public view {
        setPoolConfigUint(pool, "PROTOCOL_SWAP_FEE_PERC", value);
    }

    function setProtocolFeeGyroPortion(address pool, uint256 value) public view {
        setPoolConfigUint(pool, "PROTOCOL_FEE_GYRO_PORTION", value);
    }
}

