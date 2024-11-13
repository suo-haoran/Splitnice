// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SplitBill.sol";
import "./SplitBillNFT.sol";

contract SplitBillFactory {
    // mapping to keep track of all deployed SplitBill contracts
    // user address => SplitBill contract addresses
    // Note: Although this is private, it can be seen using other tools like ethers.js
    address private usdcToken;
    SplitBillNFT private splitBillNFT;

    struct Proposal {
        // Variable Packing
        bool isApproved;
        address creator;
        uint256 totalAmount;
        uint256 requiredApprovals;
        uint256 approvals;
        address[] participants;
        mapping(address => bool) hasApproved;
    }

    mapping(address => address[]) private splitBills;
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount = 0;

    event ProposalCreated(uint256 proposalId, address creator, uint256 totalAmount, address[] participants);
    event ProposalApproved(uint256 proposalId, address participant, uint256 totalApprovals);
    event SplitBillCreated(
        address indexed splitBillAddress, uint256 totalAmount, uint256 tokenId, address[] participants
    );

    constructor(address _usdcToken) {
        usdcToken = _usdcToken;
        splitBillNFT = new SplitBillNFT(address(this));
    }

    modifier proposalExists(uint256 proposalId) {
        require(proposals[proposalId].creator != address(0), "Proposal does not exist");
        _;
    }

    modifier onlyParticipant(uint256 proposalId) {
        require(isParticipant(proposalId, msg.sender), "Not a participant in this proposal");
        _;
    }

    // Create a new proposal for a SplitBill contract
    function createProposal(uint256 _totalAmount, address[] memory _participants, uint256 _requiredApprovals)
        external
        returns (uint256)
    {
        proposalCount += 1;
        Proposal storage newProposal = proposals[proposalCount - 1];
        newProposal.creator = msg.sender;
        newProposal.totalAmount = _totalAmount;
        newProposal.participants = _participants;
        newProposal.requiredApprovals = _requiredApprovals;
        newProposal.approvals = 0;
        newProposal.isApproved = false;

        emit ProposalCreated(proposalCount, msg.sender, _totalAmount, _participants);
        return proposalCount - 1;
    }

    // Allow participants to approve the proposal before creating the SplitBill Contract
    function approveProposal(uint256 proposalId) external proposalExists(proposalId) onlyParticipant(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.isApproved, "Proposal already approved");
        require(!proposal.hasApproved[msg.sender], "You already approved this proposal");

        proposal.hasApproved[msg.sender] = true;
        proposal.approvals += 1;

        emit ProposalApproved(proposalId, msg.sender, proposal.approvals);

        if (proposal.approvals >= proposal.requiredApprovals) {
            proposal.isApproved = true;
            createSplitBill(proposalId);
        }
    }

    // Function to deploy a new SplitBill contract
    function createSplitBill(uint256 proposalId) internal proposalExists(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.isApproved, "Proposal has not reached required approvals");

        uint256 tokenId = splitBillNFT.mintNFT(proposal.creator);

        // Deploy the new SplitBill contract
        SplitBill newSplitBill =
            new SplitBill(proposal.totalAmount, proposal.participants, usdcToken, address(splitBillNFT), tokenId);

        // Store the address of the new contract
        splitBills[proposal.creator].push(address(newSplitBill));

        // Emit an event for the newly created SplitBill contract
        emit SplitBillCreated(address(newSplitBill), proposal.totalAmount, tokenId, proposal.participants);
    }

    // Helper function to check if an address is a participant in a proposal
    function isParticipant(uint256 proposalId, address account) public view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        for (uint256 i = 0; i < proposal.participants.length; i++) {
            if (proposal.participants[i] == account) {
                return true;
            }
        }
        return false;
    }

    // Function to get the deployed SplitBill contracts
    function getDeployedSplitBills() external view returns (address[] memory) {
        return splitBills[msg.sender];
    }
}
