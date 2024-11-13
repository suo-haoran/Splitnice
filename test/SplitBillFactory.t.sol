// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SplitBillFactory.sol";
import "../src/SplitBill.sol";
import "../src/USDC.sol";

contract SplitBillFactoryTest is Test {
    SplitBillFactory public splitBillFactory;
    address public owner1;
    address public owner2;
    address public participant3;
    USDC usdc;
    uint256 totalAmount;

    event ProposalCreated(uint256 proposalId, address creator, uint256 totalAmount, address[] participants);
    event ProposalApproved(uint256 proposalId, address participant, uint256 totalApprovals);
    event SplitBillCreated(
        address indexed splitBillAddress, uint256 totalAmount, uint256 tokenId, address[] participants
    );

    function setUp() public {
        uint256 initialSupply = 1_000_000 * 10 ** 6;
        usdc = new USDC(initialSupply);
        splitBillFactory = new SplitBillFactory(address(usdc));
        owner1 = address(0x1);
        owner2 = address(0x2);
        participant3 = address(0x3);
        totalAmount = 12 * 1e6;
    }

    function testCreateSplitBill() public {
        // Setup participants
        address[] memory participants = new address[](2);
        participants[0] = owner2;
        participants[1] = address(0x3);

        // Create a new SplitBill contract as owner1
        vm.prank(owner1);
        uint256 proposalId = splitBillFactory.createProposal(totalAmount, participants, participants.length);

        // Verify that the SplitBill was created
        vm.prank(owner1);
        address[] memory bills = splitBillFactory.getDeployedSplitBills();
        assertEq(bills.length, 0, "Owner shouldn't have any deployed SplitBill contract");

        (bool isApproved, address creator, uint256 totalAmountProposed,,) = splitBillFactory.proposals(proposalId);
        assertEq(creator, owner1, "Proposal creator should be owner1");

        assertEq(totalAmountProposed, totalAmount, "Proposal totalAmount should match the requested amount");

        // Approve the proposal by the first owner (owner2)
        vm.prank(owner2);
        splitBillFactory.approveProposal(proposalId);

        // Verify that the proposal is still not approved
        (isApproved,,,,) = splitBillFactory.proposals(proposalId);
        assertFalse(isApproved, "Proposal should not be approved yet");

        // Approve the proposal by the second owner (address(0x3))
        vm.prank(participant3);
        splitBillFactory.approveProposal(proposalId);

        // Verify that the proposal is now approved
        (isApproved,,,,) = splitBillFactory.proposals(proposalId);
        assertTrue(isApproved, "Proposal should be approved after enough approvals");

        // Verify that the SplitBill was created after the multi-sig approval
        vm.prank(owner1);
        bills = splitBillFactory.getDeployedSplitBills();
        assertEq(bills.length, 1, "Owner should have one deployed SplitBill contract");

        assertTrue(bills[0] != address(0), "The address of the SplitBill should not be zero");
    }

    function testOnlyOwnerCanSeeTheirBills() public {
        // Setup participants
        address[] memory participants = new address[](3);
        participants[0] = owner1;
        participants[1] = owner2;
        participants[2] = participant3;

        // Create a new SplitBill contract as owner1
        vm.prank(owner1);
        uint256 proposalId = splitBillFactory.createProposal(totalAmount, participants, participants.length);

        // Verify that the SplitBill was created
        vm.prank(owner1);
        address[] memory bills = splitBillFactory.getDeployedSplitBills();
        assertEq(bills.length, 0, "Owner shouldn't have any deployed SplitBill contract");

        (bool isApproved, address creator, uint256 totalAmountProposed,,) = splitBillFactory.proposals(proposalId);
        assertEq(creator, owner1, "Proposal creator should be owner1");

        assertEq(totalAmountProposed, totalAmount, "Proposal totalAmount should match the requested amount");

        // Approve the proposal
        vm.prank(owner1);
        splitBillFactory.approveProposal(proposalId);
        vm.prank(owner2);
        splitBillFactory.approveProposal(proposalId);
        vm.prank(participant3);
        splitBillFactory.approveProposal(proposalId);

        // Verify that the proposal is still not approved
        (isApproved,,,,) = splitBillFactory.proposals(proposalId);
        assertTrue(isApproved, "Proposal should be approved");

        // Verify that owner1 can see their own bill
        vm.prank(owner1);
        address[] memory owner1Bills = splitBillFactory.getDeployedSplitBills();
        assertEq(owner1Bills.length, 1, "Owner1 should have one deployed SplitBill contract");

        // Verify that owner2 cannot see owner1's bill
        vm.prank(owner2);
        address[] memory owner2Bills = splitBillFactory.getDeployedSplitBills();
        assertEq(owner2Bills.length, 0, "Owner2 should have no deployed SplitBill contracts");
    }

    function testEventEmittedOnCreation() public {
        // Setup participants
        address[] memory participants = new address[](3);
        participants[0] = owner1;
        participants[1] = owner2;
        participants[2] = address(0x3);

        vm.expectEmit(false, true, true, true);
        emit ProposalCreated(1, owner1, totalAmount, participants);
        // Create a new SplitBill contract as owner1
        vm.startPrank(owner1);
        uint256 proposalId = splitBillFactory.createProposal(totalAmount, participants, participants.length);

        // Verify that the SplitBill was created
        address[] memory bills = splitBillFactory.getDeployedSplitBills();
        assertEq(bills.length, 0, "Owner shouldn't have any deployed SplitBill contract");

        (bool isApproved, address creator, uint256 totalAmountProposed,,) = splitBillFactory.proposals(proposalId);
        assertEq(creator, owner1, "Proposal creator should be owner1");

        assertEq(totalAmountProposed, totalAmount, "Proposal totalAmount should match the requested amount");

        // Approve the proposal
        splitBillFactory.approveProposal(proposalId);
        vm.stopPrank();

        vm.prank(owner2);
        splitBillFactory.approveProposal(proposalId);
        vm.expectEmit();
        emit ProposalApproved(proposalId, participant3, 3);
        // Expect the SplitBillCreated event
        vm.expectEmit(false, true, false, true); // Don't match the first parameter because it's dynamic
        emit SplitBillCreated(address(0), totalAmount, 1, participants);
        vm.prank(participant3);
        splitBillFactory.approveProposal(proposalId);

        // Verify that the proposal is now approved
        (isApproved,,,,) = splitBillFactory.proposals(proposalId);
        assertTrue(isApproved, "Proposal should be approved after enough approvals");
    }
}
