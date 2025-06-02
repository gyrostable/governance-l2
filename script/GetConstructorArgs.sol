pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {Deployment} from "./Deployment.sol";
import {UUPSProxy} from "./UUPSProxy.sol";
import {GovernanceRoleManager} from "../src/GovernanceRoleManager.sol";

/// @notice Dump ABI-encoded constructor args for proxy contracts for verification.
// Duplicates functionality from Deployment.sol.
contract GetConstructorArgs is Deployment {
    /// @param owner The owner at deployment
    /// @param impl The implementation at deployment
    function governanceRoleManager(address owner, address impl) view public {
        bytes memory data = abi.encodeWithSelector(GovernanceRoleManager.initialize.selector, owner);
        bytes memory args = abi.encode(address(impl), data);
        console.logBytes(args);
    }
}
