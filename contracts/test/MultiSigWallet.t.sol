// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet public multisig;
    
    // Test addresses
    address public owner1 = address(0x1);
    address public owner2 = address(0x2);
    address public owner3 = address(0x3);
    address public owner4 = address(0x4);
    address public recipient = address(0x5);
    address public nonOwner = address(0x6);
    
    address[] public owners;
    uint256 public requiredConfirmations = 2;

    // Events
    event Deposit(address indexed sender, uint256 amount);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event RequiredConfirmationsChanged(uint256 required);

    function setUp() public {
        owners = [owner1, owner2, owner3];
        multisig = new MultiSigWallet(owners, requiredConfirmations);
    }

    // ============ CONSTRUCTOR TESTS ============

    function testConstructor() public view{
        assertTrue(multisig.isOwner(owner1));
        assertTrue(multisig.isOwner(owner2));
        assertTrue(multisig.isOwner(owner3));
        assertFalse(multisig.isOwner(nonOwner));
        assertEq(multisig.requiredConfirmations(), 2);
        assertEq(multisig.getOwners().length, 3);
        
        address[] memory returnedOwners = multisig.getOwners();
        assertEq(returnedOwners[0], owner1);
        assertEq(returnedOwners[1], owner2);
        assertEq(returnedOwners[2], owner3);
    }

    function testConstructorEmptyOwners() public {
        address[] memory emptyOwners = new address[](0);
        vm.expectRevert("Owners required");
        new MultiSigWallet(emptyOwners, 1);
    }

    function testConstructorInvalidConfirmationsZero() public {
        address[] memory testOwners = new address[](2);
        testOwners[0] = owner1;
        testOwners[1] = owner2;
        
        vm.expectRevert("Invalid required number of confirmations");
        new MultiSigWallet(testOwners, 0);
    }

    function testConstructorInvalidConfirmationsTooHigh() public {
        address[] memory testOwners = new address[](2);
        testOwners[0] = owner1;
        testOwners[1] = owner2;
        
        vm.expectRevert("Invalid required number of confirmations");
        new MultiSigWallet(testOwners, 3);
    }

    function testConstructorZeroAddressOwner() public {
        address[] memory invalidOwners = new address[](2);
        invalidOwners[0] = owner1;
        invalidOwners[1] = address(0);
        
        vm.expectRevert("Invalid owner");
        new MultiSigWallet(invalidOwners, 1);
    }

    function testConstructorDuplicateOwners() public {
        address[] memory duplicateOwners = new address[](2);
        duplicateOwners[0] = owner1;
        duplicateOwners[1] = owner1;
        
        vm.expectRevert("Owner not unique");
        new MultiSigWallet(duplicateOwners, 1);
    }

    function testConstructorSingleOwner() public {
        address[] memory singleOwner = new address[](1);
        singleOwner[0] = owner1;
        
        MultiSigWallet singleOwnerWallet = new MultiSigWallet(singleOwner, 1);
        assertTrue(singleOwnerWallet.isOwner(owner1));
        assertEq(singleOwnerWallet.requiredConfirmations(), 1);
        assertEq(singleOwnerWallet.getOwners().length, 1);
    }

    // ============ RECEIVE FUNCTION TESTS ============

    function testReceive() public {
        uint256 amount = 5 ether;
        vm.deal(nonOwner, amount);
        
        vm.prank(nonOwner);
        vm.expectEmit(true, false, false, true);
        emit Deposit(nonOwner, amount);
        (bool success,) = address(multisig).call{value: amount}("");
        
        assertTrue(success);
        assertEq(address(multisig).balance, amount);
    }

    function testReceiveMultipleDeposits() public {
        vm.deal(owner1, 10 ether);
        vm.deal(owner2, 10 ether);
        
        vm.prank(owner1);
        (bool success1,) = address(multisig).call{value: 3 ether}("");
        assertTrue(success1);
        
        vm.prank(owner2);
        (bool success2,) = address(multisig).call{value: 2 ether}("");
        assertTrue(success2);
        
        assertEq(address(multisig).balance, 5 ether);
    }

    // ============ SUBMIT TRANSACTION TESTS ============

    function testSubmitTransaction() public {
        vm.prank(owner1);
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(owner1, 0, recipient, 1 ether, "");
        multisig.submitTransaction(recipient, 1 ether, "");
        
        assertEq(multisig.getTransactionCount(), 1);
        
        (address to, uint256 value, bytes memory data, bool executed, uint256 numConfirmations) = multisig.getTransaction(0);
        assertEq(to, recipient);
        assertEq(value, 1 ether);
        assertEq(data.length, 0);
        assertFalse(executed);
        assertEq(numConfirmations, 0);
    }

    function testSubmitTransactionWithData() public {
        bytes memory testData = abi.encodeWithSignature("testFunction(uint256)", 123);
        
        vm.prank(owner2);
        multisig.submitTransaction(recipient, 0.5 ether, testData);
        
        (address to, uint256 value, bytes memory data, bool executed, uint256 numConfirmations) = multisig.getTransaction(0);
        assertEq(to, recipient);
        assertEq(value, 0.5 ether);
        assertEq(data, testData);
        assertFalse(executed);
        assertEq(numConfirmations, 0);
    }

    function testSubmitTransactionNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert("Not owner");
        multisig.submitTransaction(recipient, 1 ether, "");
    }

    function testSubmitMultipleTransactions() public {
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner2);
        multisig.submitTransaction(owner3, 2 ether, "");
        
        vm.prank(owner3);
        multisig.submitTransaction(owner1, 0.5 ether, "");
        
        assertEq(multisig.getTransactionCount(), 3);
        
        (address to1,,, bool executed1,) = multisig.getTransaction(0);
        (address to2,,, bool executed2,) = multisig.getTransaction(1);
        (address to3,,, bool executed3,) = multisig.getTransaction(2);
        
        assertEq(to1, recipient);
        assertEq(to2, owner3);
        assertEq(to3, owner1);
        assertFalse(executed1);
        assertFalse(executed2);
        assertFalse(executed3);
    }

    // ============ CONFIRM TRANSACTION TESTS ============

    function testConfirmTransaction() public {
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner2);
        vm.expectEmit(true, true, false, false);
        emit ConfirmTransaction(owner2, 0);
        multisig.confirmTransaction(0);
        
        (,,,, uint256 numConfirmations) = multisig.getTransaction(0);
        assertEq(numConfirmations, 1);
        assertTrue(multisig.isConfirmedBy(0, owner2));
        assertFalse(multisig.isConfirmedBy(0, owner1));
        assertFalse(multisig.isConfirmedBy(0, owner3));
    }

    function testConfirmTransactionNotOwner() public {
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(nonOwner);
        vm.expectRevert("Not owner");
        multisig.confirmTransaction(0);
    }

    function testConfirmTransactionAlreadyConfirmed() public {
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        vm.prank(owner2);
        vm.expectRevert("Transaction already confirmed");
        multisig.confirmTransaction(0);
    }

    function testConfirmTransactionDoesNotExist() public {
        vm.prank(owner1);
        vm.expectRevert("Transaction does not exist");
        multisig.confirmTransaction(0);
    }

    function testConfirmTransactionAlreadyExecuted() public {
        // Fund the multisig wallet
        vm.deal(address(multisig), 10 ether);
        
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        vm.prank(owner3);
        multisig.confirmTransaction(0);
        
        vm.prank(owner1);
        multisig.executeTransaction(0);
        
        vm.prank(owner1);
        vm.expectRevert("Transaction already executed");
        multisig.confirmTransaction(0);
    }

    function testConfirmTransactionMultipleOwners() public {
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        vm.prank(owner3);
        multisig.confirmTransaction(0);
        
        (,,,, uint256 numConfirmations) = multisig.getTransaction(0);
        assertEq(numConfirmations, 2);
        assertTrue(multisig.isConfirmedBy(0, owner2));
        assertTrue(multisig.isConfirmedBy(0, owner3));
        assertFalse(multisig.isConfirmedBy(0, owner1));
    }

    // ============ EXECUTE TRANSACTION TESTS ============

    function testExecuteTransaction() public {
        // Fund the multisig wallet
        vm.deal(address(multisig), 10 ether);
        
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        vm.prank(owner3);
        multisig.confirmTransaction(0);
        
        uint256 recipientBalanceBefore = recipient.balance;
        uint256 multisigBalanceBefore = address(multisig).balance;
        
        vm.prank(owner1);
        vm.expectEmit(true, true, false, false);
        emit ExecuteTransaction(owner1, 0);
        multisig.executeTransaction(0);
        
        (,,, bool executed,) = multisig.getTransaction(0);
        assertTrue(executed);
        assertEq(recipient.balance, recipientBalanceBefore + 1 ether);
        assertEq(address(multisig).balance, multisigBalanceBefore - 1 ether);
    }

    function testExecuteTransactionInsufficientConfirmations() public {
        vm.deal(address(multisig), 10 ether);
        
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        vm.prank(owner1);
        vm.expectRevert("Cannot execute transaction");
        multisig.executeTransaction(0);
    }

    function testExecuteTransactionNotOwner() public {
        vm.deal(address(multisig), 10 ether);
        
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        vm.prank(owner3);
        multisig.confirmTransaction(0);
        
        vm.prank(nonOwner);
        vm.expectRevert("Not owner");
        multisig.executeTransaction(0);
    }

    function testExecuteTransactionDoesNotExist() public {
        vm.prank(owner1);
        vm.expectRevert("Transaction does not exist");
        multisig.executeTransaction(0);
    }

    function testExecuteTransactionAlreadyExecuted() public {
        vm.deal(address(multisig), 10 ether);
        
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        vm.prank(owner3);
        multisig.confirmTransaction(0);
        
        vm.prank(owner1);
        multisig.executeTransaction(0);
        
        vm.prank(owner1);
        vm.expectRevert("Transaction already executed");
        multisig.executeTransaction(0);
    }

    function testExecuteTransactionFails() public {
        vm.deal(address(multisig), 10 ether);
        
        // Create a contract that will revert when called
        MockContract mockContract = new MockContract();
        
        vm.prank(owner1);
        multisig.submitTransaction(address(mockContract), 0, abi.encodeWithSignature("revertFunction()"));
        
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        vm.prank(owner3);
        multisig.confirmTransaction(0);
        
        vm.prank(owner1);
        vm.expectRevert("Transaction failed");
        multisig.executeTransaction(0);
    }

    // ============ REVOKE CONFIRMATION TESTS ============

    function testRevokeConfirmation() public {
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        (,,,, uint256 numConfirmations) = multisig.getTransaction(0);
        assertEq(numConfirmations, 1);
        assertTrue(multisig.isConfirmedBy(0, owner2));
        
        vm.prank(owner2);
        vm.expectEmit(true, true, false, false);
        emit RevokeConfirmation(owner2, 0);
        multisig.revokeConfirmation(0);
        
        (,,,, numConfirmations) = multisig.getTransaction(0);
        assertEq(numConfirmations, 0);
        assertFalse(multisig.isConfirmedBy(0, owner2));
    }

    function testRevokeConfirmationNotConfirmed() public {
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner2);
        vm.expectRevert("Transaction not confirmed");
        multisig.revokeConfirmation(0);
    }

    function testRevokeConfirmationNotOwner() public {
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        vm.prank(nonOwner);
        vm.expectRevert("Not owner");
        multisig.revokeConfirmation(0);
    }

    function testRevokeConfirmationDoesNotExist() public {
        vm.prank(owner1);
        vm.expectRevert("Transaction does not exist");
        multisig.revokeConfirmation(0);
    }

    function testRevokeConfirmationAlreadyExecuted() public {
        vm.deal(address(multisig), 10 ether);
        
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        vm.prank(owner3);
        multisig.confirmTransaction(0);
        
        vm.prank(owner1);
        multisig.executeTransaction(0);
        
        vm.prank(owner2);
        vm.expectRevert("Transaction already executed");
        multisig.revokeConfirmation(0);
    }

    // ============ OWNER MANAGEMENT TESTS ============

    function testAddOwner() public {
        vm.prank(owner1);
        vm.expectEmit(true, false, false, false);
        emit OwnerAdded(owner4);
        multisig.addOwner(owner4);
        
        assertTrue(multisig.isOwner(owner4));
        assertEq(multisig.getOwners().length, 4);
        
        address[] memory returnedOwners = multisig.getOwners();
        assertEq(returnedOwners[3], owner4);
    }

    function testAddOwnerNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert("Not owner");
        multisig.addOwner(owner4);
    }

    function testAddOwnerAlreadyOwner() public {
        vm.prank(owner1);
        vm.expectRevert("Already an owner");
        multisig.addOwner(owner2);
    }

    function testAddOwnerZeroAddress() public {
        vm.prank(owner1);
        vm.expectRevert("Invalid owner address");
        multisig.addOwner(address(0));
    }

    function testRemoveOwner() public {
        vm.prank(owner1);
        vm.expectEmit(true, false, false, false);
        emit OwnerRemoved(owner3);
        multisig.removeOwner(owner3);
        
        assertFalse(multisig.isOwner(owner3));
        assertEq(multisig.getOwners().length, 2);
        
        address[] memory returnedOwners = multisig.getOwners();
        assertEq(returnedOwners[0], owner1);
        assertEq(returnedOwners[1], owner2);
    }

    function testRemoveOwnerTooFewOwners() public {
        // Create a multisig with 2 owners and 2 required confirmations
        address[] memory twoOwners = new address[](2);
        twoOwners[0] = owner1;
        twoOwners[1] = owner2;
        MultiSigWallet smallMultisig = new MultiSigWallet(twoOwners, 2);
        
        vm.prank(owner1);
        vm.expectRevert("Too few owners left");
        smallMultisig.removeOwner(owner2);
    }

    function testRemoveOwnerNotOwner() public {
        vm.prank(owner1);
        vm.expectRevert("Not an owner");
        multisig.removeOwner(nonOwner);
    }

    // ============ REQUIRED CONFIRMATIONS TESTS ============

    function testChangeRequiredConfirmations() public {
        vm.prank(owner1);
        vm.expectEmit(false, false, false, true);
        emit RequiredConfirmationsChanged(3);
        multisig.changeRequiredConfirmations(3);
        
        assertEq(multisig.requiredConfirmations(), 3);
    }

    function testChangeRequiredConfirmationsNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert("Not owner");
        multisig.changeRequiredConfirmations(3);
    }

    function testChangeRequiredConfirmationsZero() public {
        vm.prank(owner1);
        vm.expectRevert("Invalid required number of confirmations");
        multisig.changeRequiredConfirmations(0);
    }

    function testChangeRequiredConfirmationsTooHigh() public {
        vm.prank(owner1);
        vm.expectRevert("Invalid required number of confirmations");
        multisig.changeRequiredConfirmations(4);
    }

    function testChangeRequiredConfirmationsAfterOwnerRemoval() public {
        vm.prank(owner1);
        multisig.removeOwner(owner3);
        
        vm.prank(owner1);
        multisig.changeRequiredConfirmations(2);
        
        assertEq(multisig.requiredConfirmations(), 2);
        
        // Should not be able to set to 3 since we only have 2 owners now
        vm.prank(owner1);
        vm.expectRevert("Invalid required number of confirmations");
        multisig.changeRequiredConfirmations(3);
    }

    // ============ VIEW FUNCTION TESTS ============

    function testGetTransaction() public {
        bytes memory testData = abi.encodeWithSignature("testFunction(uint256)", 789);
        
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1.5 ether, testData);
        
        (address to, uint256 value, bytes memory data, bool executed, uint256 numConfirmations) = multisig.getTransaction(0);
        assertEq(to, recipient);
        assertEq(value, 1.5 ether);
        assertEq(data, testData);
        assertFalse(executed);
        assertEq(numConfirmations, 0);
    }

    function testGetOwners() public view {
        address[] memory returnedOwners = multisig.getOwners();
        assertEq(returnedOwners.length, 3);
        assertEq(returnedOwners[0], owner1);
        assertEq(returnedOwners[1], owner2);
        assertEq(returnedOwners[2], owner3);
    }

    function testGetTransactionCount() public {
        assertEq(multisig.getTransactionCount(), 0);
        
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        assertEq(multisig.getTransactionCount(), 1);
        
        vm.prank(owner2);
        multisig.submitTransaction(recipient, 2 ether, "");
        assertEq(multisig.getTransactionCount(), 2);
    }

    function testIsConfirmedBy() public {
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        assertFalse(multisig.isConfirmedBy(0, owner1));
        assertFalse(multisig.isConfirmedBy(0, owner2));
        assertFalse(multisig.isConfirmedBy(0, owner3));
        
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        assertFalse(multisig.isConfirmedBy(0, owner1));
        assertTrue(multisig.isConfirmedBy(0, owner2));
        assertFalse(multisig.isConfirmedBy(0, owner3));
    }

    // ============ INTEGRATION TESTS ============

    function testCompleteWorkflow() public {
        // Fund the multisig wallet
        vm.deal(address(multisig), 10 ether);
        
        // Submit transaction
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 2 ether, "");
        
        // Confirm by owner2
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        // Confirm by owner3
        vm.prank(owner3);
        multisig.confirmTransaction(0);
        
        // Execute transaction
        uint256 recipientBalanceBefore = recipient.balance;
        vm.prank(owner1);
        multisig.executeTransaction(0);
        
        // Verify execution
        assertEq(recipient.balance, recipientBalanceBefore + 2 ether);
        (,,, bool executed,) = multisig.getTransaction(0);
        assertTrue(executed);
    }

    function testRevokeAndReconfirmWorkflow() public {
        vm.deal(address(multisig), 10 ether);
        
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        vm.prank(owner3);
        multisig.confirmTransaction(0);
        
        // Revoke confirmation
        vm.prank(owner2);
        multisig.revokeConfirmation(0);
        
        (,,,, uint256 numConfirmations) = multisig.getTransaction(0);
        assertEq(numConfirmations, 1);
        
        // Try to execute (should fail)
        vm.prank(owner1);
        vm.expectRevert("Cannot execute transaction");
        multisig.executeTransaction(0);
        
        // Reconfirm
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        (,,,, numConfirmations) = multisig.getTransaction(0);
        assertEq(numConfirmations, 2);
        
        // Execute (should succeed)
        vm.prank(owner1);
        multisig.executeTransaction(0);
        
        (,,, bool executed,) = multisig.getTransaction(0);
        assertTrue(executed);
    }

    // ============ EDGE CASE TESTS ============

    function testSubmitTransactionToSelf() public {
        vm.deal(address(multisig), 10 ether);
        
        vm.prank(owner1);
        multisig.submitTransaction(address(multisig), 1 ether, "");
        
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        vm.prank(owner3);
        multisig.confirmTransaction(0);
        
        vm.prank(owner1);
        multisig.executeTransaction(0);
        
        (,,, bool executed,) = multisig.getTransaction(0);
        assertTrue(executed);
    }

    function testSubmitTransactionWithLargeData() public {
        bytes memory largeData = new bytes(1000);
        for (uint256 i = 0; i < 1000; i++) {
            largeData[i] = bytes1(uint8(i % 256));
        }
        
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 0, largeData);
        
        (,, bytes memory data,,) = multisig.getTransaction(0);
        assertEq(data.length, 1000);
        assertEq(data, largeData);
    }

    function testSubmitTransactionWithZeroValue() public {
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 0, "");
        
        (address to, uint256 value,,,) = multisig.getTransaction(0);
        assertEq(to, recipient);
        assertEq(value, 0);
    }

    function testSubmitTransactionWithMaxValue() public {
        vm.deal(address(multisig), type(uint256).max);
        
        vm.prank(owner1);
        multisig.submitTransaction(recipient, type(uint256).max, "");
        
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        vm.prank(owner3);
        multisig.confirmTransaction(0);
        
        vm.prank(owner1);
        multisig.executeTransaction(0);
        
        (,,, bool executed,) = multisig.getTransaction(0);
        assertTrue(executed);
    }
}

// Mock contract for testing failed transactions
contract MockContract {
    function revertFunction() external pure {
        revert("Mock revert");
    }
    
    receive() external payable {
        revert("Mock receive revert");
    }
} 