// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseHook} from "./BaseHook.sol";
import {IHook} from "./IHook.sol";

/**
 * @title DepositCapHook
 * @notice Hook that limits the total amount of assets that can be deposited into a strategy
 * @dev Tracks deposits in terms of assets (not shares) and decrements on withdrawals
 * to allow profits to increase available capacity
 */
contract DepositCapHook is BaseHook {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error Unauthorized();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event DepositCapSet(uint256 cap, uint256 oldCap);
    event DepositTracked(uint256 assets, uint256 newTotal);
    event WithdrawalTracked(uint256 assets, uint256 newTotal);

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Token address
    address public immutable token;

    /// @notice Deposit cap (in assets)
    uint256 public depositCap;

    /// @notice Total deposited assets
    uint256 public totalDeposited;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor
     */
    constructor(address _token, uint256 initialCap) BaseHook("DepositCapHook-1.0") {
        if (token == address(0)) revert ZeroAddress();

        depositCap = initialCap;
        token = _token;
    }

    /*//////////////////////////////////////////////////////////////
                            CAP MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the deposit cap for a specific token
     * @dev Only the strategy contract associated with the token can set its cap
     * @param newCap Maximum amount of assets that can be deposited (0 means no cap)
     */
    function setDepositCap(uint256 newCap) external {
        if (msg.sender != token.strategy()) revert Unauthorized();

        emit DepositCapSet(newCap, depositCap);

        depositCap = newCap;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the available deposit capacity for a token
     * @param token Address of the token
     * @return Available capacity (0 if cap exceeded or no cap set)
     */
    function getAvailableCapacity() external view returns (uint256) {
        if (depositCap == type(uint256).max) return type(uint256).max; // No cap set

        uint256 deposited = totalDeposited;
        if (deposited >= depositCap) return 0;

        return depositCap - deposited;
    }

    /**
     * @notice Check if a deposit amount would exceed the cap
     * @param token Address of the token
     * @param assets Amount of assets to deposit
     * @return Whether the deposit is allowed
     */
    function isDepositAllowed(uint256 assets) external view returns (bool) {
        if (depositCap == type(uint256).max) return true; // No cap set

        return totalDeposited + assets <= depositCap;
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Hook executed before a deposit operation
     * @param token Address of the token
     * @param user Address initiating the deposit
     * @param assets Amount of assets to deposit
     * @param receiver Address receiving the shares
     * @return IHook.HookOutput Result of the hook evaluation
     */
    function onBeforeDeposit(
        address,
        address,
        uint256 assets,
        address
    ) public override returns (IHook.HookOutput memory) {
        uint256 newTotal = totalDeposited + assets;

        // Check if deposit would exceed cap
        if (newTotal > depositCap) {
            uint256 available = depositCap > currentDeposited ? depositCap - currentDeposited : 0;
            return IHook.HookOutput({
                approved: false,
                reason: "DepositCap: limit exceeded"
            });
        }

        // Update tracked deposits
        totalDeposited = newTotal;
        emit DepositTracked(assets, newTotal);

        return IHook.HookOutput({approved: true, reason: ""});
    }

    /**
     * @notice Hook executed before a withdraw operation
     * @param token Address of the token
     * @param by Address initiating the withdrawal
     * @param assets Amount of assets to withdraw
     * @param to Address receiving the assets
     * @param owner Address owning the shares
     * @return IHook.HookOutput Result of the hook evaluation
     */
    function onBeforeWithdraw(
        address,
        address,
        uint256 assets,
        address,
        address
    ) public override returns (IHook.HookOutput memory) {
        // Decrement the tracked deposits to account for withdrawals
        // This allows profits to increase the available deposit capacity
        uint256 newTotal = assets > totalDeposited ? 0 : totalDeposited - assets;

        totalDeposited = newTotal;

        emit WithdrawalTracked(token, assets, newTotal);

        return IHook.HookOutput({approved: true, reason: ""});
    }
}