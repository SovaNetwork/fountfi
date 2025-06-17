// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IStrategy} from "./IStrategy.sol";

/**
 * @title IDirectDepositStrategy
 * @notice Interface for strategies that support direct deposit to issuer wallets
 */
interface IDirectDepositStrategy is IStrategy {
    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidIssuerWallet();
    error UnauthorizedMint();

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event IssuerWalletSet(address indexed oldWallet, address indexed newWallet);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function issuerWallet() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                            ISSUER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setIssuerWallet(address newWallet) external;
    function mintShares(address recipient, uint256 shares) external;
    function batchMintShares(address[] calldata recipients, uint256[] calldata shares) external;
    function acceptDeposit(bytes32 depositId) external;
    function batchAcceptDeposits(bytes32[] calldata depositIds) external;
    function refundDeposit(bytes32 depositId) external;
    function setDepositExpirationPeriod(uint256 newExpirationPeriod) external;
}
