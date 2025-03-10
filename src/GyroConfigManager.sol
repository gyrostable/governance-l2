// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IGyroConfig.sol";

contract GyroConfigManager is Ownable {
    IGyroConfig public immutable config;

    constructor(address _config) Ownable(msg.sender) {
        config = IGyroConfig(_config);
    }

    function setPoolConfigUint(address pool, bytes32 key, uint256 value) external onlyOwner {
        bytes32 poolKey = _getPoolKey(pool, key);
        config.setUint(poolKey, value);
    }

    function setPoolConfigAddress(address pool, bytes32 key, address value) external onlyOwner {
        bytes32 poolKey = _getPoolKey(pool, key);
        config.setAddress(poolKey, value);
    }

    // NOTE: code from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/Proxy.sol
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    fallback() external onlyOwner {
        _delegate(address(config));
    }

    function _getPoolKey(address pool, bytes32 key) internal pure returns (bytes32) {
        return keccak256(abi.encode(key, pool));
    }
}
