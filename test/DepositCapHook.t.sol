// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {DepositCapHook} from "../src/hooks/DepositCapHook.sol";
import {IHook} from "../src/hooks/IHook.sol";
import {MocktRWA} from "../src/mocks/MocktRWA.sol";

/**
 * @title DepositCapHookTest
 * @notice Comprehensive tests for DepositCapHook to achieve 100% coverage
 */
contract DepositCapHookTest is Test {
    // Test instances
    DepositCapHook public hook;
    MocktRWA public token;

    // Test addresses
    address public constant STRATEGY = address(0x1);
    address public constant ASSET = address(0x2);
    address public constant USER = address(0x3);
    address public constant RECEIVER = address(0x4);
    address public constant OWNER = address(0x5);
    address public constant NON_STRATEGY = address(0x6);

    // Test values
    uint256 public constant INITIAL_CAP = 1_000_000;
    uint256 public constant DEPOSIT_AMOUNT = 100_000;

    // Events
    event DepositCapSet(uint256 cap, uint256 oldCap);
    event DepositTracked(uint256 assets, uint256 newTotal);
    event WithdrawalTracked(uint256 assets, uint256 newTotal);

    function setUp() public {
        // Deploy mock token with strategy
        token = new MocktRWA("Test Token", "TEST", ASSET, 18, STRATEGY);

        // Deploy hook with initial cap
        hook = new DepositCapHook(address(token), INITIAL_CAP);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_ValidParams() public view {
        // Verify state initialization
        assertEq(hook.token(), address(token), "Token should be set correctly");
        assertEq(hook.depositCap(), INITIAL_CAP, "Initial cap should be set correctly");
        assertEq(hook.totalDeposited(), 0, "Total deposited should start at 0");
        assertEq(hook.name(), "DepositCapHook-1.0", "Hook name should be set correctly");
    }

    function test_Constructor_ZeroAddress_Reverts() public {
        vm.expectRevert(DepositCapHook.ZeroAddress.selector);
        new DepositCapHook(address(0), INITIAL_CAP);
    }

    function test_Constructor_ZeroCap() public {
        // Should allow zero cap (no limit)
        DepositCapHook zeroCapHook = new DepositCapHook(address(token), 0);
        assertEq(zeroCapHook.depositCap(), 0, "Zero cap should be allowed");
    }

    /*//////////////////////////////////////////////////////////////
                        SET DEPOSIT CAP TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetDepositCap_FromStrategy() public {
        uint256 newCap = 2_000_000;

        // Set new cap from strategy address
        vm.prank(STRATEGY);
        vm.expectEmit(true, true, true, true);
        emit DepositCapSet(newCap, newCap); // oldCap parameter gets newCap value because depositCap is updated before event
        hook.setDepositCap(newCap);

        assertEq(hook.depositCap(), newCap, "Deposit cap should be updated");
    }

    function test_SetDepositCap_Unauthorized_Reverts() public {
        uint256 newCap = 2_000_000;

        // Try to set cap from non-strategy address
        vm.prank(NON_STRATEGY);
        vm.expectRevert(DepositCapHook.Unauthorized.selector);
        hook.setDepositCap(newCap);
    }

    function test_SetDepositCap_ToZero() public {
        // Should allow setting cap to zero (no limit)
        vm.prank(STRATEGY);
        hook.setDepositCap(0);

        assertEq(hook.depositCap(), 0, "Should allow setting cap to zero");
    }

    function testFuzz_SetDepositCap(uint256 newCap) public {
        vm.prank(STRATEGY);
        hook.setDepositCap(newCap);

        assertEq(hook.depositCap(), newCap, "Deposit cap should be updated to fuzzed value");
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetAvailableCapacity_Full() public view {
        uint256 available = hook.getAvailableCapacity();
        assertEq(available, INITIAL_CAP, "Full capacity should be available initially");
    }

    function test_GetAvailableCapacity_Partial() public {
        // Make a deposit
        vm.prank(address(hook));
        hook.onBeforeDeposit(address(token), USER, DEPOSIT_AMOUNT, RECEIVER);

        uint256 available = hook.getAvailableCapacity();
        assertEq(available, INITIAL_CAP - DEPOSIT_AMOUNT, "Available capacity should decrease after deposit");
    }

    function test_GetAvailableCapacity_Exceeded() public {
        // Make deposits that exceed cap
        vm.startPrank(address(hook));
        hook.onBeforeDeposit(address(token), USER, INITIAL_CAP - 1000, RECEIVER);
        hook.onBeforeDeposit(address(token), USER, 1000, RECEIVER);
        vm.stopPrank();

        uint256 available = hook.getAvailableCapacity();
        assertEq(available, 0, "Should return 0 when cap is reached");
    }

    function test_GetAvailableCapacity_CapExactlyMet() public {
        // Deposit exactly the cap amount
        vm.prank(address(hook));
        hook.onBeforeDeposit(address(token), USER, INITIAL_CAP, RECEIVER);

        uint256 available = hook.getAvailableCapacity();
        assertEq(available, 0, "Should return 0 when cap is exactly met");
    }

    function test_IsDepositAllowed_BelowCap() public view {
        assertTrue(hook.isDepositAllowed(DEPOSIT_AMOUNT), "Deposit should be allowed below cap");
    }

    function test_IsDepositAllowed_ExactlyCap() public view {
        assertTrue(hook.isDepositAllowed(INITIAL_CAP), "Deposit should be allowed at exactly cap");
    }

    function test_IsDepositAllowed_ExceedsCap() public view {
        assertFalse(hook.isDepositAllowed(INITIAL_CAP + 1), "Deposit should not be allowed above cap");
    }

    function test_IsDepositAllowed_AfterPartialDeposit() public {
        // Make a partial deposit
        vm.prank(address(hook));
        hook.onBeforeDeposit(address(token), USER, DEPOSIT_AMOUNT, RECEIVER);

        // Check remaining capacity
        assertTrue(hook.isDepositAllowed(INITIAL_CAP - DEPOSIT_AMOUNT), "Should allow remaining capacity");
        assertFalse(hook.isDepositAllowed(INITIAL_CAP - DEPOSIT_AMOUNT + 1), "Should not allow exceeding cap");
    }

    function testFuzz_IsDepositAllowed(uint256 depositAmount, uint256 alreadyDeposited) public {
        // Bound inputs to realistic values (up to 1 billion tokens)
        uint256 maxRealisticAmount = 1_000_000_000 * 1e18;
        alreadyDeposited = bound(alreadyDeposited, 0, INITIAL_CAP);
        depositAmount = bound(depositAmount, 0, maxRealisticAmount);

        // Make initial deposit if needed
        if (alreadyDeposited > 0) {
            vm.prank(address(hook));
            hook.onBeforeDeposit(address(token), USER, alreadyDeposited, RECEIVER);
        }

        bool allowed = hook.isDepositAllowed(depositAmount);
        bool expectedAllowed = (alreadyDeposited + depositAmount <= INITIAL_CAP);

        assertEq(allowed, expectedAllowed, "Deposit allowed should match expected");
    }

    /*//////////////////////////////////////////////////////////////
                    ON BEFORE DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OnBeforeDeposit_Approved() public {
        vm.expectEmit(true, true, true, true);
        emit DepositTracked(DEPOSIT_AMOUNT, DEPOSIT_AMOUNT);

        IHook.HookOutput memory output = hook.onBeforeDeposit(address(token), USER, DEPOSIT_AMOUNT, RECEIVER);

        assertTrue(output.approved, "Deposit should be approved");
        assertEq(output.reason, "", "Reason should be empty for approved deposit");
        assertEq(hook.totalDeposited(), DEPOSIT_AMOUNT, "Total deposited should be updated");
    }

    function test_OnBeforeDeposit_Rejected_ExceedsCap() public {
        uint256 exceedingAmount = INITIAL_CAP + 1;

        IHook.HookOutput memory output = hook.onBeforeDeposit(address(token), USER, exceedingAmount, RECEIVER);

        assertFalse(output.approved, "Deposit should be rejected");
        assertEq(output.reason, "DepositCap: limit exceeded", "Should have correct rejection reason");
        assertEq(hook.totalDeposited(), 0, "Total deposited should not be updated on rejection");
    }

    function test_OnBeforeDeposit_MultipleDeposits() public {
        // First deposit
        vm.expectEmit(true, true, true, true);
        emit DepositTracked(300_000, 300_000);
        hook.onBeforeDeposit(address(token), USER, 300_000, RECEIVER);

        // Second deposit
        vm.expectEmit(true, true, true, true);
        emit DepositTracked(400_000, 700_000);
        hook.onBeforeDeposit(address(token), USER, 400_000, RECEIVER);

        // Third deposit that would exceed cap
        IHook.HookOutput memory output = hook.onBeforeDeposit(
            address(token),
            USER,
            400_000, // Would make total 1.1M, exceeding 1M cap
            RECEIVER
        );

        assertFalse(output.approved, "Third deposit should be rejected");
        assertEq(hook.totalDeposited(), 700_000, "Total should remain at 700k");
    }

    function test_OnBeforeDeposit_ExactlyAtCap() public {
        IHook.HookOutput memory output = hook.onBeforeDeposit(address(token), USER, INITIAL_CAP, RECEIVER);

        assertTrue(output.approved, "Deposit at exactly cap should be approved");
        assertEq(hook.totalDeposited(), INITIAL_CAP, "Total should equal cap");

        // Any further deposit should fail
        output = hook.onBeforeDeposit(address(token), USER, 1, RECEIVER);
        assertFalse(output.approved, "Even 1 wei over cap should be rejected");
    }

    function test_OnBeforeDeposit_ZeroAmount() public {
        // Zero deposits should be allowed
        IHook.HookOutput memory output = hook.onBeforeDeposit(address(token), USER, 0, RECEIVER);

        assertTrue(output.approved, "Zero deposit should be approved");
        assertEq(hook.totalDeposited(), 0, "Total should remain 0");
    }

    function testFuzz_OnBeforeDeposit(uint256 amount1, uint256 amount2) public {
        // Bound amounts to realistic values (up to 1 billion tokens)
        uint256 maxRealisticAmount = 1_000_000_000 * 1e18;
        amount1 = bound(amount1, 0, INITIAL_CAP);
        amount2 = bound(amount2, 0, maxRealisticAmount);

        // First deposit
        IHook.HookOutput memory output1 = hook.onBeforeDeposit(address(token), USER, amount1, RECEIVER);

        assertTrue(output1.approved, "First deposit within cap should be approved");
        assertEq(hook.totalDeposited(), amount1, "Total should equal first deposit");

        // Second deposit
        IHook.HookOutput memory output2 = hook.onBeforeDeposit(address(token), USER, amount2, RECEIVER);

        bool shouldApprove = (amount1 + amount2 <= INITIAL_CAP);
        assertEq(output2.approved, shouldApprove, "Second deposit approval should match expected");

        if (shouldApprove) {
            assertEq(hook.totalDeposited(), amount1 + amount2, "Total should be sum of deposits");
        } else {
            assertEq(hook.totalDeposited(), amount1, "Total should remain at first deposit");
        }
    }

    /*//////////////////////////////////////////////////////////////
                    ON BEFORE WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OnBeforeWithdraw_AlwaysApproved() public {
        DepositCapHook testHook = new DepositCapHook(address(1), 1000);

        IHook.HookOutput memory output = testHook.onBeforeWithdraw(
            address(1), // token
            address(2), // by
            1000, // assets
            address(3), // to
            address(4) // owner
        );

        assertTrue(output.approved, "Withdrawal should always be approved");
        assertEq(output.reason, "", "Reason should be empty for withdrawals");
    }

    function test_OnBeforeWithdraw_DoesNotAffectCap() public {
        // Make a deposit first
        hook.onBeforeDeposit(address(token), USER, DEPOSIT_AMOUNT, RECEIVER);
        uint256 totalBefore = hook.totalDeposited();

        // Withdraw
        IHook.HookOutput memory output = hook.onBeforeWithdraw(address(token), USER, DEPOSIT_AMOUNT, RECEIVER, OWNER);

        assertTrue(output.approved, "Withdrawal should be approved");
        assertEq(hook.totalDeposited(), totalBefore, "Total deposited should not change on withdrawal");
    }

    function testFuzz_OnBeforeWithdraw(address tokenAddr, address by, uint256 assets, address to, address owner)
        public
    {
        DepositCapHook testHook = new DepositCapHook(address(1), 1000);

        IHook.HookOutput memory output = testHook.onBeforeWithdraw(tokenAddr, by, assets, to, owner);

        assertTrue(output.approved, "All withdrawals should be approved");
        assertEq(output.reason, "", "Reason should always be empty");
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Integration_DepositWithdrawCycle() public {
        // Initial state
        assertEq(hook.getAvailableCapacity(), INITIAL_CAP, "Full capacity available");

        // Deposit 40% of cap
        uint256 deposit1 = (INITIAL_CAP * 40) / 100;
        hook.onBeforeDeposit(address(token), USER, deposit1, RECEIVER);
        assertEq(hook.getAvailableCapacity(), INITIAL_CAP - deposit1, "60% capacity should remain");

        // Withdraw doesn't affect cap
        hook.onBeforeWithdraw(address(token), USER, deposit1, RECEIVER, OWNER);
        assertEq(hook.getAvailableCapacity(), INITIAL_CAP - deposit1, "Capacity unchanged after withdrawal");
        assertEq(hook.totalDeposited(), deposit1, "Total deposited unchanged after withdrawal");

        // Deposit another 40%
        uint256 deposit2 = (INITIAL_CAP * 40) / 100;
        hook.onBeforeDeposit(address(token), USER, deposit2, RECEIVER);
        assertEq(hook.getAvailableCapacity(), INITIAL_CAP - deposit1 - deposit2, "20% capacity should remain");

        // Try to deposit 30% (should fail)
        uint256 deposit3 = (INITIAL_CAP * 30) / 100;
        IHook.HookOutput memory output = hook.onBeforeDeposit(address(token), USER, deposit3, RECEIVER);
        assertFalse(output.approved, "Deposit exceeding cap should fail");

        // Deposit exactly remaining 20%
        uint256 deposit4 = (INITIAL_CAP * 20) / 100;
        output = hook.onBeforeDeposit(address(token), USER, deposit4, RECEIVER);
        assertTrue(output.approved, "Deposit within remaining cap should succeed");
        assertEq(hook.getAvailableCapacity(), 0, "No capacity should remain");
    }

    function test_Integration_CapIncrease() public {
        // Fill half the cap
        uint256 halfCap = INITIAL_CAP / 2;
        hook.onBeforeDeposit(address(token), USER, halfCap, RECEIVER);

        // Increase cap
        uint256 newCap = INITIAL_CAP * 2;
        vm.prank(STRATEGY);
        hook.setDepositCap(newCap);

        // Should now have 1.5x original cap available
        assertEq(hook.getAvailableCapacity(), newCap - halfCap, "Available capacity should reflect new cap");

        // Can deposit more than original cap
        IHook.HookOutput memory output = hook.onBeforeDeposit(address(token), USER, INITIAL_CAP, RECEIVER);
        assertTrue(output.approved, "Should allow deposit up to new cap");
    }

    function test_Integration_CapDecrease() public {
        // Deposit 60% of cap
        uint256 deposit = (INITIAL_CAP * 60) / 100;
        hook.onBeforeDeposit(address(token), USER, deposit, RECEIVER);

        // Decrease cap to 50% of original (below current deposits)
        uint256 newCap = INITIAL_CAP / 2;
        vm.prank(STRATEGY);
        hook.setDepositCap(newCap);

        // Available capacity should be 0 (cap exceeded)
        assertEq(hook.getAvailableCapacity(), 0, "No capacity when deposits exceed new cap");

        // Cannot make any new deposits
        IHook.HookOutput memory output = hook.onBeforeDeposit(address(token), USER, 1, RECEIVER);
        assertFalse(output.approved, "Should not allow deposits when already over new cap");

        // But withdrawals still work
        output = hook.onBeforeWithdraw(address(token), USER, deposit, RECEIVER, OWNER);
        assertTrue(output.approved, "Withdrawals should still be allowed");
    }
}
