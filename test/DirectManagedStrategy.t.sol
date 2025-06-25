// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {DirectManagedRWA} from "../src/token/DirectManagedRWA.sol";
import {DirectManagedStrategy} from "../src/strategy/DirectManagedStrategy.sol";
import {ManagedWithdrawReportedStrategy} from "../src/strategy/ManagedWithdrawRWAStrategy.sol";
import {IDirectDepositStrategy} from "../src/strategy/IDirectDepositStrategy.sol";
import {MockConduitForDirectDeposit} from "../src/mocks/MockConduitForDirectDeposit.sol";
import {MockReporter} from "../src/mocks/MockReporter.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";

contract DirectManagedStrategyTest is BaseFountfiTest {
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
    
    // EIP-712 constants
    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    
    bytes32 private constant WITHDRAWAL_REQUEST_TYPEHASH = keccak256(
        "WithdrawalRequest(address owner,address to,uint256 shares,uint256 minAssets,uint96 nonce,uint96 expirationTime)"
    );
    
    // Test keys
    uint256 private alicePrivateKey = 0xA11CE;
    uint256 private bobPrivateKey = 0xB0B;
    
    // Events
    event SetIssuerWallet(address indexed oldWallet, address indexed newWallet);
    event WithdrawalNonceUsed(address indexed owner, uint96 nonce);

    function setUp() public override {
        super.setUp();

        // Set alice and bob addresses to match private keys
        alice = vm.addr(alicePrivateKey);
        bob = vm.addr(bobPrivateKey);

        // Deploy mocks
        conduitForDirectDeposit = new MockConduitForDirectDeposit();
        reporter = new MockReporter(INITIAL_PRICE);

        // Mock the registry.conduit() call to return our mock
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
            address(roleManager),
            abi.encodeWithSelector(roleManager.registry.selector),
            abi.encode(address(registry))
        );

        // Deploy strategy through factory
        strategy = new DirectManagedStrategy();
        
        // Initialize strategy with issuer wallet
        strategy.initializeWithIssuerWallet(
            "DirectManaged RWA Token",
            "dmRWA",
            address(roleManager),
            manager,
            address(usdc),
            USDC_DECIMALS,
            address(reporter),
            issuerWallet
        );
        
        directManagedRWA = DirectManagedRWA(strategy.sToken());

        // Setup initial balances and approvals
        usdc.mint(address(this), 1000000e6);
        usdc.mint(alice, 1000000e6);
        usdc.mint(bob, 1000000e6);
        usdc.mint(address(strategy), 1000000e6); // For redemptions
        usdc.mint(issuerWallet, 10000000e6); // Issuer wallet needs lots of funds
        
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
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InitializeWithIssuerWallet_Success() public {
        DirectManagedStrategy newStrategy = new DirectManagedStrategy();
        
        vm.expectEmit(true, true, true, true);
        emit SetIssuerWallet(address(0), issuerWallet);
        
        newStrategy.initializeWithIssuerWallet(
            "Test Token",
            "TEST",
            owner,  // Using owner as roleManager for tests
            manager,
            address(usdc),
            USDC_DECIMALS,
            address(reporter),
            issuerWallet
        );
        
        assertEq(newStrategy.issuerWallet(), issuerWallet);
        assertEq(newStrategy.manager(), manager);
        assertEq(newStrategy.asset(), address(usdc));
        assertTrue(newStrategy.sToken() != address(0));
        
        // Verify DirectManagedRWA was deployed
        DirectManagedRWA token = DirectManagedRWA(newStrategy.sToken());
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.strategy(), address(newStrategy));
    }

    function test_InitializeWithIssuerWallet_RevertZeroAddress() public {
        DirectManagedStrategy newStrategy = new DirectManagedStrategy();
        
        vm.expectRevert(IDirectDepositStrategy.InvalidIssuerWallet.selector);
        newStrategy.initializeWithIssuerWallet(
            "Test Token",
            "TEST",
            owner,  // Using owner as roleManager for tests
            manager,
            address(usdc),
            USDC_DECIMALS,
            address(reporter),
            address(0) // Zero issuer wallet
        );
    }

    function test_InitializeWithIssuerWallet_RevertAlreadyInitialized() public {
        DirectManagedStrategy newStrategy = new DirectManagedStrategy();
        
        newStrategy.initializeWithIssuerWallet(
            "Test Token",
            "TEST",
            owner,  // Using owner as roleManager for tests
            manager,
            address(usdc),
            USDC_DECIMALS,
            address(reporter),
            issuerWallet
        );
        
        // Try to initialize again
        vm.expectRevert();
        newStrategy.initializeWithIssuerWallet(
            "Test Token 2",
            "TEST2",
            owner,  // Using owner as roleManager for tests
            manager,
            address(usdc),
            USDC_DECIMALS,
            address(reporter),
            issuerWallet
        );
    }

    /*//////////////////////////////////////////////////////////////
                    ISSUER WALLET MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetIssuerWallet_Success() public {
        address newWallet = makeAddr("newIssuerWallet");
        
        vm.expectEmit(true, true, true, true);
        emit SetIssuerWallet(issuerWallet, newWallet);
        
        vm.prank(manager);
        strategy.setIssuerWallet(newWallet);
        
        assertEq(strategy.issuerWallet(), newWallet);
    }

    function test_SetIssuerWallet_RevertNotManager() public {
        address newWallet = makeAddr("newIssuerWallet");
        
        vm.expectRevert();
        strategy.setIssuerWallet(newWallet);
    }

    function test_SetIssuerWallet_RevertZeroAddress() public {
        vm.expectRevert(IDirectDepositStrategy.InvalidIssuerWallet.selector);
        vm.prank(manager);
        strategy.setIssuerWallet(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                    BATCH MINT SHARES TESTS
    //////////////////////////////////////////////////////////////*/

    function test_BatchMintShares_Success() public {
        // Create deposits
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);
        vm.prank(bob);
        directManagedRWA.deposit(DEPOSIT_AMOUNT * 2, bob);
        
        bytes32[] memory depositIds = new bytes32[](2);
        depositIds[0] = directManagedRWA.getUserPendingDeposits(alice)[0];
        depositIds[1] = directManagedRWA.getUserPendingDeposits(bob)[0];
        
        // Batch mint through strategy
        vm.prank(manager);
        strategy.batchMintShares(depositIds);
        
        // Verify shares were minted
        assertGt(directManagedRWA.balanceOf(alice), 0);
        assertGt(directManagedRWA.balanceOf(bob), 0);
        assertEq(directManagedRWA.totalPendingAssets(), 0);
    }

    function test_BatchMintShares_RevertNotManager() public {
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);
        
        bytes32[] memory depositIds = new bytes32[](1);
        depositIds[0] = directManagedRWA.getUserPendingDeposits(alice)[0];
        
        vm.expectRevert();
        strategy.batchMintShares(depositIds);
    }

    /*//////////////////////////////////////////////////////////////
                    REDEMPTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Redeem_WithSignature_Success() public {
        // Setup: Create deposit and mint shares
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);
        
        bytes32 depositId = directManagedRWA.getUserPendingDeposits(alice)[0];
        vm.prank(manager);
        strategy.batchMintShares(_toArray(depositId));
        
        uint256 shares = directManagedRWA.balanceOf(alice);
        uint256 expectedAssets = directManagedRWA.previewRedeem(shares);
        
        // Alice approves strategy
        vm.prank(alice);
        directManagedRWA.approve(address(strategy), shares);
        
        // Create withdrawal request
        ManagedWithdrawReportedStrategy.WithdrawalRequest memory request = ManagedWithdrawReportedStrategy.WithdrawalRequest({
            shares: shares,
            minAssets: expectedAssets,
            owner: alice,
            nonce: 1,
            to: alice,
            expirationTime: uint96(block.timestamp + 1 hours)
        });
        
        // Sign request
        ManagedWithdrawReportedStrategy.Signature memory sig = _signWithdrawalRequest(request, alicePrivateKey);
        
        // Ensure issuer wallet has enough balance for redemption
        if (usdc.balanceOf(issuerWallet) < expectedAssets) {
            usdc.mint(issuerWallet, expectedAssets - usdc.balanceOf(issuerWallet));
        }
        
        // Transfer assets to strategy for redemption
        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), expectedAssets);
        
        // Strategy needs to approve the token to pull assets
        vm.prank(address(strategy));
        usdc.approve(address(directManagedRWA), expectedAssets);
        
        // Execute redemption
        vm.expectEmit(true, true, true, true);
        emit WithdrawalNonceUsed(alice, 1);
        
        vm.prank(manager);
        uint256 assets = strategy.redeem(request, sig);
        
        assertEq(assets, expectedAssets);
        assertEq(directManagedRWA.balanceOf(alice), 0);
        // Alice started with 1000000e6 USDC, deposited 1000e6, and got back assets
        assertEq(usdc.balanceOf(alice), 1000000e6 - DEPOSIT_AMOUNT + assets);
        
        // Verify nonce was used
        assertTrue(strategy.usedNonces(alice, 1));
    }

    function test_Redeem_RevertExpiredRequest() public {
        _setupShares(alice, DEPOSIT_AMOUNT);
        
        ManagedWithdrawReportedStrategy.WithdrawalRequest memory request = ManagedWithdrawReportedStrategy.WithdrawalRequest({
            shares: 100,
            minAssets: 100,
            owner: alice,
            nonce: 1,
            to: alice,
            expirationTime: uint96(block.timestamp - 1) // Expired
        });
        
        ManagedWithdrawReportedStrategy.Signature memory sig = _signWithdrawalRequest(request, alicePrivateKey);
        
        vm.expectRevert(ManagedWithdrawReportedStrategy.WithdrawalRequestExpired.selector);
        vm.prank(manager);
        strategy.redeem(request, sig);
    }

    function test_Redeem_RevertNonceReuse() public {
        _setupShares(alice, DEPOSIT_AMOUNT);
        
        uint256 shares = directManagedRWA.balanceOf(alice) / 2;
        
        vm.prank(alice);
        directManagedRWA.approve(address(strategy), type(uint256).max);
        
        ManagedWithdrawReportedStrategy.WithdrawalRequest memory request = ManagedWithdrawReportedStrategy.WithdrawalRequest({
            shares: shares,
            minAssets: directManagedRWA.previewRedeem(shares),
            owner: alice,
            nonce: 1,
            to: alice,
            expirationTime: uint96(block.timestamp + 1 hours)
        });
        
        ManagedWithdrawReportedStrategy.Signature memory sig = _signWithdrawalRequest(request, alicePrivateKey);
        
        // Calculate needed assets
        uint256 neededAssets = directManagedRWA.previewRedeem(shares) * 2; // Transfer enough for both attempts
        
        // Ensure issuer wallet has enough balance for redemption
        if (usdc.balanceOf(issuerWallet) < neededAssets) {
            usdc.mint(issuerWallet, neededAssets - usdc.balanceOf(issuerWallet));
        }
        
        // Transfer assets to strategy for redemption
        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), neededAssets);
        
        // Strategy needs to approve the token to pull assets
        vm.prank(address(strategy));
        usdc.approve(address(directManagedRWA), type(uint256).max);
        
        // First redemption succeeds
        vm.prank(manager);
        strategy.redeem(request, sig);
        
        // Second redemption with same nonce fails
        vm.expectRevert(ManagedWithdrawReportedStrategy.WithdrawNonceReuse.selector);
        vm.prank(manager);
        strategy.redeem(request, sig);
    }

    function test_Redeem_RevertInvalidSignature() public {
        _setupShares(alice, DEPOSIT_AMOUNT);
        
        ManagedWithdrawReportedStrategy.WithdrawalRequest memory request = ManagedWithdrawReportedStrategy.WithdrawalRequest({
            shares: 100,
            minAssets: 100,
            owner: alice,
            nonce: 1,
            to: alice,
            expirationTime: uint96(block.timestamp + 1 hours)
        });
        
        // Sign with wrong key
        ManagedWithdrawReportedStrategy.Signature memory sig = _signWithdrawalRequest(request, bobPrivateKey);
        
        vm.expectRevert(ManagedWithdrawReportedStrategy.WithdrawInvalidSignature.selector);
        vm.prank(manager);
        strategy.redeem(request, sig);
    }

    function test_Redeem_RevertNotManager() public {
        ManagedWithdrawReportedStrategy.WithdrawalRequest memory request;
        ManagedWithdrawReportedStrategy.Signature memory sig;
        
        vm.expectRevert();
        strategy.redeem(request, sig);
    }

    function test_BatchRedeem_Success() public {
        // Setup shares for multiple users
        _setupShares(alice, DEPOSIT_AMOUNT);
        _setupShares(bob, DEPOSIT_AMOUNT * 2);
        
        uint256 aliceShares = directManagedRWA.balanceOf(alice);
        uint256 bobShares = directManagedRWA.balanceOf(bob);
        
        // Approve strategy
        vm.prank(alice);
        directManagedRWA.approve(address(strategy), aliceShares);
        vm.prank(bob);
        directManagedRWA.approve(address(strategy), bobShares);
        
        // Create requests
        ManagedWithdrawReportedStrategy.WithdrawalRequest[] memory requests = new ManagedWithdrawReportedStrategy.WithdrawalRequest[](2);
        requests[0] = ManagedWithdrawReportedStrategy.WithdrawalRequest({
            shares: aliceShares,
            minAssets: directManagedRWA.previewRedeem(aliceShares),
            owner: alice,
            nonce: 1,
            to: alice,
            expirationTime: uint96(block.timestamp + 1 hours)
        });
        requests[1] = ManagedWithdrawReportedStrategy.WithdrawalRequest({
            shares: bobShares,
            minAssets: directManagedRWA.previewRedeem(bobShares),
            owner: bob,
            nonce: 1,
            to: bob,
            expirationTime: uint96(block.timestamp + 1 hours)
        });
        
        // Sign requests
        ManagedWithdrawReportedStrategy.Signature[] memory signatures = new ManagedWithdrawReportedStrategy.Signature[](2);
        signatures[0] = _signWithdrawalRequest(requests[0], alicePrivateKey);
        signatures[1] = _signWithdrawalRequest(requests[1], bobPrivateKey);
        
        // Transfer assets to strategy for redemption
        uint256 totalAssets = directManagedRWA.previewRedeem(aliceShares) + directManagedRWA.previewRedeem(bobShares);
        
        // Ensure issuer wallet has enough balance for redemption
        if (usdc.balanceOf(issuerWallet) < totalAssets) {
            usdc.mint(issuerWallet, totalAssets - usdc.balanceOf(issuerWallet));
        }
        
        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), totalAssets);
        
        // Strategy needs to approve the token to pull assets
        vm.prank(address(strategy));
        usdc.approve(address(directManagedRWA), totalAssets);
        
        // Execute batch redemption
        vm.prank(manager);
        uint256[] memory assets = strategy.batchRedeem(requests, signatures);
        
        assertEq(assets.length, 2);
        assertEq(directManagedRWA.balanceOf(alice), 0);
        assertEq(directManagedRWA.balanceOf(bob), 0);
        assertTrue(strategy.usedNonces(alice, 1));
        assertTrue(strategy.usedNonces(bob, 1));
    }

    function test_BatchRedeem_RevertInvalidArrayLengths() public {
        ManagedWithdrawReportedStrategy.WithdrawalRequest[] memory requests = new ManagedWithdrawReportedStrategy.WithdrawalRequest[](2);
        ManagedWithdrawReportedStrategy.Signature[] memory signatures = new ManagedWithdrawReportedStrategy.Signature[](1); // Wrong length
        
        vm.expectRevert(ManagedWithdrawReportedStrategy.InvalidArrayLengths.selector);
        vm.prank(manager);
        strategy.batchRedeem(requests, signatures);
    }

    function test_BatchRedeem_RevertPartialFailure() public {
        _setupShares(alice, DEPOSIT_AMOUNT);
        _setupShares(bob, DEPOSIT_AMOUNT);
        
        vm.prank(alice);
        directManagedRWA.approve(address(strategy), type(uint256).max);
        vm.prank(bob);
        directManagedRWA.approve(address(strategy), type(uint256).max);
        
        ManagedWithdrawReportedStrategy.WithdrawalRequest[] memory requests = new ManagedWithdrawReportedStrategy.WithdrawalRequest[](2);
        requests[0] = ManagedWithdrawReportedStrategy.WithdrawalRequest({
            shares: 100,
            minAssets: 100,
            owner: alice,
            nonce: 1,
            to: alice,
            expirationTime: uint96(block.timestamp + 1 hours)
        });
        requests[1] = ManagedWithdrawReportedStrategy.WithdrawalRequest({
            shares: 100,
            minAssets: 100,
            owner: bob,
            nonce: 1,
            to: bob,
            expirationTime: uint96(block.timestamp - 1) // Expired
        });
        
        ManagedWithdrawReportedStrategy.Signature[] memory signatures = new ManagedWithdrawReportedStrategy.Signature[](2);
        signatures[0] = _signWithdrawalRequest(requests[0], alicePrivateKey);
        signatures[1] = _signWithdrawalRequest(requests[1], bobPrivateKey);
        
        // Transfer assets to strategy for redemption
        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), 200);
        
        // Strategy needs to approve the token to pull assets
        vm.prank(address(strategy));
        usdc.approve(address(directManagedRWA), 200);
        
        vm.expectRevert(ManagedWithdrawReportedStrategy.WithdrawalRequestExpired.selector);
        vm.prank(manager);
        strategy.batchRedeem(requests, signatures);
    }

    /*//////////////////////////////////////////////////////////////
                    EDGE CASES & INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FullLifecycle() public {
        // 1. Multiple deposits
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);
        vm.prank(bob);
        directManagedRWA.deposit(DEPOSIT_AMOUNT * 2, bob);
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);
        
        // 2. Batch mint shares
        bytes32[] memory depositIds = new bytes32[](3);
        bytes32[] memory aliceDeposits = directManagedRWA.getUserPendingDeposits(alice);
        bytes32[] memory bobDeposits = directManagedRWA.getUserPendingDeposits(bob);
        depositIds[0] = aliceDeposits[0];
        depositIds[1] = bobDeposits[0];
        depositIds[2] = aliceDeposits[1];
        
        vm.prank(manager);
        strategy.batchMintShares(depositIds);
        
        // 3. Change issuer wallet
        address newIssuerWallet = makeAddr("newIssuerWallet");
        vm.prank(manager);
        strategy.setIssuerWallet(newIssuerWallet);
        
        // 4. New deposit goes to new wallet
        vm.prank(alice);
        directManagedRWA.deposit(DEPOSIT_AMOUNT, alice);
        assertEq(usdc.balanceOf(newIssuerWallet), DEPOSIT_AMOUNT);
        
        // 5. Batch redeem with signatures
        uint256 aliceShares = directManagedRWA.balanceOf(alice) / 2;
        uint256 bobShares = directManagedRWA.balanceOf(bob);
        
        vm.prank(alice);
        directManagedRWA.approve(address(strategy), type(uint256).max);
        vm.prank(bob);
        directManagedRWA.approve(address(strategy), type(uint256).max);
        
        ManagedWithdrawReportedStrategy.WithdrawalRequest[] memory requests = new ManagedWithdrawReportedStrategy.WithdrawalRequest[](2);
        requests[0] = ManagedWithdrawReportedStrategy.WithdrawalRequest({
            shares: aliceShares,
            minAssets: directManagedRWA.previewRedeem(aliceShares),
            owner: alice,
            nonce: 1,
            to: alice,
            expirationTime: uint96(block.timestamp + 1 hours)
        });
        requests[1] = ManagedWithdrawReportedStrategy.WithdrawalRequest({
            shares: bobShares,
            minAssets: directManagedRWA.previewRedeem(bobShares),
            owner: bob,
            nonce: 1,
            to: bob,
            expirationTime: uint96(block.timestamp + 1 hours)
        });
        
        ManagedWithdrawReportedStrategy.Signature[] memory signatures = new ManagedWithdrawReportedStrategy.Signature[](2);
        signatures[0] = _signWithdrawalRequest(requests[0], alicePrivateKey);
        signatures[1] = _signWithdrawalRequest(requests[1], bobPrivateKey);
        
        // Transfer assets to strategy for redemption
        uint256 totalAssets = directManagedRWA.previewRedeem(aliceShares) + directManagedRWA.previewRedeem(bobShares);
        
        // Ensure issuer wallet has enough balance for redemption
        if (usdc.balanceOf(issuerWallet) < totalAssets) {
            usdc.mint(issuerWallet, totalAssets - usdc.balanceOf(issuerWallet));
        }
        
        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), totalAssets);
        
        // Strategy needs to approve the token to pull assets
        vm.prank(address(strategy));
        usdc.approve(address(directManagedRWA), totalAssets);
        
        vm.prank(manager);
        strategy.batchRedeem(requests, signatures);
        
        // Verify final state
        assertGt(directManagedRWA.balanceOf(alice), 0); // Alice still has some shares
        assertEq(directManagedRWA.balanceOf(bob), 0); // Bob redeemed all
        assertGt(directManagedRWA.totalSupply(), 0); // Token still has supply
    }

    function testFuzz_RedemptionNonces(uint96 nonce, uint256 shares) public {
        vm.assume(nonce > 0);
        vm.assume(shares > 0 && shares <= DEPOSIT_AMOUNT);
        
        _setupShares(alice, DEPOSIT_AMOUNT);
        
        vm.prank(alice);
        directManagedRWA.approve(address(strategy), type(uint256).max);
        
        ManagedWithdrawReportedStrategy.WithdrawalRequest memory request = ManagedWithdrawReportedStrategy.WithdrawalRequest({
            shares: shares,
            minAssets: directManagedRWA.previewRedeem(shares),
            owner: alice,
            nonce: nonce,
            to: alice,
            expirationTime: uint96(block.timestamp + 1 hours)
        });
        
        ManagedWithdrawReportedStrategy.Signature memory sig = _signWithdrawalRequest(request, alicePrivateKey);
        
        // Transfer assets to strategy for redemption
        uint256 expectedAssets = directManagedRWA.previewRedeem(shares);
        vm.prank(issuerWallet);
        usdc.transfer(address(strategy), expectedAssets);
        
        // Strategy needs to approve the token to pull assets
        vm.prank(address(strategy));
        usdc.approve(address(directManagedRWA), expectedAssets);
        
        vm.prank(manager);
        strategy.redeem(request, sig);
        
        assertTrue(strategy.usedNonces(alice, nonce));
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setupShares(address user, uint256 amount) private {
        vm.prank(user);
        directManagedRWA.deposit(amount, user);
        
        bytes32[] memory deposits = directManagedRWA.getUserPendingDeposits(user);
        
        vm.prank(manager);
        strategy.batchMintShares(deposits);
    }

    function _toArray(bytes32 value) private pure returns (bytes32[] memory) {
        bytes32[] memory array = new bytes32[](1);
        array[0] = value;
        return array;
    }

    function _signWithdrawalRequest(
        ManagedWithdrawReportedStrategy.WithdrawalRequest memory request,
        uint256 privateKey
    ) private view returns (ManagedWithdrawReportedStrategy.Signature memory) {
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
        
        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("ManagedWithdrawReportedStrategy")),
                keccak256(bytes("V1")),
                block.chainid,
                address(strategy)
            )
        );
        
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        
        return ManagedWithdrawReportedStrategy.Signature(v, r, s);
    }
}