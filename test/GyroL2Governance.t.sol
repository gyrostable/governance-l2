// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {GyroL2Governance} from "../src/GyroL2Governance.sol";

contract GyroL2GovernanceTest is Test {
    GyroL2Governance public l2Governance;

    function setUp() public {
        l2Governance = new GyroL2Governance();
    }
}
