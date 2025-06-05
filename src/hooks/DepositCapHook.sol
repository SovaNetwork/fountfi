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

    /// @notice Total deposited assets (principal only, not profits)
    uint256 public totalDeposited;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor
     */
    constructor(address _token, uint256 initialCap) BaseHook("DepositCapHook-1.0") {
        if (_token == address(0)) revert ZeroAddress();

        token = _token;
        depositCap = initialCap;
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
        // Get strategy address from token
        (bool success, bytes memory data) = token.staticcall(abi.encodeWithSignature("strategy()"));
        if (!success || data.length < 32) revert Unauthorized();
        address strategy = abi.decode(data, (address));
        
        if (msg.sender != strategy) revert Unauthorized();

        emit DepositCapSet(newCap, depositCap);

        depositCap = newCap;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the available deposit capacity for the token
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
     * @param assets Amount of assets to deposit
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
     * @param assets Amount of assets to withdraw
     * @return IHook.HookOutput Result of the hook evaluation
     */
    function onBeforeWithdraw(
        address,
        address,
        uint256 assets,
        address,
        address
    ) public override returns (IHook.HookOutput memory) {
        // Calculate how much of the withdrawal is principal vs profit
        // We can determine this by comparing total assets to total deposited principal
        uint256 totalAssets = _getTotalAssets();
        
        if (totalAssets > totalDeposited) {
            // There are profits, so some withdrawal could be profit
            uint256 totalProfits = totalAssets - totalDeposited;
            
            if (assets <= totalProfits) {
                // Withdrawal is entirely profit, no principal reduction
                emit WithdrawalTracked(0, totalDeposited);
                return IHook.HookOutput({approved: true, reason: ""});
            } else {
                // Withdrawal includes some principal
                uint256 principalWithdrawn = assets - totalProfits;
                uint256 newTotal = principalWithdrawn > totalDeposited ? 0 : totalDeposited - principalWithdrawn;
                totalDeposited = newTotal;
                emit WithdrawalTracked(principalWithdrawn, newTotal);
                return IHook.HookOutput({approved: true, reason: ""});
            }
        } else {
            // No profits, all withdrawal is principal
            uint256 newTotal = assets > totalDeposited ? 0 : totalDeposited - assets;
            totalDeposited = newTotal;
            emit WithdrawalTracked(assets, newTotal);
            return IHook.HookOutput({approved: true, reason: ""});
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the total assets managed by the strategy
     * @return Total assets under management
     */
    function _getTotalAssets() internal view returns (uint256) {
        // Call totalAssets() on the token to get current total managed assets
        (bool success, bytes memory data) = token.staticcall(abi.encodeWithSignature("totalAssets()"));
        
        if (!success || data.length < 32) {
            return 0; // Fallback to 0 if call fails
        }
        
        return abi.decode(data, (uint256));
    }
}