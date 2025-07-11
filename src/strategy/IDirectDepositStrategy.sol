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

    event SetIssuerWallet(address indexed oldWallet, address indexed newWallet);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function issuerWallet() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                            ISSUER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setIssuerWallet(address newWallet) external;
    function batchMintShares(bytes32[] calldata ids) external;
}
