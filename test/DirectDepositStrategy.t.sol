// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {DirectDepositStrategy} from "../src/strategy/DirectDepositStrategy.sol";
import {DirectDepositRWA} from "../src/token/DirectDepositRWA.sol";
import {IDirectDepositStrategy} from "../src/strategy/IDirectDepositStrategy.sol";
import {IStrategy} from "../src/strategy/IStrategy.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {Registry} from "../src/registry/Registry.sol";
import {Conduit} from "../src/conduit/Conduit.sol";
import {MockConduitForDirectDeposit} from "../src/mocks/MockConduitForDirectDeposit.sol";
import {MockReporter} from "../src/mocks/MockReporter.sol";

/**
 * @title DirectDepositStrategyTest
 * @notice Comprehensive tests for DirectDepositStrategy contract
 */
contract DirectDepositStrategyTest is BaseFountfiTest {
    DirectDepositStrategy public strategy;
    DirectDepositRWA public token;
    RoleManager public roleManager;
    MockConduitForDirectDeposit public mockConduit;
    MockReporter public reporter;
    
    address public issuerWallet;
    address public newIssuerWallet;
    
    // Test constants
    uint256 constant INITIAL_PRICE = 1e18; // 1:1 initial price
    
    function setUp() public override {
        super.setUp();
        
        issuerWallet = makeAddr("issuerWallet");
        newIssuerWallet = makeAddr("newIssuerWallet");
        
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
        
        // Deploy reporter
        reporter = new MockReporter(INITIAL_PRICE);
        
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
        
        // Approve USDC for test users to mock conduit
        vm.prank(alice);
        usdc.approve(address(mockConduit), type(uint256).max);
        
        vm.prank(bob);
        usdc.approve(address(mockConduit), type(uint256).max);
    }
    
    function test_Initialization() public view {
        // Check base strategy initialization
        assertEq(strategy.registry(), address(registry), "Registry should be set");
        assertEq(strategy.manager(), manager, "Manager should be set");
        assertEq(strategy.asset(), address(usdc), "Asset should be USDC");
        assertEq(strategy.sToken(), address(token), "Token should be set");
        
        // Check reporter initialization
        assertEq(address(strategy.reporter()), address(reporter), "Reporter should be set");
        
        // Check issuer wallet
        assertEq(strategy.issuerWallet(), issuerWallet, "Issuer wallet should be set");
        
        // Check token is DirectDepositRWA
        assertEq(token.name(), "Direct Deposit RWA", "Token name should match");
        assertEq(token.symbol(), "ddRWA", "Token symbol should match");
        assertEq(address(token.strategy()), address(strategy), "Token strategy should match");
    }
    
    function test_SetIssuerWallet() public {
        // Manager sets new issuer wallet
        vm.prank(manager);
        strategy.setIssuerWallet(newIssuerWallet);
        
        assertEq(strategy.issuerWallet(), newIssuerWallet, "Issuer wallet should be updated");
    }
    
    function test_SetIssuerWalletEmitsEvent() public {
        vm.prank(manager);
        vm.expectEmit(true, true, false, true);
        emit IDirectDepositStrategy.SetIssuerWallet(issuerWallet, newIssuerWallet);
        strategy.setIssuerWallet(newIssuerWallet);
    }
    
    function test_RevertSetIssuerWalletZeroAddress() public {
        vm.prank(manager);
        vm.expectRevert(IDirectDepositStrategy.InvalidIssuerWallet.selector);
        strategy.setIssuerWallet(address(0));
    }
    
    function test_RevertSetIssuerWalletNotManager() public {
        vm.prank(alice);
        vm.expectRevert(IStrategy.Unauthorized.selector);
        strategy.setIssuerWallet(newIssuerWallet);
    }
    
    function test_InitializeWithZeroIssuerWallet() public {
        // Deploy new implementation
        DirectDepositStrategy newImpl = new DirectDepositStrategy();
        
        // Try to initialize with zero issuer wallet
        bytes memory badInitData = abi.encode(address(reporter), address(0));
        
        vm.expectRevert(IDirectDepositStrategy.InvalidIssuerWallet.selector);
        newImpl.initialize(
            "Test Token",
            "TEST",
            address(roleManager),
            manager,
            address(usdc),
            6,
            badInitData
        );
    }
    
    function test_BatchMintSharesIntegration() public {
        // Setup: Alice and Bob make deposits
        vm.prank(alice);
        usdc.approve(address(token), type(uint256).max);
        vm.prank(alice);
        token.deposit(1000 * 10**6, alice);
        
        vm.prank(bob);
        usdc.approve(address(token), type(uint256).max);
        vm.prank(bob);
        token.deposit(500 * 10**6, bob);
        
        // Get deposit IDs
        bytes32[] memory aliceDeposits = token.getUserPendingDeposits(alice);
        bytes32[] memory bobDeposits = token.getUserPendingDeposits(bob);
        
        bytes32[] memory depositIds = new bytes32[](2);
        depositIds[0] = aliceDeposits[0];
        depositIds[1] = bobDeposits[0];
        
        // Manager batch mints shares through strategy
        vm.prank(manager);
        strategy.batchMintShares(depositIds);
        
        // Verify shares minted
        assertGt(token.balanceOf(alice), 0, "Alice should have shares");
        assertGt(token.balanceOf(bob), 0, "Bob should have shares");
    }
    
    function test_RevertBatchMintSharesNotManager() public {
        bytes32[] memory depositIds = new bytes32[](1);
        depositIds[0] = keccak256("test");
        
        vm.prank(alice);
        vm.expectRevert(IStrategy.Unauthorized.selector);
        strategy.batchMintShares(depositIds);
    }
    
    function test_DirectDepositFlowEndToEnd() public {
        uint256 depositAmount = 1000 * 10**6; // 1000 USDC
        uint256 issuerBalanceBefore = usdc.balanceOf(issuerWallet);
        
        // Alice deposits
        vm.prank(alice);
        usdc.approve(address(token), depositAmount);
        vm.prank(alice);
        token.deposit(depositAmount, alice);
        
        // Verify funds went to issuer wallet
        assertEq(usdc.balanceOf(issuerWallet), issuerBalanceBefore + depositAmount, "Issuer should receive funds");
        
        // Get deposit ID
        bytes32[] memory deposits = token.getUserPendingDeposits(alice);
        
        // Manager accepts deposit
        vm.prank(manager);
        strategy.batchMintShares(deposits);
        
        // Verify shares minted
        assertGt(token.balanceOf(alice), 0, "Alice should have shares");
        assertEq(token.totalPendingAssets(), 0, "No pending assets should remain");
    }
    
    function test_ReporterIntegration() public {
        // Change price via reporter
        uint256 newPrice = 2e18; // 2:1 price
        reporter.setValue(newPrice);
        
        // Alice deposits
        uint256 depositAmount = 1000 * 10**6;
        vm.prank(alice);
        usdc.approve(address(token), depositAmount);
        vm.prank(alice);
        token.deposit(depositAmount, alice);
        
        // Get deposit ID and mint shares
        bytes32[] memory deposits = token.getUserPendingDeposits(alice);
        vm.prank(manager);
        strategy.batchMintShares(deposits);
        
        // When vault is empty, first depositor gets 1:1 conversion with decimal adjustment
        // depositAmount is 1000 * 10^6 (USDC with 6 decimals)
        // shares are 18 decimals, so we get 1000 * 10^18
        uint256 expectedShares = 1000 * 10**18; // 1000 shares with 18 decimals
        assertEq(token.balanceOf(alice), expectedShares, "First deposit should convert with decimal adjustment");
    }
    
    function test_MultipleIssuerWalletChanges() public {
        address wallet1 = makeAddr("wallet1");
        address wallet2 = makeAddr("wallet2");
        address wallet3 = makeAddr("wallet3");
        
        // Change issuer wallet multiple times
        vm.startPrank(manager);
        
        strategy.setIssuerWallet(wallet1);
        assertEq(strategy.issuerWallet(), wallet1, "Should be wallet1");
        
        strategy.setIssuerWallet(wallet2);
        assertEq(strategy.issuerWallet(), wallet2, "Should be wallet2");
        
        strategy.setIssuerWallet(wallet3);
        assertEq(strategy.issuerWallet(), wallet3, "Should be wallet3");
        
        vm.stopPrank();
        
        // Verify deposits go to latest wallet
        vm.prank(alice);
        usdc.approve(address(token), 1000 * 10**6);
        vm.prank(alice);
        token.deposit(1000 * 10**6, alice);
        
        assertEq(usdc.balanceOf(wallet3), 1000 * 10**6, "Funds should go to latest wallet");
    }
    
    
    function test_StrategyTokenDeployment() public {
        // Verify the deployed token is DirectDepositRWA type
        // Try to call DirectDepositRWA specific function
        vm.prank(alice);
        usdc.approve(address(token), 1000 * 10**6);
        vm.prank(alice);
        token.deposit(1000 * 10**6, alice);
        
        // This should work because it's a DirectDepositRWA
        bytes32[] memory deposits = token.getUserPendingDeposits(alice);
        assertEq(deposits.length, 1, "Should have pending deposit");
        
        // Get deposit details - this is DirectDepositRWA specific
        (address depositor, , , ) = token.getDepositDetails(deposits[0]);
        assertEq(depositor, alice, "Should track depositor");
    }
}