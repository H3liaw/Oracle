// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { CcipClient } from "../libs/CcipClient.sol";

/**
 * @title ICCIPEndpoint
 * @notice Interface for CCIP Endpoint
 */
interface ICCIPEndpoint {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when the destination chain is not supported
    /// @param destChainSelector The destination chain selector
    error UnsupportedDestinationChain(uint64 destChainSelector);
    error InsufficientFeeTokenAmount();
    error InvalidMsgValue();

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if the given chain ID is supported for sending/receiving.
    /// @param destChainSelector The chain to check.
    /// @return supported is true if it is supported, false if not.
    function isChainSupported(uint64 destChainSelector) external view returns (bool supported);

    /// @param destinationChainSelector The destination chainSelector
    /// @param message The cross-chain CCIP message including data and/or tokens
    /// @return fee returns execution fee for the message
    /// delivery to destination chain, denominated in the feeToken specified in the message.
    /// @dev Reverts with appropriate reason upon invalid message.
    function getFee(
        uint64 destinationChainSelector,
        CcipClient.EVM2AnyMessage memory message
    )
        external
        view
        returns (uint256 fee);

    /// @notice Request a message to be sent to the destination chain
    /// @param destinationChainSelector The destination chain ID
    /// @param message The cross-chain CCIP message including data and/or tokens
    /// @return messageId The message ID
    /// @dev Note if msg.value is larger than the required fee (from getFee) we accept
    /// the overpayment with no refund.
    /// @dev Reverts with appropriate reason upon invalid message.
    function ccipSend(
        uint64 destinationChainSelector,
        CcipClient.EVM2AnyMessage calldata message
    )
        external
        payable
        returns (bytes32);
}
