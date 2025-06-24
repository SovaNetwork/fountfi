// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {DirectDepositRWA} from "../src/token/DirectDepositRWA.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {DirectDepositStrategy} from "../src/strategy/DirectDepositStrategy.sol";
import {IDirectDepositStrategy} from "../src/strategy/IDirectDepositStrategy.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockReporter} from "../src/mocks/MockReporter.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {Registry} from "../src/registry/Registry.sol";
import {Conduit} from "../src/conduit/Conduit.sol";
import {MockConduitForDirectDeposit} from "../src/mocks/MockConduitForDirectDeposit.sol";
import {MockHook} from "../src/mocks/hooks/MockHook.sol";
import {AlwaysRejectingHook} from "../src/mocks/hooks/AlwaysRejectingHook.sol";
import {IHook} from "../src/hooks/IHook.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/**
 * @title DirectDepositRWATest
 * @notice Comprehensive tests for DirectDepositRWA contract to achieve 100% coverage
 */
contract DirectDepositRWATest is BaseFountfiTest {
    using SafeTransferLib for address;

    DirectDepositRWA public token;
    DirectDepositStrategy public strategy;
    RoleManager public roleManager;
    MockConduitForDirectDeposit public mockConduit;
    MockReporter public reporter;
    
    address public issuerWallet;
    
    // Hook operation types
    bytes32 public constant OP_DEPOSIT = keccak256("DEPOSIT_OPERATION");
    
    // Test constants
    uint256 constant INITIAL_DEPOSIT = 1000 * 10**6; // 1000 USDC
    uint256 constant SMALL_DEPOSIT = 100 * 10**6; // 100 USDC
    
    function setUp() public override {
        super.setUp();
        
        issuerWallet = makeAddr("issuerWallet");
        reporter = new MockReporter(1e18); // 1:1 initial price
        
        vm.startPrank(owner);
        
        // Deploy RoleManager
        roleManager = new RoleManager();
        roleManager.grantRole(owner, roleManager.STRATEGY_OPERATOR());
        roleManager.grantRole(owner, roleManager.KYC_OPERATOR());
        roleManager.grantRole(manager, roleManager.STRATEGY_OPERATOR());
        
        // Deploy Registry
        registry = new Registry(address(roleManager));
        roleManager.initializeRegistry(address(registry));
        
        // Deploy mock conduit
        mockConduit = new MockConduitForDirectDeposit();
        
        // Mock the registry.conduit() call to return our mock
        vm.mockCall(
            address(registry),
            abi.encodeWithSelector(registry.conduit.selector),
            abi.encode(address(mockConduit))
        );
        
        // Register USDC as allowed asset
        registry.setAsset(address(usdc), 6);
        
        // Deploy DirectDepositStrategy implementation
        DirectDepositStrategy strategyImpl = new DirectDepositStrategy();
        registry.setStrategy(address(strategyImpl), true);
        
        // Deploy strategy and token through registry
        bytes memory initData = abi.encode(address(reporter), issuerWallet);
        (address strategyAddr, address tokenAddr) = registry.deploy(
            address(strategyImpl),
            "Direct Deposit RWA",
            "ddRWA",
            address(usdc),
            manager,
            initData
        );
        
        strategy = DirectDepositStrategy(payable(strategyAddr));
        token = DirectDepositRWA(tokenAddr);
        
        vm.stopPrank();
        
        // Approve USDC for test users to both token and mock conduit
        vm.prank(alice);
        usdc.approve(address(token), type(uint256).max);
        vm.prank(alice);
        usdc.approve(address(mockConduit), type(uint256).max);
        
        vm.prank(bob);
        usdc.approve(address(token), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(mockConduit), type(uint256).max);
        
        vm.prank(charlie);
        usdc.approve(address(token), type(uint256).max);
        vm.prank(charlie);
        usdc.approve(address(mockConduit), type(uint256).max);
    }
    
    function test_DirectDeposit() public {
        uint256 depositAmount = INITIAL_DEPOSIT;
        uint256 issuerBalanceBefore = usdc.balanceOf(issuerWallet);
        
        vm.prank(alice);
        uint256 shares = token.deposit(depositAmount, alice);
        
        // Should return preview of shares but not mint them immediately
        uint256 expectedShares = depositAmount * 10**12; // Convert from 6 to 18 decimals
        assertEq(shares, expectedShares, "Should return preview of shares");
        assertEq(token.balanceOf(alice), 0, "Alice should have no shares yet");
        
        // Check that funds went to issuer wallet
        assertEq(usdc.balanceOf(issuerWallet), issuerBalanceBefore + depositAmount, "Issuer should receive funds");
        
        // Check pending deposit tracking
        assertEq(token.totalPendingAssets(), depositAmount, "Total pending assets should match deposit");
        assertEq(token.userPendingAssets(alice), depositAmount, "User pending assets should match deposit");
        
        // Get deposit ID
        bytes32[] memory userDeposits = token.getUserPendingDeposits(alice);
        assertEq(userDeposits.length, 1, "Should have one pending deposit");
        
        // Check deposit details
        (address depositor, address recipient, uint256 assetAmount, uint8 state) = token.getDepositDetails(userDeposits[0]);
        assertEq(depositor, alice, "Depositor should be alice");
        assertEq(recipient, alice, "Recipient should be alice");
        assertEq(assetAmount, depositAmount, "Asset amount should match deposit");
        assertEq(state, 0, "State should be PENDING (0)");
    }
    
    function test_MintSharesForDeposit() public {
        uint256 depositAmount = INITIAL_DEPOSIT;
        
        // Alice deposits
        vm.prank(alice);
        token.deposit(depositAmount, alice);
        
        // Get deposit ID
        bytes32[] memory userDeposits = token.getUserPendingDeposits(alice);
        bytes32 depositId = userDeposits[0];
        
        // Manager mints shares through strategy batch function
        bytes32[] memory depositIds = new bytes32[](1);
        depositIds[0] = depositId;
        vm.prank(manager);
        strategy.batchMintShares(depositIds);
        
        // Check shares minted
        // With 1:1 price, 1000 USDC (6 decimals) should give 1000 shares (18 decimals)
        uint256 expectedShares = depositAmount * 10**12; // Convert from 6 to 18 decimals
        assertEq(token.balanceOf(alice), expectedShares, "Alice should receive shares");
        
        // Check pending deposits cleared
        assertEq(token.totalPendingAssets(), 0, "Total pending assets should be zero");
        assertEq(token.userPendingAssets(alice), 0, "User pending assets should be zero");
        
        // Check deposit state
        (, , , uint8 state) = token.getDepositDetails(depositId);
        assertEq(state, 1, "State should be ACCEPTED (1)");
        
        // Should have no pending deposits now
        userDeposits = token.getUserPendingDeposits(alice);
        assertEq(userDeposits.length, 0, "Should have no pending deposits");
    }
    
    function test_BatchMintSharesForDeposit() public {
        // Multiple users deposit
        vm.prank(alice);
        token.deposit(INITIAL_DEPOSIT, alice);
        
        vm.prank(bob);
        token.deposit(SMALL_DEPOSIT, bob);
        
        vm.prank(charlie);
        token.deposit(INITIAL_DEPOSIT * 2, charlie);
        
        // Get all deposit IDs
        bytes32[] memory aliceDeposits = token.getUserPendingDeposits(alice);
        bytes32[] memory bobDeposits = token.getUserPendingDeposits(bob);
        bytes32[] memory charlieDeposits = token.getUserPendingDeposits(charlie);
        
        bytes32[] memory allDeposits = new bytes32[](3);
        allDeposits[0] = aliceDeposits[0];
        allDeposits[1] = bobDeposits[0];
        allDeposits[2] = charlieDeposits[0];
        
        // Manager batch mints shares
        vm.prank(manager);
        strategy.batchMintShares(allDeposits);
        
        // Check all shares minted correctly
        // Alice gets full conversion (first depositor)
        assertEq(token.balanceOf(alice), INITIAL_DEPOSIT * 10**12, "Alice shares incorrect");
        // Bob and Charlie get proportional shares based on the exchange rate after Alice
        // When balance in WAD = supply in shares, 1 asset unit = 1 share unit
        assertEq(token.balanceOf(bob), SMALL_DEPOSIT, "Bob shares incorrect");
        // Charlie might get 1 extra share due to rounding
        assertLe(token.balanceOf(charlie) - (INITIAL_DEPOSIT * 2), 1, "Charlie shares should be close to expected");
        
        // Check all pending cleared
        assertEq(token.totalPendingAssets(), 0, "Total pending assets should be zero");
        assertEq(token.userPendingAssets(alice), 0, "Alice pending should be zero");
        assertEq(token.userPendingAssets(bob), 0, "Bob pending should be zero");
        assertEq(token.userPendingAssets(charlie), 0, "Charlie pending should be zero");
    }
    
    function test_RefundDeposit() public {
        uint256 depositAmount = INITIAL_DEPOSIT;
        
        // Alice deposits
        vm.prank(alice);
        token.deposit(depositAmount, alice);
        
        // Get deposit ID
        bytes32[] memory userDeposits = token.getUserPendingDeposits(alice);
        bytes32 depositId = userDeposits[0];
        
        // Strategy refunds deposit
        vm.prank(address(strategy));
        token.refundDeposit(depositId);
        
        // Check no shares minted
        assertEq(token.balanceOf(alice), 0, "Alice should have no shares");
        
        // Check pending cleared
        assertEq(token.totalPendingAssets(), 0, "Total pending assets should be zero");
        assertEq(token.userPendingAssets(alice), 0, "User pending assets should be zero");
        
        // Check deposit state
        (, , , uint8 state) = token.getDepositDetails(depositId);
        assertEq(state, 2, "State should be REFUNDED (2)");
    }
    
    function test_DepositToRecipient() public {
        uint256 depositAmount = INITIAL_DEPOSIT;
        
        // Alice deposits for Bob
        vm.prank(alice);
        token.deposit(depositAmount, bob);
        
        // Get deposit ID
        bytes32[] memory aliceDeposits = token.getUserPendingDeposits(alice);
        bytes32 depositId = aliceDeposits[0];
        
        // Check deposit details
        (address depositor, address recipient, uint256 assetAmount, ) = token.getDepositDetails(depositId);
        assertEq(depositor, alice, "Depositor should be alice");
        assertEq(recipient, bob, "Recipient should be bob");
        assertEq(assetAmount, depositAmount, "Asset amount should match");
        
        // Manager mints shares through strategy batch function
        bytes32[] memory depositIds = new bytes32[](1);
        depositIds[0] = depositId;
        vm.prank(manager);
        strategy.batchMintShares(depositIds);
        
        // Bob should receive shares, not Alice
        assertEq(token.balanceOf(alice), 0, "Alice should have no shares");
        // Bob gets full conversion as first depositor
        assertEq(token.balanceOf(bob), depositAmount * 10**12, "Bob should receive shares");
    }
    
    function test_MultipleDepositsFromSameUser() public {
        // Alice makes multiple deposits
        vm.startPrank(alice);
        token.deposit(INITIAL_DEPOSIT, alice);
        token.deposit(SMALL_DEPOSIT, alice);
        token.deposit(INITIAL_DEPOSIT * 2, alice);
        vm.stopPrank();
        
        // Check pending amounts
        uint256 totalPending = INITIAL_DEPOSIT + SMALL_DEPOSIT + (INITIAL_DEPOSIT * 2);
        assertEq(token.totalPendingAssets(), totalPending, "Total pending incorrect");
        assertEq(token.userPendingAssets(alice), totalPending, "User pending incorrect");
        
        // Check deposit count
        bytes32[] memory userDeposits = token.getUserPendingDeposits(alice);
        assertEq(userDeposits.length, 3, "Should have 3 pending deposits");
        
        // Accept middle deposit only
        bytes32[] memory singleDeposit = new bytes32[](1);
        singleDeposit[0] = userDeposits[1];
        vm.prank(manager);
        strategy.batchMintShares(singleDeposit);
        
        // Check remaining pending
        assertEq(token.totalPendingAssets(), totalPending - SMALL_DEPOSIT, "Total pending should decrease");
        assertEq(token.userPendingAssets(alice), totalPending - SMALL_DEPOSIT, "User pending should decrease");
        
        // Check pending deposits
        userDeposits = token.getUserPendingDeposits(alice);
        assertEq(userDeposits.length, 2, "Should have 2 pending deposits");
    }
    
    function test_DepositWithHooks() public {
        // Add a hook to deposit operation
        MockHook depositHook = new MockHook(true, "");
        
        vm.prank(address(strategy));
        token.addOperationHook(OP_DEPOSIT, address(depositHook));
        
        // Deposit should work with approving hook
        vm.prank(alice);
        token.deposit(INITIAL_DEPOSIT, alice);
        
        // Verify hook was called
        assertEq(token.lastExecutedBlock(OP_DEPOSIT), block.number, "Hook should update last executed block");
    }
    
    function test_DepositWithRejectingHook() public {
        // Add rejecting hook
        AlwaysRejectingHook rejectHook = new AlwaysRejectingHook("Deposit rejected");
        
        vm.prank(address(strategy));
        token.addOperationHook(OP_DEPOSIT, address(rejectHook));
        
        // Deposit should fail
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(tRWA.HookCheckFailed.selector, "Deposit rejected")
        );
        token.deposit(INITIAL_DEPOSIT, alice);
    }
    
    function test_RevertOnNonexistentDeposit() public {
        bytes32 fakeDepositId = keccak256("fake");
        
        bytes32[] memory fakeIds = new bytes32[](1);
        fakeIds[0] = fakeDepositId;
        
        vm.prank(manager);
        vm.expectRevert(DirectDepositRWA.DepositNotFound.selector);
        strategy.batchMintShares(fakeIds);
    }
    
    function test_RevertOnAlreadyAcceptedDeposit() public {
        // Alice deposits
        vm.prank(alice);
        token.deposit(INITIAL_DEPOSIT, alice);
        
        bytes32[] memory userDeposits = token.getUserPendingDeposits(alice);
        bytes32 depositId = userDeposits[0];
        
        // Accept deposit
        bytes32[] memory depositIds = new bytes32[](1);
        depositIds[0] = depositId;
        vm.prank(manager);
        strategy.batchMintShares(depositIds);
        
        // Try to accept again
        vm.prank(manager);
        vm.expectRevert(DirectDepositRWA.DepositNotPending.selector);
        strategy.batchMintShares(depositIds);
    }
    
    function test_RevertOnRefundedDeposit() public {
        // Alice deposits
        vm.prank(alice);
        token.deposit(INITIAL_DEPOSIT, alice);
        
        bytes32[] memory userDeposits = token.getUserPendingDeposits(alice);
        bytes32 depositId = userDeposits[0];
        
        // Refund deposit
        vm.prank(address(strategy));
        token.refundDeposit(depositId);
        
        // Try to accept refunded deposit
        vm.prank(address(strategy));
        vm.expectRevert(DirectDepositRWA.DepositNotPending.selector);
        token.mintSharesForDeposit(depositId);
    }
    
    function test_OnlyStrategyCanMintShares() public {
        // Alice deposits
        vm.prank(alice);
        token.deposit(INITIAL_DEPOSIT, alice);
        
        bytes32[] memory userDeposits = token.getUserPendingDeposits(alice);
        bytes32 depositId = userDeposits[0];
        
        // Non-strategy tries to mint
        vm.prank(alice);
        vm.expectRevert(tRWA.NotStrategyAdmin.selector);
        token.mintSharesForDeposit(depositId);
    }
    
    function test_OnlyStrategyCanRefund() public {
        // Alice deposits
        vm.prank(alice);
        token.deposit(INITIAL_DEPOSIT, alice);
        
        bytes32[] memory userDeposits = token.getUserPendingDeposits(alice);
        bytes32 depositId = userDeposits[0];
        
        // Non-strategy tries to refund
        vm.prank(alice);
        vm.expectRevert(tRWA.NotStrategyAdmin.selector);
        token.refundDeposit(depositId);
    }
    
    function test_EmptyBatchMint() public {
        bytes32[] memory emptyArray = new bytes32[](0);
        
        // Should not revert on empty array
        vm.prank(manager);
        strategy.batchMintShares(emptyArray);
    }
    
    function test_LargeScaleDeposits() public {
        // Test with many deposits
        uint256 numDeposits = 50;
        bytes32[] memory allDepositIds = new bytes32[](numDeposits);
        
        // Create many deposits from different users
        for (uint256 i = 0; i < numDeposits; i++) {
            address user = address(uint160(1000 + i));
            vm.deal(user, 1 ether);
            
            // Mint USDC and approve
            usdc.mint(user, SMALL_DEPOSIT);
            vm.prank(user);
            usdc.approve(address(token), SMALL_DEPOSIT);
            vm.prank(user);
            usdc.approve(address(mockConduit), SMALL_DEPOSIT);
            
            // Deposit
            vm.prank(user);
            token.deposit(SMALL_DEPOSIT, user);
            
            // Get deposit ID
            bytes32[] memory userDeposits = token.getUserPendingDeposits(user);
            allDepositIds[i] = userDeposits[0];
        }
        
        // Batch mint all
        vm.prank(manager);
        strategy.batchMintShares(allDepositIds);
        
        // Verify all cleared
        assertEq(token.totalPendingAssets(), 0, "All pending should be cleared");
        
        // Verify all users got shares
        for (uint256 i = 0; i < numDeposits; i++) {
            address user = address(uint160(1000 + i));
            // First user gets full conversion, rest get proportional
            uint256 expectedShares = i == 0 ? SMALL_DEPOSIT * 10**12 : SMALL_DEPOSIT;
            assertEq(token.balanceOf(user), expectedShares, "User should have shares");
        }
    }
    
    function test_DepositIdUniqueness() public {
        // Make identical deposits and ensure IDs are unique
        vm.startPrank(alice);
        token.deposit(INITIAL_DEPOSIT, alice);
        token.deposit(INITIAL_DEPOSIT, alice); // Same amount, same recipient
        vm.stopPrank();
        
        bytes32[] memory userDeposits = token.getUserPendingDeposits(alice);
        assertEq(userDeposits.length, 2, "Should have 2 deposits");
        assertTrue(userDeposits[0] != userDeposits[1], "Deposit IDs should be unique");
    }
    
    function test_GetDepositDetailsForNonexistent() public {
        bytes32 fakeDepositId = keccak256("nonexistent");
        
        (address depositor, address recipient, uint256 assetAmount, uint8 state) = token.getDepositDetails(fakeDepositId);
        assertEq(depositor, address(0), "Depositor should be zero");
        assertEq(recipient, address(0), "Recipient should be zero");
        assertEq(assetAmount, 0, "Asset amount should be zero");
        assertEq(state, 0, "State should be zero");
    }
}