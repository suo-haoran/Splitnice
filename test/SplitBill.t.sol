// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SplitBill.sol";
import "../src/SplitBillNFT.sol";
import "../src/USDC.sol";
import {console} from "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract SplitBillTest is Test, IERC721Receiver {
    address nftContractOwner = address(0x123456);
    address owner = address(this);
    address alice = address(0x123);
    address bob = address(0x456);
    address carol = address(0x789);
    address newOwner = address(0x101112);
    uint256 amountPayable;
    uint256 totalAmount;
    uint256 initAmount;
    uint256 tokenId;
    SplitBill splitBill;
    USDC usdc;
    SplitBillNFT nft;

    event OwnerWithdraw(address indexed owner, uint256 amount);
    event OwnershipTransferred(address indexed newOwner);
    event ContributionMade(address indexed participant, uint256 amount);

    // Deploy the contract with a total amount of 10 ETH
    function setUp() public {
        address[] memory participants = new address[](3);
        participants[0] = alice;
        participants[1] = bob;
        participants[2] = carol;
        // Deploy contract with an initial supply of 1 million USDC (6 decimals)
        uint256 initialSupply = 1_000_000 * 10 ** 6;
        usdc = new USDC(initialSupply);
        totalAmount = 12 * 1e6;
        amountPayable = 4 * 1e6;
        initAmount = 10 * 1e6;
        nft = new SplitBillNFT(nftContractOwner);

        vm.prank(nftContractOwner);
        tokenId = nft.mintNFT(owner);

        splitBill = new SplitBill(owner, totalAmount, participants, address(usdc), address(nft), tokenId);
    }

    // Test participants can contribute and owner can withdraw
    function testContributionsAndWithdraw() public {
        // Fund participants with USDC
        usdc.transfer(alice, initAmount); // USDC has 6 decimals
        usdc.transfer(bob, initAmount);
        usdc.transfer(carol, initAmount);

        // Participants contribute in USDC
        vm.prank(alice);
        usdc.approve(address(splitBill), amountPayable);
        vm.expectEmit();
        emit ContributionMade(alice, amountPayable);
        vm.prank(alice);
        splitBill.contribute(amountPayable);

        vm.prank(bob);
        usdc.approve(address(splitBill), amountPayable);
        vm.expectEmit();
        emit ContributionMade(bob, amountPayable);
        vm.prank(bob);
        splitBill.contribute(amountPayable);

        vm.prank(carol);
        usdc.approve(address(splitBill), amountPayable);
        vm.expectEmit();
        emit ContributionMade(carol, amountPayable);
        vm.prank(carol);
        splitBill.contribute(amountPayable);

        // Check that the totalCollected in the splitBill contract is 12 USDC (adjusted for USDC decimals)
        assertEq(splitBill.totalCollected(), totalAmount);

        // Owner's USDC balance before withdrawal
        uint256 ownerUSDCBalanceBefore = usdc.balanceOf(owner);

        // Approve the splitBill address
        vm.prank(owner);
        nft.approve(address(splitBill), tokenId);
        vm.expectEmit();
        emit OwnerWithdraw(owner, totalAmount);
        // Owner withdraws the funds in USDC
        vm.prank(owner);
        splitBill.withdraw();

        // Owner's USDC balance after withdrawal
        uint256 ownerUSDCBalanceAfter = usdc.balanceOf(owner);

        // Check that owner received 12 USDC
        assertEq(ownerUSDCBalanceAfter - ownerUSDCBalanceBefore, totalAmount);

        // isPaid should be true after withdrawal
        assertTrue(splitBill.isPaid());
    }

    function testTransferOwner() public {
        // Fund participants with USDC
        usdc.transfer(alice, initAmount); // USDC has 6 decimals
        usdc.transfer(bob, initAmount);
        usdc.transfer(carol, initAmount);

        // Participants contribute in USDC
        vm.prank(alice);
        usdc.approve(address(splitBill), amountPayable);
        vm.prank(alice);
        splitBill.contribute(amountPayable);

        vm.prank(bob);
        usdc.approve(address(splitBill), amountPayable);
        vm.prank(bob);
        splitBill.contribute(amountPayable);

        vm.prank(carol);
        usdc.approve(address(splitBill), amountPayable);
        vm.prank(carol);
        splitBill.contribute(amountPayable);

        // Check that the totalCollected in the splitBill contract is 12 USDC (adjusted for USDC decimals)
        assertEq(splitBill.totalCollected(), totalAmount);

        // Approve the splitBill address
        vm.prank(owner);
        nft.approve(address(splitBill), tokenId);
        // Owner transfers ownership to the new owner
        vm.expectEmit();
        emit OwnershipTransferred(newOwner);
        vm.prank(owner);
        splitBill.transferOwnership(newOwner);

        vm.prank(newOwner);
        nft.approve(address(splitBill), tokenId);
        vm.expectEmit();
        emit OwnerWithdraw(newOwner, totalAmount);
        vm.prank(newOwner);
        splitBill.withdraw();
    }

    // Test participants cannot contribute more than once
    function testDuplicateContribution() public {
        usdc.transfer(alice, initAmount); // USDC has 6 decimals

        vm.startPrank(alice);
        usdc.approve(address(splitBill), 8 * 1e6);
        splitBill.contribute(amountPayable);

        // Attempt to contribute again
        vm.expectRevert("You have already contributed");
        splitBill.contribute(amountPayable);
    }

    // Test only owner can withdraw
    function testOnlyOwnerCanWithdraw() public {
        // Fund alice with USDC
        usdc.transfer(alice, initAmount);

        // Alice tries to contribute with USDC
        vm.startPrank(alice);
        usdc.approve(address(splitBill), amountPayable);
        splitBill.contribute(amountPayable);

        // Attempt withdrawal by a participant (not the owner)
        vm.expectRevert("Only the contract owner can perform this action");
        splitBill.withdraw();
        vm.stopPrank();
    }

    // Test that contributions are tracked correctly
    function testContributionTracking() public {
        // Fund participants with USDC
        usdc.transfer(alice, initAmount);
        usdc.transfer(bob, initAmount);

        // Alice and Bob contribute in USDC
        vm.prank(alice);
        usdc.approve(address(splitBill), amountPayable);
        vm.prank(alice);
        splitBill.contribute(amountPayable);

        vm.prank(bob);
        usdc.approve(address(splitBill), amountPayable);
        vm.prank(bob);
        splitBill.contribute(amountPayable);

        // Check contributions
        uint256 aliceContribution = splitBill.getContribution(alice);
        uint256 bobContribution = splitBill.getContribution(bob);

        assertEq(aliceContribution, amountPayable);
        assertEq(bobContribution, amountPayable);
    }

    // Test that no one can send ETH directly to the contract
    function testPreventDirectTransfer() public {
        // Fund alice with some Ether (not used in USDC setup but included for testing ETH transfer rejection)
        vm.deal(alice, 2 ether);

        // Attempt to send Ether directly to the contract
        vm.prank(alice);
        vm.expectRevert("Please use the contribute function");
        (bool success,) = address(splitBill).call{value: 1 ether}("");
        assertEq(success, true);
    }

    // Implement the onERC721Received function to accept NFTs
    function onERC721Received(address, address, uint256, bytes memory) public pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
