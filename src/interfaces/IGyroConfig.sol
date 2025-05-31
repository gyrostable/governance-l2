// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

interface IGyroConfig {
    function setUint(bytes32 key, uint256 newValue) external;

    function setAddress(bytes32 key, address newValue) external;

    function unset(bytes32 key) external;
}
