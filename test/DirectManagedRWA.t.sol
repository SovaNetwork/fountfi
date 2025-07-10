// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {DirectManagedRWA} from "../src/token/DirectManagedRWA.sol";
import {DirectManagedStrategy} from "../src/strategy/DirectManagedStrategy.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {DirectDepositRWA} from "../src/token/DirectDepositRWA.sol";
import {ManagedWithdrawRWA} from "../src/token/ManagedWithdrawRWA.sol";
import {IDirectDepositStrategy} from "../src/strategy/IDirectDepositStrategy.sol";
import {MockConduitForDirectDeposit} from "../src/mocks/MockConduitForDirectDeposit.sol";
import {MockReporter} from "../src/mocks/MockReporter.sol";
import {MockHook} from "../src/mocks/hooks/MockHook.sol";
import {AlwaysRejectingHook} from "../src/mocks/hooks/AlwaysRejectingHook.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IHook} from "../src/hooks/IHook.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {Registry} from "../src/registry/Registry.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";

/**
 * @title HookHelper
 * @notice Helper contract to add hooks to DirectManagedRWA since only strategy can add hooks
 */
contract HookHelper {
    DirectManagedRWA public token;

    constructor(DirectManagedRWA _token) {
        token = _token;
    }

    function addHook(bytes32 operation, address hook) external {
        token.addOperationHook(operation, hook);
    }
}

contract DirectManagedRWATest is BaseFountfiTest {
    using SafeTransferLib for address;

    DirectManagedRWA public directManagedRWA;
    DirectManagedStrategy public strategy;
    MockConduitForDirectDeposit public conduitForDirectDeposit;
    MockReporter public reporter;
    RoleManager public roleManager;

    address public issuerWallet = makeAddr("issuerWallet");
    uint256 public constant INITIAL_PRICE = 1e18;
    uint256 public constant DEPOSIT_AMOUNT = 1000e6;
    uint8 public constant USDC_DECIMALS = 6;

    // Hook operation types
    bytes32 public constant OP_DEPOSIT = keccak256("DEPOSIT_OPERATION");
    bytes32 public constant OP_WITHDRAW = keccak256("WITHDRAW_OPERATION");

    // Events
    event DirectDepositPending(
        bytes32 indexed depositId, address indexed depositor, address indexed recipient, uint256 assets
    );
    event DepositAccepted(bytes32 indexed depositId, address indexed recipient, uint256 assets, uint256 shares);
    event DepositRefunded(bytes32 indexed depositId, address indexed depositor, uint256 assets);
    event BatchDepositsAccepted(bytes32[] depositIds, uint256 totalAssets, uint256 totalShares);
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    function setUp() public override {
        super.setUp();

        // Deploy mocks
        conduitForDirectDeposit = new MockConduitForDirectDeposit();
        reporter = new MockReporter(INITIAL_PRICE);

        // Mock all registry-related calls
        vm.mockCall(
            address(registry),
            abi.encodeWithSelector(registry.conduit.selector),
            abi.encode(address(conduitForDirectDeposit))
        );

        // Deploy RoleManager
        roleManager = new RoleManager();
        roleManager.grantRole(owner, roleManager.STRATEGY_OPERATOR());
        roleManager.grantRole(manager, roleManager.STRATEGY_OPERATOR());

        // Initialize registry with roleManager
        roleManager.initializeRegistry(address(registry));

        // Also mock roleManager.registry() calls to return our registry
        vm.mockCall(
            address(roleManager), abi.encodeWithSelector(roleManager.registry.selector), abi.encode(address(registry))
        );

        // Deploy and initialize strategy
        strategy = new DirectManagedStrategy();

        // Initialize strategy with issuer wallet
        strategy.initialize(
            "DirectManaged RWA Token",
            "dmRWA",
            address(roleManager),
            manager,
            address(usdc),
            USDC_DECIMALS,
            abi.encode(address(reporter), issuerWallet)
        );

        directManagedRWA = DirectManagedRWA(strategy.sToken());

        // Setup initial balances and approvals
        usdc.mint(address(this), 1000000e6);
        usdc.mint(alice, 1000000e6);
        usdc.mint(bob, 1000000e6);
        usdc.mint(issuerWallet, 10000000e6); // Issuer wallet needs lots of funds for redemptions

        usdc.approve(address(directManagedRWA), type(uint256).max);
        usdc.approve(address(conduitForDirectDeposit), type(uint256).max);
        vm.startPrank(alice);
        usdc.approve(address(directManagedRWA), type(uint256).max);
        usdc.approve(address(conduitForDirectDeposit), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(address(directManagedRWA), type(uint256).max);
        usdc.approve(address(conduitForDirectDeposit), type(uint256).max);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Deposit_CreatesValidPendingDeposit() public {
        uint256 assets = DEPOSIT_AMOUNT;

        // The deposit will emit DirectDepositPending event

        vm.prank(alice);
        directManagedRWA.deposit(assets, alice);

        // Verify deposit state
        bytes32[] memory deposits = directManagedRWA.getUserPendingDeposits(alice);
        assertEq(deposits.length, 1);

        (address depositor, address recipient, uint256 assetAmount, uint8 state) =
            directManagedRWA.getDepositDetails(deposits[0]);

        assertEq(depositor, alice);
        assertEq(recipient, alice);
        assertEq(assetAmount, assets);
        assertEq(state, 0); // PENDING

        // Verify accounting
        assertEq(directManagedRWA.totalPendingAssets(), assets);
        assertEq(directManagedRWA.userPendingAssets(alice), assets);

        // Verify assets were sent to issuer wallet (issuer had initial balance)
        assertGe(usdc.balanceOf(issuerWallet), assets);
    }

    function test_Deposit_MultipleDepositsFromSameUser() public {
        vm.startPrank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT * 2, alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT * 3, alice);
        vm.stopPrank();

        bytes32[] memory deposits = directManagedRWA.getUserPendingDeposits(alice);
        assertEq(deposits.length, 3);
        assertEq(directManagedRWA.totalPendingAssets(), DEPOSIT_AMOUNT * 6);
        assertEq(directManagedRWA.userPendingAssets(alice), DEPOSIT_AMOUNT * 6);
    }

    function test_Deposit_DifferentRecipient() public {
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, bob);

        bytes32[] memory aliceDeposits = directManagedRWA.getUserPendingDeposits(alice);
        bytes32[] memory bobDeposits = directManagedRWA.getUserPendingDeposits(bob);

        assertEq(aliceDeposits.length, 1);
        assertEq(bobDeposits.length, 0); // Bob is recipient, not depositor

        (address depositor, address recipient,,) = directManagedRWA.getDepositDetails(aliceDeposits[0]);
        assertEq(depositor, alice);
        assertEq(recipient, bob);
    }

    function test_Deposit_WithHooks() public {
        // Create a passing hook
        MockHook passingHook = new MockHook(true, "");

        // Add hook through strategy
        vm.prank(address(strategy));
        directManagedRWA.addOperationHook(OP_DEPOSIT, address(passingHook));

        // Deposit should work with approving hook
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        // Verify hook was called by checking lastExecutedBlock
        assertEq(directManagedRWA.lastExecutedBlock(OP_DEPOSIT), block.number);
    }

    function test_Deposit_RevertWhenHookFails() public {
        // Create rejecting hook
        AlwaysRejectingHook rejectHook = new AlwaysRejectingHook("Deposit rejected by hook");

        // Add hook through strategy
        vm.prank(address(strategy));
        directManagedRWA.addOperationHook(OP_DEPOSIT, address(rejectHook));

        // Deposit should fail
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(tRWA.HookCheckFailed.selector, "Deposit rejected by hook"));
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);
    }

    /*//////////////////////////////////////////////////////////////
                    MINT SHARES TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MintSharesForDeposit_Success() public {
        // Create deposit
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32[] memory deposits = directManagedRWA.getUserPendingDeposits(alice);
        bytes32 depositId = deposits[0];

        // Mint shares
        uint256 expectedShares = directManagedRWA.previewDeposit(DEPOSIT_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit DepositAccepted(depositId, alice, DEPOSIT_AMOUNT, expectedShares);

        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(depositId);

        // Verify state
        assertEq(directManagedRWA.balanceOf(alice), expectedShares);
        assertEq(directManagedRWA.totalPendingAssets(), 0);
        assertEq(directManagedRWA.userPendingAssets(alice), 0);

        // Verify deposit state changed
        (,,, uint8 state) = directManagedRWA.getDepositDetails(depositId);
        assertEq(state, 1); // ACCEPTED

        // Verify no longer in pending list
        bytes32[] memory pendingDeposits = directManagedRWA.getUserPendingDeposits(alice);
        assertEq(pendingDeposits.length, 0);
    }

    function test_MintSharesForDeposit_RevertNonExistentDeposit() public {
        bytes32 fakeId = keccak256("fake");

        vm.expectRevert(DirectDepositRWA.DepositNotFound.selector);
        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(fakeId);
    }

    function test_MintSharesForDeposit_RevertAlreadyAccepted() public {
        // Create and accept deposit
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32[] memory deposits = directManagedRWA.getUserPendingDeposits(alice);
        bytes32 depositId = deposits[0];

        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(depositId);

        // Try to accept again
        vm.expectRevert(DirectDepositRWA.DepositNotPending.selector);
        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(depositId);
    }

    function test_MintSharesForDeposit_RevertNotStrategy() public {
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32[] memory deposits = directManagedRWA.getUserPendingDeposits(alice);

        vm.expectRevert(tRWA.NotStrategyAdmin.selector);
        directManagedRWA.mintSharesForDeposit(deposits[0]);
    }

    function test_BatchMintSharesForDeposit_Success() public {
        // Create multiple deposits
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);
        vm.prank(bob);
        directManagedRWA.deposit(DEPOSIT_AMOUNT * 2, bob);
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT * 3, alice);

        bytes32[] memory aliceDeposits = directManagedRWA.getUserPendingDeposits(alice);
        bytes32[] memory bobDeposits = directManagedRWA.getUserPendingDeposits(bob);

        bytes32[] memory allDeposits = new bytes32[](3);
        allDeposits[0] = aliceDeposits[0];
        allDeposits[1] = bobDeposits[0];
        allDeposits[2] = aliceDeposits[1];

        // Don't check the exact amounts due to rounding
        vm.expectEmit(true, false, false, false);
        emit BatchDepositsAccepted(allDeposits, 0, 0);

        vm.prank(address(strategy));
        directManagedRWA.batchMintSharesForDeposit(allDeposits);

        // Verify balances - alice deposited 1000 + 3000, bob deposited 2000
        assertGt(directManagedRWA.balanceOf(alice), 0);
        assertGt(directManagedRWA.balanceOf(bob), 0);

        // Verify accounting cleared
        assertEq(directManagedRWA.totalPendingAssets(), 0);
        assertEq(directManagedRWA.userPendingAssets(alice), 0);
        assertEq(directManagedRWA.userPendingAssets(bob), 0);
    }

    function test_BatchMintSharesForDeposit_EmptyArray() public {
        bytes32[] memory empty = new bytes32[](0);

        vm.prank(address(strategy));
        directManagedRWA.batchMintSharesForDeposit(empty);

        // Should succeed without doing anything
        assertEq(directManagedRWA.totalSupply(), 0);
    }

    function test_BatchMintSharesForDeposit_RevertMixedStates() public {
        // Create deposits
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);
        vm.prank(bob);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, bob);

        bytes32[] memory deposits = new bytes32[](2);
        deposits[0] = directManagedRWA.getUserPendingDeposits(alice)[0];
        deposits[1] = directManagedRWA.getUserPendingDeposits(bob)[0];

        // Accept first deposit
        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(deposits[0]);

        // Try batch with already accepted deposit
        vm.expectRevert(DirectDepositRWA.DepositNotPending.selector);
        vm.prank(address(strategy));
        directManagedRWA.batchMintSharesForDeposit(deposits);
    }

    /*//////////////////////////////////////////////////////////////
                        REFUND TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RefundDeposit_Success() public {
        // Create deposit
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32 depositId = directManagedRWA.getUserPendingDeposits(alice)[0];

        // Transfer funds back to strategy first (simulating issuer returning funds)
        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), DEPOSIT_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit DepositRefunded(depositId, alice, DEPOSIT_AMOUNT);

        vm.prank(address(strategy));
        directManagedRWA.refundDeposit(depositId);

        // Verify state
        (,,, uint8 state) = directManagedRWA.getDepositDetails(depositId);
        assertEq(state, 2); // REFUNDED

        // Verify accounting
        assertEq(directManagedRWA.totalPendingAssets(), 0);
        assertEq(directManagedRWA.userPendingAssets(alice), 0);

        // Verify no pending deposits
        assertEq(directManagedRWA.getUserPendingDeposits(alice).length, 0);
    }

    function test_RefundDeposit_RevertNotStrategy() public {
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32 depositId = directManagedRWA.getUserPendingDeposits(alice)[0];

        vm.expectRevert(tRWA.NotStrategyAdmin.selector);
        directManagedRWA.refundDeposit(depositId);
    }

    function test_RefundDeposit_RevertNonExistent() public {
        vm.expectRevert(DirectDepositRWA.DepositNotFound.selector);
        vm.prank(address(strategy));
        directManagedRWA.refundDeposit(bytes32(0));
    }

    function test_RefundDeposit_RevertAlreadyRefunded() public {
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32 depositId = directManagedRWA.getUserPendingDeposits(alice)[0];

        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), DEPOSIT_AMOUNT);

        vm.prank(address(strategy));
        directManagedRWA.refundDeposit(depositId);

        vm.expectRevert(DirectDepositRWA.DepositNotPending.selector);
        vm.prank(address(strategy));
        directManagedRWA.refundDeposit(depositId);
    }

    /*//////////////////////////////////////////////////////////////
                    MANAGED WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Redeem_WithMinAssets_Success() public {
        // Setup: Create deposit and mint shares
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32 depositId = directManagedRWA.getUserPendingDeposits(alice)[0];
        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(depositId);

        uint256 shares = directManagedRWA.balanceOf(alice);
        uint256 expectedAssets = directManagedRWA.previewRedeem(shares);

        // Alice approves strategy
        vm.prank(alice);
        directManagedRWA.approve(address(strategy), shares);

        // Ensure issuer wallet has enough balance
        if (usdc.balanceOf(issuerWallet) < expectedAssets) {
            usdc.mint(issuerWallet, expectedAssets - usdc.balanceOf(issuerWallet));
        }

        // Transfer assets to strategy for withdrawal
        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), expectedAssets);

        // Strategy needs to approve the token to pull assets
        vm.prank(address(strategy));
        usdc.approve(address(directManagedRWA), expectedAssets);

        // Redeem with minAssets check
        uint256 minAssets = expectedAssets;

        vm.expectEmit(true, true, true, true);
        emit Withdraw(address(strategy), alice, alice, expectedAssets, shares);

        vm.prank(address(strategy));
        uint256 assets = directManagedRWA.redeem(shares, alice, alice, minAssets);

        assertEq(assets, expectedAssets);
        assertEq(directManagedRWA.balanceOf(alice), 0);

        // Verify the withdrawal was successful - alice received assets
        assertGt(usdc.balanceOf(alice), 1000000e6 - DEPOSIT_AMOUNT); // Alice has more than initial minus deposit
    }

    function test_Redeem_RevertInsufficientAssets() public {
        // Setup shares
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32 depositId = directManagedRWA.getUserPendingDeposits(alice)[0];
        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(depositId);

        uint256 shares = directManagedRWA.balanceOf(alice);
        uint256 expectedAssets = directManagedRWA.previewRedeem(shares);

        vm.prank(alice);
        directManagedRWA.approve(address(strategy), shares);

        // Ensure issuer wallet has enough balance
        if (usdc.balanceOf(issuerWallet) < expectedAssets) {
            usdc.mint(issuerWallet, expectedAssets - usdc.balanceOf(issuerWallet));
        }

        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), expectedAssets);

        // Try to redeem with higher minAssets than available
        uint256 minAssets = expectedAssets + 1;

        vm.expectRevert(DirectManagedRWA.InsufficientOutputAssets.selector);
        vm.prank(address(strategy));
        directManagedRWA.redeem(shares, alice, alice, minAssets);
    }

    function test_Redeem_RevertNotStrategy() public {
        vm.expectRevert(tRWA.NotStrategyAdmin.selector);
        directManagedRWA.redeem(100, alice, alice, 100);
    }

    function test_Redeem_RevertExceedsMax() public {
        // Setup shares
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32 depositId = directManagedRWA.getUserPendingDeposits(alice)[0];
        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(depositId);

        uint256 shares = directManagedRWA.balanceOf(alice);

        // Try to redeem more shares than alice has
        uint256 excessShares = shares + 1;

        vm.expectRevert(ERC4626.RedeemMoreThanMax.selector);
        vm.prank(address(strategy));
        directManagedRWA.redeem(excessShares, alice, alice, 0);
    }

    function test_BatchRedeemShares_Success() public {
        // Setup: Create deposits and mint shares for multiple users
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = DEPOSIT_AMOUNT;
        amounts[1] = DEPOSIT_AMOUNT * 2;
        amounts[2] = DEPOSIT_AMOUNT * 3;

        address[] memory users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = alice;

        // Create deposits
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            directManagedRWA.deposit(amounts[i], users[i]);
        }

        // Mint all shares
        bytes32[] memory allDeposits = new bytes32[](3);
        allDeposits[0] = directManagedRWA.getUserPendingDeposits(alice)[0];
        allDeposits[1] = directManagedRWA.getUserPendingDeposits(bob)[0];
        allDeposits[2] = directManagedRWA.getUserPendingDeposits(alice)[1];

        vm.prank(address(strategy));
        directManagedRWA.batchMintSharesForDeposit(allDeposits);

        // Prepare batch redemption
        uint256[] memory shares = new uint256[](3);
        shares[0] = directManagedRWA.balanceOf(alice) / 2; // Alice redeems half
        shares[1] = directManagedRWA.balanceOf(bob);
        shares[2] = directManagedRWA.balanceOf(alice) / 2; // Alice redeems other half

        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = alice;

        address[] memory owners = new address[](3);
        owners[0] = alice;
        owners[1] = bob;
        owners[2] = alice;

        uint256[] memory minAssets = new uint256[](3);
        for (uint256 i = 0; i < shares.length; i++) {
            minAssets[i] = directManagedRWA.previewRedeem(shares[i]);
        }

        // Approve strategy
        vm.prank(alice);
        directManagedRWA.approve(address(strategy), type(uint256).max);
        vm.prank(bob);
        directManagedRWA.approve(address(strategy), type(uint256).max);

        // Transfer assets to strategy
        uint256 totalAssets = minAssets[0] + minAssets[1] + minAssets[2];

        // Ensure issuer wallet has enough balance
        if (usdc.balanceOf(issuerWallet) < totalAssets) {
            usdc.mint(issuerWallet, totalAssets - usdc.balanceOf(issuerWallet));
        }

        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), totalAssets);

        // Strategy needs to approve the token to pull assets
        vm.prank(address(strategy));
        usdc.approve(address(directManagedRWA), totalAssets);

        // Execute batch redemption
        vm.prank(address(strategy));
        uint256[] memory assets = directManagedRWA.batchRedeemShares(shares, recipients, owners, minAssets);

        // Verify results
        assertEq(assets.length, 3);
        for (uint256 i = 0; i < assets.length; i++) {
            assertEq(assets[i], minAssets[i]);
        }

        assertEq(directManagedRWA.balanceOf(alice), 0);
        assertEq(directManagedRWA.balanceOf(bob), 0);
    }

    function test_BatchRedeemShares_RevertInvalidArrayLengths() public {
        uint256[] memory shares = new uint256[](2);
        address[] memory recipients = new address[](3); // Different length
        address[] memory owners = new address[](2);
        uint256[] memory minAssets = new uint256[](2);

        vm.expectRevert(DirectDepositRWA.InvalidArrayLengths.selector);
        vm.prank(address(strategy));
        directManagedRWA.batchRedeemShares(shares, recipients, owners, minAssets);
    }

    function test_BatchRedeemShares_RevertInsufficientAssets() public {
        // Setup shares
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32 depositId = directManagedRWA.getUserPendingDeposits(alice)[0];
        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(depositId);

        uint256[] memory shares = new uint256[](1);
        shares[0] = directManagedRWA.balanceOf(alice);

        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        address[] memory owners = new address[](1);
        owners[0] = alice;

        uint256[] memory minAssets = new uint256[](1);
        minAssets[0] = directManagedRWA.previewRedeem(shares[0]) + 1; // Too high

        vm.prank(alice);
        directManagedRWA.approve(address(strategy), shares[0]);

        vm.expectRevert(DirectManagedRWA.InsufficientOutputAssets.selector);
        vm.prank(address(strategy));
        directManagedRWA.batchRedeemShares(shares, recipients, owners, minAssets);
    }

    function test_BatchRedeemShares_WithHooks() public {
        // Setup shares
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);
        vm.prank(bob);
        directManagedRWA.deposit(DEPOSIT_AMOUNT * 2, bob);

        bytes32[] memory depositIds = new bytes32[](2);
        depositIds[0] = directManagedRWA.getUserPendingDeposits(alice)[0];
        depositIds[1] = directManagedRWA.getUserPendingDeposits(bob)[0];

        vm.prank(address(strategy));
        directManagedRWA.batchMintSharesForDeposit(depositIds);

        // Add a passing hook for withdrawals
        MockHook passingHook = new MockHook(true, "");
        vm.prank(address(strategy));
        directManagedRWA.addOperationHook(OP_WITHDRAW, address(passingHook));

        // Prepare batch redemption
        uint256[] memory shares = new uint256[](2);
        shares[0] = directManagedRWA.balanceOf(alice);
        shares[1] = directManagedRWA.balanceOf(bob);

        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        address[] memory owners = new address[](2);
        owners[0] = alice;
        owners[1] = bob;

        uint256[] memory minAssets = new uint256[](2);
        minAssets[0] = directManagedRWA.previewRedeem(shares[0]);
        minAssets[1] = directManagedRWA.previewRedeem(shares[1]);

        // Approve
        vm.prank(alice);
        directManagedRWA.approve(address(strategy), shares[0]);
        vm.prank(bob);
        directManagedRWA.approve(address(strategy), shares[1]);

        // Transfer assets to strategy
        uint256 totalAssets = minAssets[0] + minAssets[1];
        if (usdc.balanceOf(issuerWallet) < totalAssets) {
            usdc.mint(issuerWallet, totalAssets - usdc.balanceOf(issuerWallet));
        }
        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), totalAssets);
        vm.prank(address(strategy));
        usdc.approve(address(directManagedRWA), totalAssets);

        // Execute batch with hooks
        vm.prank(address(strategy));
        directManagedRWA.batchRedeemShares(shares, recipients, owners, minAssets);

        // Verify hook was called by checking lastExecutedBlock
        assertEq(directManagedRWA.lastExecutedBlock(OP_WITHDRAW), block.number);
    }

    function test_BatchRedeemShares_RevertWhenHookFails() public {
        // Setup shares
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32 depositId = directManagedRWA.getUserPendingDeposits(alice)[0];
        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(depositId);

        // Add rejecting hook for withdrawals
        MockHook rejectingHook = new MockHook(false, "Withdrawal rejected by hook");
        vm.prank(address(strategy));
        directManagedRWA.addOperationHook(OP_WITHDRAW, address(rejectingHook));

        // Prepare batch
        uint256[] memory shares = new uint256[](1);
        shares[0] = directManagedRWA.balanceOf(alice);

        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        address[] memory owners = new address[](1);
        owners[0] = alice;

        uint256[] memory minAssets = new uint256[](1);
        minAssets[0] = directManagedRWA.previewRedeem(shares[0]);

        vm.prank(alice);
        directManagedRWA.approve(address(strategy), shares[0]);

        // Transfer assets to strategy
        if (usdc.balanceOf(issuerWallet) < minAssets[0]) {
            usdc.mint(issuerWallet, minAssets[0] - usdc.balanceOf(issuerWallet));
        }
        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), minAssets[0]);
        vm.prank(address(strategy));
        usdc.approve(address(directManagedRWA), minAssets[0]);

        // Should revert due to hook rejection
        vm.expectRevert(abi.encodeWithSelector(tRWA.HookCheckFailed.selector, "Withdrawal rejected by hook"));
        vm.prank(address(strategy));
        directManagedRWA.batchRedeemShares(shares, recipients, owners, minAssets);
    }

    /*//////////////////////////////////////////////////////////////
                    ERC4626 OVERRIDE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Withdraw_RevertUseRedeem() public {
        vm.expectRevert(DirectManagedRWA.UseRedeem.selector);
        vm.prank(address(strategy));
        directManagedRWA.withdraw(100, alice, alice);
    }

    function test_Redeem_StandardVersion_Success() public {
        // Setup shares
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32 depositId = directManagedRWA.getUserPendingDeposits(alice)[0];
        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(depositId);

        uint256 shares = directManagedRWA.balanceOf(alice);
        uint256 expectedAssets = directManagedRWA.previewRedeem(shares);

        vm.prank(alice);
        directManagedRWA.approve(address(strategy), shares);

        // Ensure issuer wallet has enough balance
        if (usdc.balanceOf(issuerWallet) < expectedAssets) {
            usdc.mint(issuerWallet, expectedAssets - usdc.balanceOf(issuerWallet));
        }

        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), expectedAssets);

        // Strategy needs to approve the token to pull assets
        vm.prank(address(strategy));
        usdc.approve(address(directManagedRWA), expectedAssets);

        vm.prank(address(strategy));
        uint256 assets = directManagedRWA.redeem(shares, alice, alice);

        assertEq(assets, expectedAssets);
        assertEq(directManagedRWA.balanceOf(alice), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetUserPendingDeposits_FiltersByState() public {
        // Create multiple deposits
        vm.startPrank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();

        bytes32[] memory allDeposits = directManagedRWA.getUserPendingDeposits(alice);
        assertEq(allDeposits.length, 3);

        // Accept one deposit
        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(allDeposits[0]);

        // Refund another
        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), DEPOSIT_AMOUNT);
        vm.prank(address(strategy));
        directManagedRWA.refundDeposit(allDeposits[1]);

        // Check pending deposits
        bytes32[] memory pendingDeposits = directManagedRWA.getUserPendingDeposits(alice);
        assertEq(pendingDeposits.length, 1);
        assertEq(pendingDeposits[0], allDeposits[2]);
    }

    function test_GetDepositDetails_NonExistent() public {
        (address depositor, address recipient, uint256 amount, uint8 state) =
            directManagedRWA.getDepositDetails(bytes32(0));

        assertEq(depositor, address(0));
        assertEq(recipient, address(0));
        assertEq(amount, 0);
        assertEq(state, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASES & FUZZING
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Deposit_VariousAmounts(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 1000000e6);

        usdc.mint(alice, amount);

        uint256 issuerBalanceBefore = usdc.balanceOf(issuerWallet);

        vm.prank(alice);
        directManagedRWA.deposit(amount, alice);

        assertEq(directManagedRWA.totalPendingAssets(), amount);
        assertEq(usdc.balanceOf(issuerWallet), issuerBalanceBefore + amount);
    }

    function testFuzz_BatchOperations_LargeArrays(uint8 count) public {
        vm.assume(count > 0 && count <= 100);

        // Create many deposits
        bytes32[] memory depositIds = new bytes32[](count);
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < count; i++) {
            uint256 amount = (i + 1) * 1e6;
            totalAmount += amount;

            address user = i % 2 == 0 ? alice : bob;
            usdc.mint(user, amount);

            vm.prank(user);
            directManagedRWA.deposit(amount, user);

            bytes32[] memory userDeposits = directManagedRWA.getUserPendingDeposits(user);
            depositIds[i] = userDeposits[userDeposits.length - 1];
        }

        // Batch mint all
        vm.prank(address(strategy));
        directManagedRWA.batchMintSharesForDeposit(depositIds);

        assertEq(directManagedRWA.totalPendingAssets(), 0);
        assertGt(directManagedRWA.totalSupply(), 0);
    }

    function test_SequenceNumberUniqueness() public {
        // Create deposits with same parameters but different sequence numbers
        uint256 amount = DEPOSIT_AMOUNT;

        vm.startPrank(alice);
        directManagedRWA.deposit(amount, alice);
        directManagedRWA.deposit(amount, alice);
        vm.stopPrank();

        bytes32[] memory deposits = directManagedRWA.getUserPendingDeposits(alice);
        assertEq(deposits.length, 2);
        assertTrue(deposits[0] != deposits[1]); // Different IDs despite same parameters
    }

    /*//////////////////////////////////////////////////////////////
                    ADDITIONAL BRANCH COVERAGE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_BatchRedeemShares_RevertExceedsMaxInBatch() public {
        // Setup shares for alice and bob
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);
        vm.prank(bob);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, bob);

        bytes32[] memory depositIds = new bytes32[](2);
        depositIds[0] = directManagedRWA.getUserPendingDeposits(alice)[0];
        depositIds[1] = directManagedRWA.getUserPendingDeposits(bob)[0];

        vm.prank(address(strategy));
        directManagedRWA.batchMintSharesForDeposit(depositIds);

        uint256 aliceShares = directManagedRWA.balanceOf(alice);
        uint256 bobShares = directManagedRWA.balanceOf(bob);

        // Try to redeem more shares than Bob has
        uint256[] memory shares = new uint256[](2);
        shares[0] = aliceShares;
        shares[1] = bobShares + 1; // This exceeds Bob's balance

        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        address[] memory owners = new address[](2);
        owners[0] = alice;
        owners[1] = bob;

        uint256[] memory minAssets = new uint256[](2);
        minAssets[0] = 0;
        minAssets[1] = 0;

        vm.expectRevert(ERC4626.RedeemMoreThanMax.selector);
        vm.prank(address(strategy));
        directManagedRWA.batchRedeemShares(shares, recipients, owners, minAssets);
    }

    function test_Redeem_StandardVersion_RevertExceedsMax() public {
        // Setup shares
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32 depositId = directManagedRWA.getUserPendingDeposits(alice)[0];
        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(depositId);

        uint256 shares = directManagedRWA.balanceOf(alice);

        // Try to redeem more shares than alice has
        uint256 excessShares = shares + 1;

        vm.expectRevert(ERC4626.RedeemMoreThanMax.selector);
        vm.prank(address(strategy));
        directManagedRWA.redeem(excessShares, alice, alice);
    }

    function test_BatchRedeemShares_WithEmptyHooks() public {
        // This tests the branch where opHooks.length == 0
        // Setup shares
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32 depositId = directManagedRWA.getUserPendingDeposits(alice)[0];
        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(depositId);

        uint256[] memory shares = new uint256[](1);
        shares[0] = directManagedRWA.balanceOf(alice);

        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        address[] memory owners = new address[](1);
        owners[0] = alice;

        uint256[] memory minAssets = new uint256[](1);
        minAssets[0] = directManagedRWA.previewRedeem(shares[0]);

        vm.prank(alice);
        directManagedRWA.approve(address(strategy), shares[0]);

        // Ensure issuer wallet has enough balance
        if (usdc.balanceOf(issuerWallet) < minAssets[0]) {
            usdc.mint(issuerWallet, minAssets[0] - usdc.balanceOf(issuerWallet));
        }

        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), minAssets[0]);

        vm.prank(address(strategy));
        usdc.approve(address(directManagedRWA), minAssets[0]);

        // Execute batch redemption without any hooks
        vm.prank(address(strategy));
        uint256[] memory assets = directManagedRWA.batchRedeemShares(shares, recipients, owners, minAssets);

        assertEq(assets[0], minAssets[0]);
        assertEq(directManagedRWA.balanceOf(alice), 0);
    }

    function test_BatchRedeemShares_MultipleUsersWithDifferentApprovals() public {
        // This tests mixed approval scenarios in batch operations
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);
        vm.prank(bob);
        directManagedRWA.deposit(DEPOSIT_AMOUNT * 2, bob);
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32[] memory depositIds = new bytes32[](3);
        depositIds[0] = directManagedRWA.getUserPendingDeposits(alice)[0];
        depositIds[1] = directManagedRWA.getUserPendingDeposits(bob)[0];
        depositIds[2] = directManagedRWA.getUserPendingDeposits(alice)[1];

        vm.prank(address(strategy));
        directManagedRWA.batchMintSharesForDeposit(depositIds);

        // Alice approves half her balance, Bob approves all
        uint256 aliceTotal = directManagedRWA.balanceOf(alice);
        uint256 bobTotal = directManagedRWA.balanceOf(bob);

        vm.prank(alice);
        directManagedRWA.approve(address(strategy), aliceTotal / 2);
        vm.prank(bob);
        directManagedRWA.approve(address(strategy), bobTotal);

        // Try to redeem: alice half (within approval), bob all, alice remaining (exceeds approval)
        uint256[] memory shares = new uint256[](3);
        shares[0] = aliceTotal / 2; // OK
        shares[1] = bobTotal; // OK
        shares[2] = aliceTotal / 2 + 1; // Exceeds approval

        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = alice;

        address[] memory owners = new address[](3);
        owners[0] = alice;
        owners[1] = bob;
        owners[2] = alice;

        uint256[] memory minAssets = new uint256[](3);
        minAssets[0] = 0;
        minAssets[1] = 0;
        minAssets[2] = 0;

        // Should revert because third redemption exceeds alice's approval
        vm.expectRevert();
        vm.prank(address(strategy));
        directManagedRWA.batchRedeemShares(shares, recipients, owners, minAssets);
    }

    function test_Mint_CreatesValidDeposit() public {
        // Mint should create a deposit just like deposit() does
        uint256 shares = 1000e18; // 1000 shares
        uint256 assets = directManagedRWA.previewMint(shares);

        // Approve the required assets
        usdc.mint(alice, assets);
        vm.prank(alice);
        usdc.approve(address(directManagedRWA), assets);

        vm.prank(alice);
        directManagedRWA.mint(shares, alice);

        // Should have created a pending deposit
        bytes32[] memory deposits = directManagedRWA.getUserPendingDeposits(alice);
        assertEq(deposits.length, 1);
        assertEq(directManagedRWA.totalPendingAssets(), assets);
    }

    function test_BatchRedeemShares_SingleItemBatch() public {
        // Test edge case of single item batch to ensure loop logic is correct
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32 depositId = directManagedRWA.getUserPendingDeposits(alice)[0];
        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(depositId);

        uint256 shares = directManagedRWA.balanceOf(alice);

        uint256[] memory sharesArray = new uint256[](1);
        sharesArray[0] = shares;

        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        address[] memory owners = new address[](1);
        owners[0] = alice;

        uint256[] memory minAssets = new uint256[](1);
        minAssets[0] = directManagedRWA.previewRedeem(shares);

        vm.prank(alice);
        directManagedRWA.approve(address(strategy), shares);

        // Ensure issuer wallet has enough balance
        if (usdc.balanceOf(issuerWallet) < minAssets[0]) {
            usdc.mint(issuerWallet, minAssets[0] - usdc.balanceOf(issuerWallet));
        }

        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), minAssets[0]);

        vm.prank(address(strategy));
        usdc.approve(address(directManagedRWA), minAssets[0]);

        vm.prank(address(strategy));
        uint256[] memory assets = directManagedRWA.batchRedeemShares(sharesArray, recipients, owners, minAssets);

        assertEq(assets.length, 1);
        assertEq(assets[0], minAssets[0]);
        assertEq(directManagedRWA.balanceOf(alice), 0);
    }

    function test_Redeem_WithMinAssets_EdgeCaseExactAmount() public {
        // Test edge case where assets == minAssets (boundary condition)
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32 depositId = directManagedRWA.getUserPendingDeposits(alice)[0];
        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(depositId);

        uint256 shares = directManagedRWA.balanceOf(alice);
        uint256 expectedAssets = directManagedRWA.previewRedeem(shares);

        vm.prank(alice);
        directManagedRWA.approve(address(strategy), shares);

        // Ensure issuer wallet has enough balance
        if (usdc.balanceOf(issuerWallet) < expectedAssets) {
            usdc.mint(issuerWallet, expectedAssets - usdc.balanceOf(issuerWallet));
        }

        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), expectedAssets);

        vm.prank(address(strategy));
        usdc.approve(address(directManagedRWA), expectedAssets);

        // Use exact expected assets as minAssets (boundary test)
        vm.prank(address(strategy));
        uint256 assets = directManagedRWA.redeem(shares, alice, alice, expectedAssets);

        assertEq(assets, expectedAssets);
        assertEq(directManagedRWA.balanceOf(alice), 0);
    }

    function test_BatchRedeemShares_ZeroShares() public {
        // Test edge case with zero shares
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32 depositId = directManagedRWA.getUserPendingDeposits(alice)[0];
        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(depositId);

        uint256[] memory shares = new uint256[](2);
        shares[0] = 0; // Zero shares
        shares[1] = directManagedRWA.balanceOf(alice);

        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = alice;

        address[] memory owners = new address[](2);
        owners[0] = alice;
        owners[1] = alice;

        uint256[] memory minAssets = new uint256[](2);
        minAssets[0] = 0;
        minAssets[1] = directManagedRWA.previewRedeem(shares[1]);

        vm.prank(alice);
        directManagedRWA.approve(address(strategy), type(uint256).max);

        // Ensure issuer wallet has enough balance
        if (usdc.balanceOf(issuerWallet) < minAssets[1]) {
            usdc.mint(issuerWallet, minAssets[1] - usdc.balanceOf(issuerWallet));
        }

        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), minAssets[1]);

        vm.prank(address(strategy));
        usdc.approve(address(directManagedRWA), minAssets[1]);

        vm.prank(address(strategy));
        uint256[] memory assets = directManagedRWA.batchRedeemShares(shares, recipients, owners, minAssets);

        assertEq(assets[0], 0);
        assertEq(assets[1], minAssets[1]);
    }

    function test_Redeem_WithMinAssets_ZeroShares() public {
        // Test redeem with zero shares - this covers the branch where shares <= maxRedeem(owner)
        vm.prank(address(strategy));
        uint256 assets = directManagedRWA.redeem(0, alice, alice, 0);

        assertEq(assets, 0);
    }

    function test_Withdraw_DifferentParams() public {
        // Test withdraw with different parameters to ensure full coverage
        vm.expectRevert(DirectManagedRWA.UseRedeem.selector);
        vm.prank(address(strategy));
        directManagedRWA.withdraw(500, bob, charlie);
    }

    function test_Redeem_WithHooks() public {
        // Setup shares
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32 depositId = directManagedRWA.getUserPendingDeposits(alice)[0];
        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(depositId);

        // Add a passing hook for withdrawals
        MockHook passingHook = new MockHook(true, "");
        vm.prank(address(strategy));
        directManagedRWA.addOperationHook(OP_WITHDRAW, address(passingHook));

        uint256 shares = directManagedRWA.balanceOf(alice) / 2;
        uint256 expectedAssets = directManagedRWA.previewRedeem(shares);

        vm.prank(alice);
        directManagedRWA.approve(address(strategy), shares);

        // Transfer assets
        if (usdc.balanceOf(issuerWallet) < expectedAssets) {
            usdc.mint(issuerWallet, expectedAssets - usdc.balanceOf(issuerWallet));
        }
        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), expectedAssets);
        vm.prank(address(strategy));
        usdc.approve(address(directManagedRWA), expectedAssets);

        // Redeem with hook - standard version
        vm.prank(address(strategy));
        uint256 assets = directManagedRWA.redeem(shares, alice, alice);

        assertEq(assets, expectedAssets);
        // Verify hook was called
        assertEq(directManagedRWA.lastExecutedBlock(OP_WITHDRAW), block.number);
    }

    function test_Redeem_WithMinAssets_ValidShares() public {
        // This test covers the branch where shares <= maxRedeem(owner) in the minAssets version
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);

        bytes32 depositId = directManagedRWA.getUserPendingDeposits(alice)[0];
        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(depositId);

        uint256 shares = directManagedRWA.balanceOf(alice) / 2; // Use only half
        uint256 expectedAssets = directManagedRWA.previewRedeem(shares);

        // Alice approves strategy to spend her shares
        vm.prank(alice);
        directManagedRWA.approve(address(strategy), shares);

        // Transfer assets to strategy for withdrawal
        if (usdc.balanceOf(issuerWallet) < expectedAssets) {
            usdc.mint(issuerWallet, expectedAssets - usdc.balanceOf(issuerWallet));
        }
        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), expectedAssets);

        // Strategy needs to approve the token to pull assets
        vm.prank(address(strategy));
        usdc.approve(address(directManagedRWA), expectedAssets);

        // Redeem with valid shares (should pass the check)
        vm.prank(address(strategy));
        uint256 assets = directManagedRWA.redeem(shares, alice, alice, expectedAssets);

        assertEq(assets, expectedAssets);
    }

    function test_BatchRedeemShares_ValidSharesWithHooks() public {
        // This test covers both the shares[i] <= maxRedeem check and hook execution
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT * 2, alice);

        bytes32 depositId = directManagedRWA.getUserPendingDeposits(alice)[0];
        vm.prank(address(strategy));
        directManagedRWA.mintSharesForDeposit(depositId);

        // Add multiple hooks
        MockHook hook1 = new MockHook(true, "");
        MockHook hook2 = new MockHook(true, "");
        vm.startPrank(address(strategy));
        directManagedRWA.addOperationHook(OP_WITHDRAW, address(hook1));
        directManagedRWA.addOperationHook(OP_WITHDRAW, address(hook2));
        vm.stopPrank();

        // Prepare valid redemption (shares < balance)
        uint256[] memory shares = new uint256[](1);
        shares[0] = directManagedRWA.balanceOf(alice) / 3; // Use only 1/3

        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        address[] memory owners = new address[](1);
        owners[0] = alice;

        uint256[] memory minAssets = new uint256[](1);
        minAssets[0] = directManagedRWA.previewRedeem(shares[0]);

        // Approve exactly what's needed
        vm.prank(alice);
        directManagedRWA.approve(address(strategy), shares[0]);

        // Transfer assets
        if (usdc.balanceOf(issuerWallet) < minAssets[0]) {
            usdc.mint(issuerWallet, minAssets[0] - usdc.balanceOf(issuerWallet));
        }
        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), minAssets[0]);
        vm.prank(address(strategy));
        usdc.approve(address(directManagedRWA), minAssets[0]);

        // Execute - should pass all checks and execute hooks
        vm.prank(address(strategy));
        directManagedRWA.batchRedeemShares(shares, recipients, owners, minAssets);

        // Verify hooks were executed
        assertEq(directManagedRWA.lastExecutedBlock(OP_WITHDRAW), block.number);
    }

    function test_Deposit_ZeroAmount() public {
        // Test deposit with zero amount (should succeed with no effect)
        vm.prank(alice);
        directManagedRWA.deposit(0, alice);

        assertEq(directManagedRWA.getUserPendingDeposits(alice).length, 1);
        assertEq(directManagedRWA.totalPendingAssets(), 0);
    }
}
