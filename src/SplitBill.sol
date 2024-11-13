// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract SplitBill {
    // Variable packing
    uint256 public totalAmount;
    uint256 public totalCollected;
    uint256 public participantCount;
    mapping(address => uint256) public contributions;
    mapping(address => bool) public hasContributed;
    mapping(address => uint256) public amountPayable;
    bool public isPaid;
    uint256 public billTokenId;
    IERC20 public usdcToken;
    ERC721Burnable public billNFT;

    event ContributionMade(address indexed participant, uint256 amount);
    event OwnerWithdraw(address indexed owner, uint256 amount);
    event OwnershipTransferred(address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == billNFT.ownerOf(billTokenId), "Only the contract owner can perform this action");
        _;
    }

    modifier notPaid() {
        require(!isPaid, "The owner has already withdrawn the funds");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0, "Contribution should be more than 0");
        _;
    }

    constructor(
        uint256 _totalAmount,
        address[] memory _participants,
        address _usdcAddress,
        address _nftAddress,
        uint256 _tokenId
    ) {
        totalAmount = _totalAmount;
        totalCollected = 0;
        isPaid = false;
        participantCount = _participants.length;
        uint256 payableToOwner = totalAmount / participantCount;
        usdcToken = IERC20(_usdcAddress);
        billNFT = ERC721Burnable(_nftAddress);
        // billNFT.approve(owner, _tokenId);
        billTokenId = _tokenId;
        for (uint256 i = 0; i < _participants.length; i++) {
            contributions[_participants[i]] = 0;
            hasContributed[_participants[i]] = false;
            amountPayable[_participants[i]] = payableToOwner;
        }
    }

    // Participants contribute to reimburse the owner
    function contribute(uint256 amount) external validAmount(amount) notPaid {
        require(!hasContributed[msg.sender], "You have already contributed");
        require(amount == amountPayable[msg.sender], "You must contribute the exact amount payable");

        contributions[msg.sender] = amount;
        totalCollected += amount;
        hasContributed[msg.sender] = true;

        // Transfer USDC from the participant to the contract
        bool success = usdcToken.transferFrom(msg.sender, address(this), amount);
        require(success, "USDC transfer failed");

        emit ContributionMade(msg.sender, amount);
    }

    // Owner can withdraw the collected funds once participants have contributed
    function withdraw() external onlyOwner notPaid {
        require(totalCollected > 0, "No funds to withdraw");

        uint256 amount = totalCollected;
        isPaid = true;
        billNFT.burn(billTokenId);
        // Transfer the collected USDC to the owner
        bool success = usdcToken.transfer(msg.sender, amount);
        require(success, "USDC transfer failed");
        emit OwnerWithdraw(msg.sender, amount);
    }

    // Get the amount a participant has contributed
    function getContribution(address _participant) external view returns (uint256) {
        return contributions[_participant];
    }

    // Get the amount payable by a participant
    function getAmountPayable(address _participant) external view returns (uint256) {
        return amountPayable[_participant];
    }

    // Function to transfer ownership of the bill NFT
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        // Transfer the NFT representing the split bill to the new owner
        billNFT.safeTransferFrom(billNFT.ownerOf(billTokenId), newOwner, billTokenId);

        emit OwnershipTransferred(newOwner);
    }

    // Fallback function to prevent accidental ETH transfers
    receive() external payable {
        revert("Please use the contribute function");
    }
}
