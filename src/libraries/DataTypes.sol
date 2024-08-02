// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

library DataTypes {
    /// @notice Proposal action as defined in L1 governance contract
    struct ProposalAction {
        address target;
        bytes data;
        uint256 value;
    }
}
