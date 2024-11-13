// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SplitBillNFT is ERC721Burnable, Ownable {
    uint256 private _tokenIds;

    constructor(address initialOwner) ERC721("SplitBillNFT", "SBNFT") Ownable(initialOwner) {}

    function mintNFT(address recipient) public onlyOwner returns (uint256) {
        _tokenIds += 1;
        uint256 newBillId = _tokenIds;
        _safeMint(recipient, newBillId);
        return newBillId;
    }
}
