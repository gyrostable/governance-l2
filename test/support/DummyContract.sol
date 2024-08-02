// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Ownable} from "oz/access/Ownable.sol";

contract DummyContract is Ownable {
    uint256 public value;
    bool public flag;

    constructor(address owner_) Ownable(owner_) {}

    function setValue(uint256 v) public {
        value = v;
    }

    function enableFlag() public {
        flag = true;
    }
}
