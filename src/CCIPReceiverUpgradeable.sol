// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAny2EVMMessageReceiver} from "ccip/interfaces/IAny2EVMMessageReceiver.sol";

import {Client} from "ccip/libraries/Client.sol";

import {IERC165} from "oz/utils/introspection/IERC165.sol";

/// @title CCIPReceiverUpgradeable - Base contract for CCIP applications that
/// can receive messages.
/// @dev This contract is copied from CCIPReceiver but avoids using constructor
abstract contract CCIPReceiverUpgradeable is IAny2EVMMessageReceiver, IERC165 {
    address internal i_ccipRouter;

    function __CCIPReceiverUpgradeable_init(address router) internal {
        if (router == address(0)) revert InvalidRouter(address(0));
        i_ccipRouter = router;
    }

    /// @notice IERC165 supports an interfaceId
    /// @param interfaceId The interfaceId to check
    /// @return true if the interfaceId is supported
    /// @dev Should indicate whether the contract implements
    /// IAny2EVMMessageReceiver
    /// e.g. return interfaceId == type(IAny2EVMMessageReceiver).interfaceId ||
    /// interfaceId == type(IERC165).interfaceId
    /// This allows CCIP to check if ccipReceive is available before calling it.
    /// If this returns false or reverts, only tokens are transferred to the
    /// receiver.
    /// If this returns true, tokens are transferred and ccipReceive is called
    /// atomically.
    /// Additionally, if the receiver address does not have code associated with
    /// it at the time of execution (EXTCODESIZE returns 0), only tokens will be
    /// transferred.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /// @inheritdoc IAny2EVMMessageReceiver
    function ccipReceive(Client.Any2EVMMessage calldata message) external virtual override onlyRouter {
        _ccipReceive(message);
    }

    /// @notice Override this function in your implementation.
    /// @param message Any2EVMMessage
    function _ccipReceive(Client.Any2EVMMessage memory message) internal virtual;

    /////////////////////////////////////////////////////////////////////
    // Plumbing
    /////////////////////////////////////////////////////////////////////

    /// @notice Return the current router
    /// @return CCIP router address
    function getRouter() public view returns (address) {
        return address(i_ccipRouter);
    }

    error InvalidRouter(address router);

    /// @dev only calls from the set router are accepted.
    modifier onlyRouter() {
        if (msg.sender != address(i_ccipRouter)) revert InvalidRouter(msg.sender);
        _;
    }
}
