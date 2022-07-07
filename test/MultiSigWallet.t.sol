// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    address[] internal owners;
    MultiSigWallet internal msw;
    address internal recipient = vm.addr(3);
    address internal notOwner = address(5);
    uint256 internal sendAmount = 1000000;

    function setUp() public {
        owners.push(address(this));

        for (uint256 i = 1; i <= 2; i++) {
            owners.push(vm.addr(i));
        }

        msw = new MultiSigWallet(owners, 2);
    }

    function test_ConstructorInsufficientOwnersRevert() public {
        vm.expectRevert("Not enough owners");
        new MultiSigWallet(new address[](0), 1);
    }

    function test_ConstructorInvalidApprovalsRevert() public {
        vm.expectRevert("Invalid amount of approvals");
        new MultiSigWallet(owners, 4);
    }

    function test_Constructor() public {
        assertEq(msw.getOwners().length, 3);
        assertEq(msw.approvalsRequired(), 2);
    }

    function test_Deposit() public {
        vm.deal(address(this), sendAmount);
        (bool success, ) = address(msw).call{value: sendAmount}("");

        assert(success);
        assertEq(address(msw).balance, sendAmount);
    }

    function test_InitiateNotOwnerRevert() public {
        vm.prank(notOwner);
        vm.expectRevert("Not owner");
        msw.initiate(recipient, sendAmount, "");
        vm.stopPrank();
    }

    function test_Initiate() public {
        msw.initiate(recipient, sendAmount, "");
        
        assertEq(msw.getTransactionCount(), 1);
    }
    
    function test_ApproveNotOwnerRevert() public {
        msw.initiate(recipient, sendAmount, "");
        vm.prank(notOwner);
        vm.expectRevert("Not owner");
        msw.approve(0);
        vm.stopPrank();
    }

    function test_ApproveDoesNotExistRevert() public {
        vm.expectRevert("Transaction does not exist");
        msw.approve(1);
    }

    function test_Approve() public {
        msw.initiate(recipient, sendAmount, "");
        msw.approve(0);

        assertEq(msw.getApprovalStatus(0), true);
    }

    function test_ApproveAlreadyApprovedRevert() public {
        msw.initiate(recipient, sendAmount, "");
        msw.approve(0);
        vm.expectRevert("Already approved");
        msw.approve(0);
    }

    function test_ExecuteNotOwnerRevert() public {
        vm.prank(notOwner);
        vm.expectRevert("Not owner");
        msw.execute(0);
        vm.stopPrank();
    }

    function test_ExecuteDoesNotExistRevert() public {
        vm.expectRevert("Transaction does not exist");
        msw.execute(1);
    }

    function test_ExecuteInsufficientApprovalsRevert() public {
        msw.initiate(recipient, sendAmount, "");
        msw.approve(0);
        vm.expectRevert("Insufficient approvals");
        msw.execute(0);
    }

    function test_ExecuteInsufficientBalanceRevert() public {
        msw.initiate(recipient, sendAmount, "");
        this.approveAllOwners();
        vm.expectRevert("Insufficient balance");
        msw.execute(0);
    }

    function test_Execute() public {
        vm.deal(address(msw), sendAmount);
        msw.initiate(recipient, sendAmount, "");
        this.approveAllOwners();   
        msw.execute(0);

        assertEq(address(recipient).balance, sendAmount);
        assertEq(address(msw).balance, 0);
    }

    function test_ExecuteAlreadyExecutedRevert() public {
        vm.deal(address(msw), sendAmount);
        msw.initiate(recipient, sendAmount, "");
        this.approveAllOwners();   
        msw.execute(0);
        vm.expectRevert("Already executed");
        msw.execute(0);
    }

    function test_RevokeNotOwnerRevert() public {
        vm.prank(notOwner);
        vm.expectRevert("Not owner");
        msw.revoke(0);
        vm.stopPrank();
    }

    function test_RevokeDoesNotExistRevert() public {
        vm.expectRevert("Transaction does not exist");
        msw.revoke(1);
    }

    function test_Revoke() public {
        msw.initiate(recipient, sendAmount, "");
        msw.approve(0);

        assertEq(msw.getApprovalStatus(0), true);

        msw.revoke(0);
        
        assertEq(msw.getApprovalStatus(0), false);
    }

    function test_RevokeAlreadyExecutedRevert() public {
        vm.deal(address(msw), sendAmount);
        msw.initiate(recipient, sendAmount, "");
        this.approveAllOwners();   
        msw.execute(0);
        vm.expectRevert("Already executed");
        msw.revoke(0);
    }

    function approveAllOwners() public {
        for (uint256 i; i < owners.length; i++) {
            vm.prank(owners[i]);
            msw.approve(0);
            vm.stopPrank();
        }
    }

}
