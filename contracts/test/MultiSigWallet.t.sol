// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet public multisig;
    
    address public owner1 = address(0x1);
    address public owner2 = address(0x2);
    address public owner3 = address(0x3);
    address public recipient = address(0x4);
    
    address[] public owners;
    uint256 public requiredConfirmations = 2;

    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    function setUp() public {
        owners = [owner1, owner2, owner3];
        multisig = new MultiSigWallet(owners, requiredConfirmations);
    }

    function testConstructor() public {
        assertTrue(multisig.isOwner(owner1));
        assertTrue(multisig.isOwner(owner2));
        assertTrue(multisig.isOwner(owner3));
        assertFalse(multisig.isOwner(address(0x5)));
        assertEq(multisig.requiredConfirmations(), 2);
        assertEq(multisig.getOwners().length, 3);
    }

    function testConstructorInvalidOwners() public {
        address[] memory emptyOwners = new address[](0);
        vm.expectRevert("Owners required");
        new MultiSigWallet(emptyOwners, 1);
    }

    function testConstructorInvalidConfirmations() public {
        address[] memory testOwners = new address[](2);
        testOwners[0] = owner1;
        testOwners[1] = owner2;
        
        vm.expectRevert("Invalid required number of confirmations");
        new MultiSigWallet(testOwners, 0);
        
        vm.expectRevert("Invalid required number of confirmations");
        new MultiSigWallet(testOwners, 3);
    }

    function testSubmitTransaction() public {
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        assertEq(multisig.getTransactionCount(), 1);
        
        (address to, uint256 value, bytes memory data, bool executed, uint256 numConfirmations) = multisig.getTransaction(0);
        assertEq(to, recipient);
        assertEq(value, 1 ether);
        assertEq(data.length, 0);
        assertFalse(executed);
        assertEq(numConfirmations, 0);
    }

    function testSubmitTransactionNotOwner() public {
        vm.prank(address(0x5));
        vm.expectRevert("Not owner");
        multisig.submitTransaction(recipient, 1 ether, "");
    }

    function testConfirmTransaction() public {
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        (,,,, uint256 numConfirmations) = multisig.getTransaction(0);
        assertEq(numConfirmations, 1);
        assertTrue(multisig.isConfirmedBy(0, owner2));
    }

    function testConfirmTransactionNotOwner() public {
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(address(0x5));
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
        
        vm.prank(owner1);
        multisig.executeTransaction(0);
        
        (,,, bool executed,) = multisig.getTransaction(0);
        assertTrue(executed);
        assertEq(recipient.balance, recipientBalanceBefore + 1 ether);
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

    function testRevokeConfirmation() public {
        vm.prank(owner1);
        multisig.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner2);
        multisig.confirmTransaction(0);
        
        (,,,, uint256 numConfirmations) = multisig.getTransaction(0);
        assertEq(numConfirmations, 1);
        
        vm.prank(owner2);
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

    function testAddOwner() public {
        address newOwner = address(0x6);
        
        vm.prank(owner1);
        multisig.addOwner(newOwner);
        
        assertTrue(multisig.isOwner(newOwner));
        assertEq(multisig.getOwners().length, 4);
    }

    function testAddOwnerAlreadyOwner() public {
        vm.prank(owner1);
        vm.expectRevert("Already an owner");
        multisig.addOwner(owner2);
    }

    function testRemoveOwner() public {
        vm.prank(owner1);
        multisig.removeOwner(owner3);
        
        assertFalse(multisig.isOwner(owner3));
        assertEq(multisig.getOwners().length, 2);
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

    function testChangeRequiredConfirmations() public {
        vm.prank(owner1);
        multisig.changeRequiredConfirmations(3);
        
        assertEq(multisig.requiredConfirmations(), 3);
    }

    function testChangeRequiredConfirmationsInvalid() public {
        vm.prank(owner1);
        vm.expectRevert("Invalid required number of confirmations");
        multisig.changeRequiredConfirmations(0);
        
        vm.prank(owner1);
        vm.expectRevert("Invalid required number of confirmations");
        multisig.changeRequiredConfirmations(4);
    }

    function testReceive() public {
        uint256 amount = 5 ether;
        vm.deal(address(0x5), amount);
        
        vm.prank(address(0x5));
        (bool success,) = address(multisig).call{value: amount}("");
        
        assertTrue(success);
        assertEq(address(multisig).balance, amount);
    }

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
} 