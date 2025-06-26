// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseHook} from "./BaseHook.sol";
import {IHook} from "./IHook.sol";

import {ItRWA} from "../token/ItRWA.sol";

/**
 * @title DepositCapHook
 * @notice Hook that limits the total amount of assets that can be deposited into a strategy
 * @dev Tracks cumulative deposits and never decrements on withdrawals (simple cap enforcement)
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

    /// @notice Total cumulative deposits (never decreases)
    uint256 public totalDeposited;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor
     * @param _token Token address
     * @param initialCap Initial deposit cap
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
        if (msg.sender != ItRWA(token).strategy()) revert Unauthorized();

        depositCap = newCap;

        emit DepositCapSet(newCap, depositCap);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the available deposit capacity for the token
     * @return Available capacity (0 if cap exceeded or no cap set)
     */
    function getAvailableCapacity() external view returns (uint256) {
        if (totalDeposited >= depositCap) return 0;
        return depositCap - totalDeposited;
    }

    /**
     * @notice Check if a deposit amount would exceed the cap
     * @param assets Amount of assets to deposit
     * @return Whether the deposit is allowed
     */
    function isDepositAllowed(uint256 assets) external view returns (bool) {
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
    function onBeforeDeposit(address, address, uint256 assets, address)
        public
        override
        returns (IHook.HookOutput memory)
    {
        uint256 newTotal = totalDeposited + assets;

        // Check if deposit would exceed cap
        if (newTotal > depositCap) {
            return IHook.HookOutput({approved: false, reason: "DepositCap: limit exceeded"});
        }

        // Update global tracking
        totalDeposited = newTotal;

        emit DepositTracked(assets, totalDeposited);

        return IHook.HookOutput({approved: true, reason: ""});
    }

    /**
     * @notice Hook executed before a withdraw operation
     * @dev Withdrawals do not reduce the deposit cap (non-decrementing)
     * @return IHook.HookOutput Result of the hook evaluation
     */
    function onBeforeWithdraw(address, address, uint256, address, address)
        public
        pure
        override
        returns (IHook.HookOutput memory)
    {
        // Always approve withdrawals - cap only applies to deposits
        return IHook.HookOutput({approved: true, reason: ""});
    }
}
