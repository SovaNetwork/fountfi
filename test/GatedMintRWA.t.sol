// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {GatedMintRWA} from "../src/token/GatedMintRWA.sol";
import {GatedMintEscrow} from "../src/strategy/GatedMintEscrow.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockStrategy} from "../src/mocks/MockStrategy.sol";
import {MockHook} from "../src/mocks/hooks/MockHook.sol";
import {MockRegistry} from "../src/mocks/MockRegistry.sol";
import {MockConduit} from "../src/mocks/MockConduit.sol";
import {tRWA} from "../src/token/tRWA.sol";

/**
 * @title GatedMintRWATest
 * @notice Comprehensive tests for GatedMintRWA contract to achieve 100% coverage
 */
contract GatedMintRWATest is BaseFountfiTest {
    GatedMintRWA internal gatedToken;
    GatedMintEscrow internal escrow;
    MockStrategy internal strategy;
    MockRegistry internal mockRegistry;
    MockConduit internal mockConduit;

    // Test constants
    uint256 internal constant DEPOSIT_AMOUNT = 1000 * 10 ** 6; // 1000 USDC
    uint256 internal constant INITIAL_BALANCE = 10000 * 10 ** 6; // 10,000 USDC

    // Hook operation types
    bytes32 public constant OP_DEPOSIT = keccak256("DEPOSIT_OPERATION");

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);

        // Create mock registry and conduit
        mockRegistry = new MockRegistry();
        mockConduit = new MockConduit();
        mockRegistry.setConduit(address(mockConduit));
        mockRegistry.setAsset(address(usdc), 6);

        // Deploy strategy
        strategy = new MockStrategy();
        strategy.initialize("Gated RWA", "GRWA", owner, manager, address(usdc), 6, "");

        // Mock the strategy's registry call
        vm.mockCall(
            address(strategy),
            abi.encodeWithSelector(bytes4(keccak256("registry()"))),
            abi.encode(address(mockRegistry))
        );

        // Deploy GatedMintRWA token
        gatedToken = new GatedMintRWA("Gated RWA", "GRWA", address(usdc), 6, address(strategy));

        // Get the escrow from the token
        escrow = GatedMintEscrow(gatedToken.escrow());

        // Setup balances
        usdc.mint(alice, INITIAL_BALANCE);
        usdc.mint(bob, INITIAL_BALANCE);
        usdc.mint(charlie, INITIAL_BALANCE);

        vm.stopPrank();
    }

    // ============ Constructor Tests ============

    function test_Constructor() public {
        GatedMintRWA newToken = new GatedMintRWA("Test Token", "TEST", address(usdc), 6, address(strategy));

        assertEq(newToken.name(), "Test Token");
        assertEq(newToken.symbol(), "TEST");
        assertEq(newToken.asset(), address(usdc));
        assertEq(newToken.strategy(), address(strategy));

        // Verify escrow was deployed
        address escrowAddr = newToken.escrow();
        assertTrue(escrowAddr != address(0));

        // Verify default expiration period
        assertEq(newToken.depositExpirationPeriod(), 7 days);
    }

    // ============ Configuration Tests ============

    function test_SetDepositExpirationPeriod() public {
        uint256 newPeriod = 14 days;

        vm.prank(address(strategy));
        vm.expectEmit(true, true, true, true);
        emit GatedMintRWA.DepositExpirationPeriodUpdated(7 days, newPeriod);

        gatedToken.setDepositExpirationPeriod(newPeriod);

        assertEq(gatedToken.depositExpirationPeriod(), newPeriod);
    }

    function test_SetDepositExpirationPeriod_ZeroPeriod() public {
        vm.prank(address(strategy));
        vm.expectRevert(GatedMintRWA.InvalidExpirationPeriod.selector);
        gatedToken.setDepositExpirationPeriod(0);
    }

    function test_SetDepositExpirationPeriod_TooLong() public {
        uint256 tooLongPeriod = 31 days; // Max is 30 days

        vm.prank(address(strategy));
        vm.expectRevert(GatedMintRWA.InvalidExpirationPeriod.selector);
        gatedToken.setDepositExpirationPeriod(tooLongPeriod);
    }

    function test_SetDepositExpirationPeriod_MaxAllowed() public {
        uint256 maxPeriod = 30 days;

        vm.prank(address(strategy));
        gatedToken.setDepositExpirationPeriod(maxPeriod);

        assertEq(gatedToken.depositExpirationPeriod(), maxPeriod);
    }

    function test_SetDepositExpirationPeriod_UnauthorizedCaller() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(tRWA.NotStrategyAdmin.selector));
        gatedToken.setDepositExpirationPeriod(14 days);
    }

    // ============ Deposit Flow Tests ============

    function test_Deposit_CreatesDepositInEscrow() public {
        vm.prank(alice);
        usdc.approve(address(mockConduit), DEPOSIT_AMOUNT);

        vm.prank(alice);
        // Don't check the exact event as the deposit ID is dynamically generated
        gatedToken.deposit(DEPOSIT_AMOUNT, alice);

        // Verify deposit was tracked
        bytes32[] memory pendingDeposits = gatedToken.getUserPendingDeposits(alice);
        assertEq(pendingDeposits.length, 1);

        // Verify deposit details
        GatedMintEscrow.PendingDeposit memory deposit = escrow.getPendingDeposit(pendingDeposits[0]);
        address depositor = deposit.depositor;
        address recipient = deposit.recipient;
        uint256 amount = deposit.assetAmount;
        uint256 expTime = deposit.expirationTime;
        uint8 state = uint8(deposit.state);

        assertEq(depositor, alice);
        assertEq(recipient, alice);
        assertEq(amount, DEPOSIT_AMOUNT);
        assertGt(expTime, block.timestamp);
        assertEq(state, 0); // PENDING
    }

    function test_Deposit_WithDifferentRecipient() public {
        vm.prank(alice);
        usdc.approve(address(mockConduit), DEPOSIT_AMOUNT);

        vm.prank(alice);
        gatedToken.deposit(DEPOSIT_AMOUNT, bob);

        bytes32[] memory pendingDeposits = gatedToken.getUserPendingDeposits(alice);
        assertEq(pendingDeposits.length, 1);

        GatedMintEscrow.PendingDeposit memory deposit = escrow.getPendingDeposit(pendingDeposits[0]);
        address depositor = deposit.depositor;
        address recipient = deposit.recipient;

        assertEq(depositor, alice);
        assertEq(recipient, bob);
    }

    function test_Deposit_WithPassingHook() public {
        // Create a hook that passes deposit operations
        MockHook passingHook = new MockHook(true, "");

        // Add hook to deposit operations
        vm.prank(address(strategy));
        gatedToken.addOperationHook(OP_DEPOSIT, address(passingHook));

        vm.prank(alice);
        usdc.approve(address(mockConduit), DEPOSIT_AMOUNT);

        vm.prank(alice);
        gatedToken.deposit(DEPOSIT_AMOUNT, alice);

        // Verify deposit was tracked
        bytes32[] memory pendingDeposits = gatedToken.getUserPendingDeposits(alice);
        assertEq(pendingDeposits.length, 1);

        // Verify deposit details
        GatedMintEscrow.PendingDeposit memory deposit = escrow.getPendingDeposit(pendingDeposits[0]);
        address depositor = deposit.depositor;
        address recipient = deposit.recipient;
        uint256 amount = deposit.assetAmount;
        uint256 expTime = deposit.expirationTime;
        uint8 state = uint8(deposit.state);

        assertEq(depositor, alice);
        assertEq(recipient, alice);
        assertEq(amount, DEPOSIT_AMOUNT);
        assertGt(expTime, block.timestamp);
        assertEq(state, 0); // PENDING
    }

    function test_Deposit_WithFailingHook() public {
        // Create a hook that rejects deposit operations
        MockHook rejectingHook = new MockHook(false, "Deposit blocked by hook");

        // Add hook to deposit operations
        vm.prank(address(strategy));
        gatedToken.addOperationHook(OP_DEPOSIT, address(rejectingHook));

        vm.prank(alice);
        usdc.approve(address(mockConduit), DEPOSIT_AMOUNT);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(tRWA.HookCheckFailed.selector, "Deposit blocked by hook"));
        gatedToken.deposit(DEPOSIT_AMOUNT, alice);
    }

    function test_Deposit_MultipleDeposits() public {
        vm.startPrank(alice);
        usdc.approve(address(mockConduit), DEPOSIT_AMOUNT * 3);

        gatedToken.deposit(DEPOSIT_AMOUNT, alice);
        gatedToken.deposit(DEPOSIT_AMOUNT, bob);
        gatedToken.deposit(DEPOSIT_AMOUNT, charlie);

        vm.stopPrank();

        bytes32[] memory pendingDeposits = gatedToken.getUserPendingDeposits(alice);
        assertEq(pendingDeposits.length, 3);
    }

    // ============ Share Minting Tests ============

    function test_MintShares_FromEscrow() public {
        // First create a deposit
        _createPendingDeposit(alice, bob, DEPOSIT_AMOUNT);

        uint256 bobSharesBefore = gatedToken.balanceOf(bob);
        uint256 expectedShares = gatedToken.previewDeposit(DEPOSIT_AMOUNT);

        vm.prank(address(escrow));
        gatedToken.mintShares(bob, DEPOSIT_AMOUNT);

        assertEq(gatedToken.balanceOf(bob), bobSharesBefore + expectedShares);
    }

    function test_MintShares_UnauthorizedCaller() public {
        vm.prank(alice);
        vm.expectRevert(GatedMintRWA.NotEscrow.selector);
        gatedToken.mintShares(bob, DEPOSIT_AMOUNT);
    }

    function test_BatchMintShares() public {
        // Create multiple deposits
        bytes32 deposit1 = _createPendingDeposit(alice, alice, DEPOSIT_AMOUNT);
        bytes32 deposit2 = _createPendingDeposit(bob, bob, DEPOSIT_AMOUNT * 2);
        bytes32 deposit3 = _createPendingDeposit(charlie, charlie, DEPOSIT_AMOUNT / 2);

        bytes32[] memory depositIds = new bytes32[](3);
        depositIds[0] = deposit1;
        depositIds[1] = deposit2;
        depositIds[2] = deposit3;

        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = DEPOSIT_AMOUNT;
        assetAmounts[1] = DEPOSIT_AMOUNT * 2;
        assetAmounts[2] = DEPOSIT_AMOUNT / 2;

        uint256 totalAssets = DEPOSIT_AMOUNT + (DEPOSIT_AMOUNT * 2) + (DEPOSIT_AMOUNT / 2);

        // Get the actual escrow address from the gatedToken
        address actualEscrow = gatedToken.escrow();

        vm.prank(actualEscrow);

        // Call batchMintShares - this should emit the event
        gatedToken.batchMintShares(depositIds, recipients, assetAmounts, totalAssets);

        // Verify shares were minted correctly
        // For the first batch mint, shares should equal assets * decimal conversion (6 to 18)
        assertEq(gatedToken.balanceOf(alice), DEPOSIT_AMOUNT * 10 ** 12);
        assertEq(gatedToken.balanceOf(bob), (DEPOSIT_AMOUNT * 2) * 10 ** 12);
        assertEq(gatedToken.balanceOf(charlie), (DEPOSIT_AMOUNT / 2) * 10 ** 12);
    }

    function test_BatchMintShares_InvalidArrayLengths() public {
        bytes32[] memory depositIds = new bytes32[](2);
        address[] memory recipients = new address[](3); // Different length
        uint256[] memory assetAmounts = new uint256[](2);
        uint256 totalAssets = 1000;

        vm.prank(address(escrow));
        vm.expectRevert(GatedMintRWA.InvalidArrayLengths.selector);
        gatedToken.batchMintShares(depositIds, recipients, assetAmounts, totalAssets);
    }

    function test_BatchMintShares_InvalidArrayLengthsAssets() public {
        bytes32[] memory depositIds = new bytes32[](2);
        address[] memory recipients = new address[](2);
        uint256[] memory assetAmounts = new uint256[](1); // Different length
        uint256 totalAssets = 1000;

        vm.prank(address(escrow));
        vm.expectRevert(GatedMintRWA.InvalidArrayLengths.selector);
        gatedToken.batchMintShares(depositIds, recipients, assetAmounts, totalAssets);
    }

    function test_BatchMintShares_UnauthorizedCaller() public {
        bytes32[] memory depositIds = new bytes32[](1);
        address[] memory recipients = new address[](1);
        uint256[] memory assetAmounts = new uint256[](1);
        uint256 totalAssets = 1000;

        vm.prank(alice);
        vm.expectRevert(GatedMintRWA.NotEscrow.selector);
        gatedToken.batchMintShares(depositIds, recipients, assetAmounts, totalAssets);
    }

    // ============ View Function Tests ============

    function test_GetUserPendingDeposits_EmptyByDefault() public view {
        bytes32[] memory pendingDeposits = gatedToken.getUserPendingDeposits(alice);
        assertEq(pendingDeposits.length, 0);
    }

    function test_GetUserPendingDeposits_OnlyPending() public {
        // Create two deposits with different amounts to ensure different IDs
        bytes32 deposit1 = _createPendingDeposit(alice, alice, DEPOSIT_AMOUNT);
        bytes32 deposit2 = _createPendingDeposit(alice, alice, DEPOSIT_AMOUNT * 2);

        // Accept one deposit
        vm.prank(address(strategy));
        escrow.acceptDeposit(deposit2);

        bytes32[] memory pendingDeposits = gatedToken.getUserPendingDeposits(alice);
        assertEq(pendingDeposits.length, 1);
        assertEq(pendingDeposits[0], deposit1);
    }

    // ============ Integration Tests ============

    function test_CompleteDepositToMintFlow() public {
        // 1. Alice approves the conduit (not the token)
        vm.prank(alice);
        usdc.approve(address(mockConduit), DEPOSIT_AMOUNT);

        // 2. Alice deposits
        vm.prank(alice);
        gatedToken.deposit(DEPOSIT_AMOUNT, alice);

        // 2. Get deposit ID
        bytes32[] memory pendingDeposits = gatedToken.getUserPendingDeposits(alice);
        assertEq(pendingDeposits.length, 1);
        bytes32 depositId = pendingDeposits[0];

        // 3. Strategy accepts deposit

        vm.prank(address(strategy));
        escrow.acceptDeposit(depositId);

        // 4. Verify shares were minted
        // For the first deposit, shares are minted based on the exchange rate
        uint256 aliceBalance = gatedToken.balanceOf(alice);
        assertGt(aliceBalance, 0);
        // Verify the balance is reasonable (around 10^12 for 1000 USDC)
        assertGt(aliceBalance, 900 * 10 ** 9); // At least 900 * 10^9
        assertLt(aliceBalance, 1100 * 10 ** 12); // Less than 1100 * 10^12

        // 5. Verify deposit is no longer pending
        pendingDeposits = gatedToken.getUserPendingDeposits(alice);
        assertEq(pendingDeposits.length, 0);
    }

    function test_BatchDepositAcceptanceFlow() public {
        // Create multiple deposits
        bytes32 deposit1 = _createPendingDeposit(alice, alice, DEPOSIT_AMOUNT);
        bytes32 deposit2 = _createPendingDeposit(bob, bob, DEPOSIT_AMOUNT * 2);
        bytes32 deposit3 = _createPendingDeposit(charlie, charlie, DEPOSIT_AMOUNT / 2);

        // Accept all deposits in batch
        bytes32[] memory depositIds = new bytes32[](3);
        depositIds[0] = deposit1;
        depositIds[1] = deposit2;
        depositIds[2] = deposit3;

        vm.prank(address(strategy));
        escrow.batchAcceptDeposits(depositIds);

        // Verify shares were minted for all users
        // In batch minting, shares are proportional to the asset amounts in the batch
        assertGt(gatedToken.balanceOf(alice), 0);
        assertGt(gatedToken.balanceOf(bob), 0);
        assertGt(gatedToken.balanceOf(charlie), 0);

        // Bob should have 2x alice's shares, charlie should have 0.5x alice's shares
        assertApproxEqRel(gatedToken.balanceOf(bob), gatedToken.balanceOf(alice) * 2, 0.01e18);
        assertApproxEqRel(gatedToken.balanceOf(charlie), gatedToken.balanceOf(alice) / 2, 0.01e18);

        // Verify deposits are no longer pending
        assertEq(gatedToken.getUserPendingDeposits(alice).length, 0);
        assertEq(gatedToken.getUserPendingDeposits(bob).length, 0);
        assertEq(gatedToken.getUserPendingDeposits(charlie).length, 0);
    }

    // ============ Additional Coverage Tests ============

    function test_BatchMintShares_EmptyArrays() public {
        bytes32[] memory depositIds = new bytes32[](0);
        address[] memory recipients = new address[](0);
        uint256[] memory assetAmounts = new uint256[](0);
        uint256 totalAssets = 0;

        vm.prank(address(escrow));
        gatedToken.batchMintShares(depositIds, recipients, assetAmounts, totalAssets);

        // Should not revert on empty arrays
    }

    function test_BatchMintShares_EmitsEvent() public {
        bytes32 deposit1 = _createPendingDeposit(alice, alice, DEPOSIT_AMOUNT);

        bytes32[] memory depositIds = new bytes32[](1);
        depositIds[0] = deposit1;

        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = DEPOSIT_AMOUNT;

        uint256 totalAssets = DEPOSIT_AMOUNT;
        uint256 expectedShares = gatedToken.previewDeposit(totalAssets);

        vm.prank(address(escrow));
        vm.expectEmit(true, true, true, true);
        emit GatedMintRWA.BatchSharesMinted(depositIds, totalAssets, expectedShares);

        gatedToken.batchMintShares(depositIds, recipients, assetAmounts, totalAssets);
    }

    function test_GetUserPendingDeposits_MixedStates() public {
        // Create deposits with different amounts to ensure different IDs
        bytes32 deposit1 = _createPendingDeposit(alice, alice, DEPOSIT_AMOUNT);
        bytes32 deposit2 = _createPendingDeposit(alice, alice, DEPOSIT_AMOUNT * 2);
        bytes32 deposit3 = _createPendingDeposit(alice, alice, DEPOSIT_AMOUNT * 3);

        // Accept one deposit
        vm.prank(address(strategy));
        escrow.acceptDeposit(deposit2);

        // Refund another deposit
        vm.prank(address(strategy));
        escrow.refundDeposit(deposit3);

        // Only deposit1 should be pending
        bytes32[] memory pendingDeposits = gatedToken.getUserPendingDeposits(alice);
        assertEq(pendingDeposits.length, 1);
        assertEq(pendingDeposits[0], deposit1);
    }

    function test_DepositIds_TrackingArray() public {
        // Create first deposit
        _createPendingDeposit(alice, alice, DEPOSIT_AMOUNT);

        // Verify depositIds array is populated
        bytes32 firstDepositId = gatedToken.depositIds(0);
        assertTrue(firstDepositId != bytes32(0));

        // Create second deposit
        _createPendingDeposit(bob, bob, DEPOSIT_AMOUNT);

        // Verify second deposit is tracked
        bytes32 secondDepositId = gatedToken.depositIds(1);
        assertTrue(secondDepositId != bytes32(0));
        assertTrue(firstDepositId != secondDepositId);
    }

    function test_UserDepositIds_TrackingArray() public {
        // Create multiple deposits for alice
        _createPendingDeposit(alice, alice, DEPOSIT_AMOUNT);
        _createPendingDeposit(alice, bob, DEPOSIT_AMOUNT * 2);

        // Create one deposit for bob
        _createPendingDeposit(bob, bob, DEPOSIT_AMOUNT);

        // Check alice has 2 deposits tracked
        bytes32 aliceDeposit1 = gatedToken.userDepositIds(alice, 0);
        bytes32 aliceDeposit2 = gatedToken.userDepositIds(alice, 1);
        assertTrue(aliceDeposit1 != bytes32(0));
        assertTrue(aliceDeposit2 != bytes32(0));
        assertTrue(aliceDeposit1 != aliceDeposit2);

        // Check bob has 1 deposit tracked
        bytes32 bobDeposit1 = gatedToken.userDepositIds(bob, 0);
        assertTrue(bobDeposit1 != bytes32(0));

        // Verify alice and bob deposits are different
        assertTrue(aliceDeposit1 != bobDeposit1);
        assertTrue(aliceDeposit2 != bobDeposit1);
    }

    function test_BatchMintShares_ProportionalDistribution() public {
        // Test with different asset amounts to ensure proper proportional distribution
        uint256 amount1 = 1000 * 10 ** 6; // 1000 USDC
        uint256 amount2 = 3000 * 10 ** 6; // 3000 USDC
        uint256 amount3 = 1000 * 10 ** 6; // 1000 USDC
        uint256 totalAssets = amount1 + amount2 + amount3; // 5000 total

        bytes32[] memory depositIds = new bytes32[](3);
        depositIds[0] = keccak256("deposit1");
        depositIds[1] = keccak256("deposit2");
        depositIds[2] = keccak256("deposit3");

        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = amount1;
        assetAmounts[1] = amount2;
        assetAmounts[2] = amount3;

        uint256 totalShares = gatedToken.previewDeposit(totalAssets);

        vm.prank(address(escrow));
        gatedToken.batchMintShares(depositIds, recipients, assetAmounts, totalAssets);

        // Check proportional distribution
        uint256 aliceExpected = (amount1 * totalShares) / totalAssets;
        uint256 bobExpected = (amount2 * totalShares) / totalAssets;
        uint256 charlieExpected = (amount3 * totalShares) / totalAssets;

        assertEq(gatedToken.balanceOf(alice), aliceExpected);
        assertEq(gatedToken.balanceOf(bob), bobExpected);
        assertEq(gatedToken.balanceOf(charlie), charlieExpected);

        // Bob should have 3x alice's shares (3000 vs 1000)
        assertEq(gatedToken.balanceOf(bob), gatedToken.balanceOf(alice) * 3);
        // Charlie should equal alice (both 1000)
        assertEq(gatedToken.balanceOf(charlie), gatedToken.balanceOf(alice));
    }

    function test_Deposit_EmitsDepositPendingEvent() public {
        vm.prank(alice);
        usdc.approve(address(mockConduit), DEPOSIT_AMOUNT);

        // We can't predict the exact depositId, but we can check the event is emitted
        vm.prank(alice);
        vm.expectEmit(false, true, true, true); // Don't check depositId (first param)
        emit GatedMintRWA.DepositPending(bytes32(0), alice, bob, DEPOSIT_AMOUNT);

        gatedToken.deposit(DEPOSIT_AMOUNT, bob);
    }

    function test_BatchMintShares_ZeroAssets() public {
        bytes32[] memory depositIds = new bytes32[](1);
        depositIds[0] = keccak256("zero");

        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 0; // Zero assets

        uint256 totalAssets = 0;

        // Record initial balance
        uint256 aliceBalanceBefore = gatedToken.balanceOf(alice);

        vm.prank(address(escrow));
        // This should succeed but mint 0 shares
        gatedToken.batchMintShares(depositIds, recipients, assetAmounts, totalAssets);

        // Verify no shares were minted
        assertEq(gatedToken.balanceOf(alice), aliceBalanceBefore);
    }

    // ============ Helper Functions ============

    function _createPendingDeposit(address depositor, address recipient, uint256 amount) internal returns (bytes32) {
        vm.prank(depositor);
        usdc.approve(address(mockConduit), amount);

        vm.prank(depositor);
        gatedToken.deposit(amount, recipient);

        bytes32[] memory pendingDeposits = gatedToken.getUserPendingDeposits(depositor);
        return pendingDeposits[pendingDeposits.length - 1];
    }
}
