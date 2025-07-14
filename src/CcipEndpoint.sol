// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ISharePriceOracle } from "./interfaces/ISharePriceOracle.sol";
import { ICCIPEndpoint } from "./interfaces/ICCIPEndpoint.sol";
import { CcipClient } from "./libs/CcipClient.sol";
import { Ownable } from "@solady/auth/Ownable.sol";
import { MsgCodec } from "./libs/MsgCodec.sol";

import { IAny2EVMMessageReceiver } from "./interfaces/IAny2EVMMessageReceiver.sol";
import { IERC165 } from "./interfaces/IERC165.sol";

/**
 * @title CCIPEndpoint
 * @notice A contract that allows for sending and receiving share prices via CCIP
 * @dev This contract is used to send and receive share prices via CCIP
 */
contract CCIPEndpoint is Ownable, IAny2EVMMessageReceiver, IERC165 {
    ////////////////////////////////////////////////////////////////
    ///                      STATE VARIABLES                       ///
    ////////////////////////////////////////////////////////////////

    /// @notice Contract state
    ISharePriceOracle public oracle;
    ICCIPEndpoint public endpoint;

    // Mapping to keep track of allowlisted destination chains.
    mapping(uint64 => bool) public allowlistedDestinationChains;
    // Mapping to keep track of allowlisted source chains.
    mapping(uint64 => bool) public allowlistedSourceChains;
    // Mapping to keep track of allowlisted senders.
    mapping(address => bool) public allowlistedSenders;

    ////////////////////////////////////////////////////////////////
    ///                          EVENTS                           ///
    ////////////////////////////////////////////////////////////////

    event MessageProcessed(bytes32 indexed messageId, bytes message);
    event SharePricesSent(uint64 indexed dstChainSelector, address[] vaults);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed dstChainSelector,
        address receiver,
        bytes message,
        address feeToken,
        uint256 fee
    );

    ////////////////////////////////////////////////////////////////
    ///                          ERRORS                           ///
    ////////////////////////////////////////////////////////////////

    error ChainNotAllowlisted(uint64 chainSelector);
    error InvalidInput();
    error InsufficientFunds();
    error ZeroAddress();
    error UnauthorizedSource(uint64 sourceChainSelector, address sender);
    error DestinationChainNotAllowlisted(uint64 destinationChainSelector);
    error InvalidReceiverAddress();
    error SourceChainNotAllowlisted(uint64 sourceChainSelector);
    error SenderNotAllowlisted(address sender);
    error InvalidRouter(address router);

    /// @dev Modifier that checks if the chain with the given destinationChainSelector is allowlisted.
    /// @param _destinationChainSelector The selector of the destination chain.
    modifier onlyAllowlistedDestinationChain(uint64 _destinationChainSelector) {
        if (!allowlistedDestinationChains[_destinationChainSelector]) {
            revert DestinationChainNotAllowlisted(_destinationChainSelector);
        }
        _;
    }

    modifier onlyAllowlisted(uint64 _sourceChainSelector, address _sender) {
        if (!allowlistedSourceChains[_sourceChainSelector]) {
            revert SourceChainNotAllowlisted(_sourceChainSelector);
        }
        if (!allowlistedSenders[_sender]) revert SenderNotAllowlisted(_sender);
        _;
    }

    /// @dev only calls from the set router are accepted.
    modifier onlyRouter() {
        if (msg.sender != address(endpoint)) revert InvalidRouter(msg.sender);
        _;
    }

    ////////////////////////////////////////////////////////////////
    ///                      CONSTRUCTOR                          ///
    ////////////////////////////////////////////////////////////////

    constructor(address admin_, address endpoint_, address oracle_) {
        if (admin_ == address(0) || oracle_ == address(0) || endpoint_ == address(0)) {
            revert ZeroAddress();
        }

        oracle = ISharePriceOracle(oracle_);
        endpoint = ICCIPEndpoint(endpoint_);
        _initializeOwner(admin_);
    }

    ////////////////////////////////////////////////////////////////
    ///                    ADMIN FUNCTIONS                        ///
    ////////////////////////////////////////////////////////////////

    /// @notice Updates the oracle address
    /// @param oracle_ The new oracle address
    /// @dev Only callable by the owner
    function setOracle(address oracle_) external onlyOwner {
        if (oracle_ == address(0)) revert InvalidInput();
        emit OracleUpdated(address(oracle), oracle_);
        oracle = ISharePriceOracle(oracle_);
    }

    /// @dev Updates the allowlist status of a destination chain for transactions.
    function allowlistDestinationChain(uint64 _destinationChainSelector, bool allowed) external onlyOwner {
        allowlistedDestinationChains[_destinationChainSelector] = allowed;
    }

    /// @dev Updates the allowlist status of a source chain for transactions.
    function allowlistSourceChain(uint64 _sourceChainSelector, bool allowed) external onlyOwner {
        allowlistedSourceChains[_sourceChainSelector] = allowed;
    }

    /// @dev Updates the allowlist status of a sender for transactions.
    function allowlistSender(address _sender, bool allowed) external onlyOwner {
        allowlistedSenders[_sender] = allowed;
    }

    /// @notice Allows owner to withdraw stuck ETH from the contract
    /// @param amount Amount of ETH to withdraw
    /// @param refundTo Address to receive the withdrawn ETH
    function refundETH(uint256 amount, address refundTo) external onlyOwner {
        if (refundTo == address(0)) revert ZeroAddress();
        if (amount == 0 || amount > address(this).balance) revert InvalidInput();

        (bool success,) = refundTo.call{ value: amount }("");
        if (!success) revert InsufficientFunds();
    }

    ////////////////////////////////////////////////////////////////
    ///                   EXTERNAL FUNCTIONS                      ///
    ////////////////////////////////////////////////////////////////

    /// @notice Sends share prices to a destination chain
    /// @param dstChainSelector The destination chain selector
    /// @param receiver The receiver address
    /// @param vaultAddresses The vault addresses
    /// @param rewardsDelegate The rewards delegate address
    /// @param _gasLimit The gas limit
    /// @param _allowOutOfOrderExecution Whether to allow out of order execution
    function sendSharePrices(
        uint64 dstChainSelector,
        address receiver,
        address[] calldata vaultAddresses,
        address rewardsDelegate,
        uint256 _gasLimit,
        bool _allowOutOfOrderExecution
    )
        external
        payable
        onlyAllowlistedDestinationChain(dstChainSelector)
        returns (bytes32 messageId)
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (!allowlistedDestinationChains[dstChainSelector]) revert ChainNotAllowlisted(dstChainSelector);

        ISharePriceOracle.VaultReport[] memory reports = oracle.getSharePrices(vaultAddresses, rewardsDelegate);

        bytes memory message = abi.encode(reports);

        messageId = _sendMessage(dstChainSelector, receiver, message, _gasLimit, _allowOutOfOrderExecution);
        emit SharePricesSent(dstChainSelector, vaultAddresses);
    }

    /// @notice Receives share prices from a source chain
    /// @param message The message
    /// @dev Only callable by the router
    function ccipReceive(CcipClient.Any2EVMMessage calldata message) external virtual override onlyRouter {
        _ccipReceive(message);
    }

    ////////////////////////////////////////////////////////////////
    ///                 INTERNAL FUNCTIONS                        ///
    ////////////////////////////////////////////////////////////////

    /// @notice Receives share prices from a source chain
    /// @param any2EvmMessage The any2Evm message
    /// @dev Only callable by the router
    function _ccipReceive(CcipClient.Any2EVMMessage memory any2EvmMessage)
        internal
        onlyAllowlisted(any2EvmMessage.sourceChainSelector, abi.decode(any2EvmMessage.sender, (address)))
    {
        (ISharePriceOracle.VaultReport[] memory reports) =
            abi.decode(any2EvmMessage.data, (ISharePriceOracle.VaultReport[]));

        oracle.updateSharePrices(reports[0].chainId, reports);

        emit MessageProcessed(any2EvmMessage.messageId, any2EvmMessage.data);
    }

    /// @notice Sends a message
    /// @param dstChainSelector The destination chain selector
    /// @param receiver The receiver address
    /// @param message The message
    /// @param _gasLimit The gas limit
    /// @param _allowOutOfOrderExecution Whether to allow out of order execution
    function _sendMessage(
        uint64 dstChainSelector,
        address receiver,
        bytes memory message,
        uint256 _gasLimit,
        bool _allowOutOfOrderExecution
    )
        private
        returns (bytes32 messageId)
    {
        CcipClient.EVM2AnyMessage memory evmMessage =
            _buildCCIPMessage(receiver, message, address(0), _gasLimit, _allowOutOfOrderExecution);

        uint256 fee = endpoint.getFee(dstChainSelector, evmMessage);

        if (fee > msg.value) {
            revert InsufficientFunds();
        }

        messageId = endpoint.ccipSend{ value: fee }(dstChainSelector, evmMessage);

        emit MessageSent(messageId, dstChainSelector, receiver, message, address(0), fee);
    }

    function _buildCCIPMessage(
        address _receiver,
        bytes memory message,
        address _feeTokenAddress,
        uint256 _gasLimit,
        bool _allowOutOfOrderExecution
    )
        private
        pure
        returns (CcipClient.EVM2AnyMessage memory)
    {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        return CcipClient.EVM2AnyMessage({
            receiver: abi.encode(_receiver), // ABI-encoded receiver address
            data: message, // ABI-encoded string
            tokenAmounts: new CcipClient.EVMTokenAmount[](0), // Empty array as no tokens are transferred
            extraArgs: CcipClient._argsToBytes(
                CcipClient.EVMExtraArgsV2({ gasLimit: _gasLimit, allowOutOfOrderExecution: _allowOutOfOrderExecution })
            ),
            // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
            feeToken: _feeTokenAddress
        });
    }

    /// @notice IERC165 supports an interfaceId
    /// @param interfaceId The interfaceId to check
    /// @return true if the interfaceId is supported
    /// @dev Should indicate whether the contract implements IAny2EVMMessageReceiver
    /// e.g. return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId
    /// This allows CCIP to check if ccipReceive is available before calling it.
    /// If this returns false or reverts, only tokens are transferred to the receiver.
    /// If this returns true, tokens are transferred and ccipReceive is called atomically.
    /// Additionally, if the receiver address does not have code associated with
    /// it at the time of execution (EXTCODESIZE returns 0), only tokens will be transferred.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    ////////////////////////////////////////////////////////////////
    ///                   FALLBACK FUNCTIONS                      ///
    ////////////////////////////////////////////////////////////////
    /// @notice Receives ETH
    /// @dev Only callable by the router

    receive() external payable { }
}
