// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ECDSA} from "solady/utils/ECDSA.sol";
import {ManagedWithdrawRWA} from "../token/ManagedWithdrawRWA.sol";
import {ReportedStrategy} from "./ReportedStrategy.sol";

/**
 * @title ManagedWithdrawReportedStrategy
 * @notice Extension of ReportedStrategy that deploys and configures ManagedWithdrawRWA tokens
 */
contract ManagedWithdrawReportedStrategy is ReportedStrategy {
    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error WithdrawalRequestExpired();
    error WithdrawNonceReuse();
    error WithdrawInvalidSignature();
    error InvalidArrayLengths();

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event WithdrawalNonceUsed(address indexed owner, uint96 nonce);

    /*//////////////////////////////////////////////////////////////
                            EIP-712 DATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Signature argument struct
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    // EIP-712 Type Hash Constants
    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 private constant WITHDRAWAL_REQUEST_TYPEHASH = keccak256(
        "WithdrawalRequest(address owner,address to,uint256 shares,uint256 minAssets,uint96 nonce,uint96 expirationTime)"
    );

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Struct to track withdrawal requests
    struct WithdrawalRequest {
        uint256 shares;
        uint256 minAssets;
        address owner;
        uint96 nonce;
        address to;
        uint96 expirationTime;
    }

    // Tracking of used nonces
    mapping(address => mapping(uint96 => bool)) public usedNonces;

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize the strategy with ManagedWithdrawRWA token
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param roleManager_ Address of the role manager
     * @param manager_ Address of the manager
     * @param asset_ Address of the underlying asset
     * @param assetDecimals_ Decimals of the asset
     * @param initData Additional initialization data (unused)
     */
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address roleManager_,
        address manager_,
        address asset_,
        uint8 assetDecimals_,
        bytes memory initData
    ) public virtual override {
        super.initialize(name_, symbol_, roleManager_, manager_, asset_, assetDecimals_, initData);
    }

    /**
     * @notice Deploy a new ManagedWithdrawRWA token
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param asset_ Address of the underlying asset
     * @param assetDecimals_ Decimals of the asset
     */
    function _deployToken(string calldata name_, string calldata symbol_, address asset_, uint8 assetDecimals_)
        internal
        virtual
        override
        returns (address)
    {
        ManagedWithdrawRWA newToken = new ManagedWithdrawRWA(name_, symbol_, asset_, assetDecimals_, address(this));

        return address(newToken);
    }

    /*//////////////////////////////////////////////////////////////
                            REDEMPTION LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Process a user-requested withdrawal
     * @param request The withdrawal request
     * @param userSig The signature of the request
     * @return assets The amount of assets received
     */
    function redeem(WithdrawalRequest calldata request, Signature calldata userSig)
        external
        onlyManager
        returns (uint256 assets)
    {
        _validateRedeem(request);

        // Verify signature
        _verifySignature(request, userSig);

        assets = ManagedWithdrawRWA(sToken).redeem(request.shares, request.to, request.owner, request.minAssets);
    }

    /**
     * @notice Process a batch of user-requested withdrawals
     * @param requests The withdrawal requests
     * @param signatures The signatures of the requests
     * @return assets The amount of assets received
     */
    function batchRedeem(WithdrawalRequest[] calldata requests, Signature[] calldata signatures)
        external
        onlyManager
        returns (uint256[] memory assets)
    {
        if (requests.length != signatures.length) revert InvalidArrayLengths();

        uint256[] memory shares = new uint256[](requests.length);
        address[] memory recipients = new address[](requests.length);
        address[] memory owners = new address[](requests.length);
        uint256[] memory minAssets = new uint256[](requests.length);

        for (uint256 i = 0; i < requests.length;) {
            _validateRedeem(requests[i]);
            _verifySignature(requests[i], signatures[i]);

            shares[i] = requests[i].shares;
            recipients[i] = requests[i].to;
            owners[i] = requests[i].owner;
            minAssets[i] = requests[i].minAssets;

            unchecked {
                ++i;
            }
        }

        assets = ManagedWithdrawRWA(sToken).batchRedeemShares(shares, recipients, owners, minAssets);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validate a withdrawal request's arguments and consume the nonce
     * @param request The withdrawal request
     */
    function _validateRedeem(WithdrawalRequest calldata request) internal {
        if (request.expirationTime < block.timestamp) revert WithdrawalRequestExpired();

        // Cache the nonce status to avoid duplicate storage read
        mapping(uint96 => bool) storage userNonces = usedNonces[request.owner];
        if (userNonces[request.nonce]) revert WithdrawNonceReuse();

        // Consume the nonce
        userNonces[request.nonce] = true;
        emit WithdrawalNonceUsed(request.owner, request.nonce);
    }

    /**
     * @notice Verify a signature using EIP-712
     * @param request The withdrawal request
     * @param signature The signature
     */
    function _verifySignature(WithdrawalRequest calldata request, Signature calldata signature) internal view {
        // Verify signature
        bytes32 structHash = keccak256(
            abi.encode(
                WITHDRAWAL_REQUEST_TYPEHASH,
                request.owner,
                request.to,
                request.shares,
                request.minAssets,
                request.nonce,
                request.expirationTime
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));

        // Recover signer address from signature
        address signer = ECDSA.recover(digest, signature.v, signature.r, signature.s);

        // Verify the signer is the owner of the shares
        if (signer != request.owner) revert WithdrawInvalidSignature();
    }

    /**
     * @notice Calculate the EIP-712 domain separator
     * @return The domain separator
     */
    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("ManagedWithdrawReportedStrategy")),
                keccak256(bytes("V1")),
                block.chainid,
                address(this)
            )
        );
    }
}
