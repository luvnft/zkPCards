// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract zkPCard is ERC721, ERC721Burnable, Pausable, Ownable {

    error TransferFailed();
    error CardExpired();
    error NotAuthorized();
    error ZeroAmountIssued();
    error InsufficientPoolBalance();
    error InsufficientCredit();
    error SendEnoughFunds();
    error CardHasBeenDiscarded();

    uint256 private _tokenId = 1;
    uint256 public poolSize;
    string public poolName;

    struct CardInfo {
        string cardName;
        uint256 amountIssued;
        uint256 amountSpent;
        uint256 expirationTime;
        bool hasBeenDiscarded;
    }
    mapping (uint256 => CardInfo) cards;

    event CardIssued(uint256 tokenId, string cardName, address issuedTo, uint256 amountIssued, uint256 expirationTime);
    event FundsSpentFromCard(uint256 tokenId, address recipient, uint256 spendAmount);
    event FundsAddedToPool(uint256 amount, address addedBy);
    event CardUpdated(uint256 tokenId, uint256 additionalAmount, uint256 newExpirationTime);
    event CardDiscarded(uint256 tokenId);
    event ContractPaused();
    event ContractUnpaused();

    constructor(string memory name, string memory symbol, address initialOwner) 
    ERC721(name, symbol) Ownable(initialOwner) 
    {
        poolName = name;
    }

    function issueCard(
        string memory name,
        address to, 
        uint256 amountIssued,  
        uint256 expirationTime
    ) external onlyOwner 
    {
        uint256 tokenId = safeMint(to);
        CardInfo memory newCard = CardInfo({
        cardName: name,
        amountIssued: amountIssued,
        amountSpent: 0,
        expirationTime: expirationTime,
        hasBeenDiscarded: false
        });
        cards[tokenId] = newCard;
        emit CardIssued(tokenId, name, to, amountIssued, expirationTime);
    }

    function spendFromCard(uint256 tokenId, address recipient, uint256 spendAmount) external whenNotPaused {
        CardInfo storage card = cards[tokenId];
        if (ownerOf(tokenId) != msg.sender) {
            revert NotAuthorized();
        }
        if (block.timestamp > card.expirationTime) {
            revert CardExpired();
        }
        if (card.hasBeenDiscarded == true) {
            revert CardHasBeenDiscarded();
        }
        if (card.amountIssued == 0) {
            revert ZeroAmountIssued();
        }
        if (card.amountIssued - card.amountSpent < spendAmount) {
            revert InsufficientCredit();
        }
        if (address(this).balance < spendAmount) {
            revert InsufficientPoolBalance();
        }
        card.amountSpent += spendAmount;
        (bool success , ) = payable(recipient).call{ value : spendAmount}("");
        if(!success) {
            revert TransferFailed();
        }
        emit FundsSpentFromCard(tokenId, recipient, spendAmount);
    }

    function addFundsToPool(uint256 amount) external payable onlyOwner {
        if (amount != msg.value) {
           revert SendEnoughFunds(); 
        }
        poolSize += amount;
        emit FundsAddedToPool(amount, msg.sender);
    }

    function updateCard(
        uint256 tokenId, 
        uint256 additionalAmount,
        uint256 newExpirationTime
        ) external onlyOwner {
        CardInfo storage card = cards[tokenId];
        card.amountIssued += additionalAmount;
        card.expirationTime = newExpirationTime;
        emit CardUpdated(tokenId, additionalAmount, newExpirationTime);
    }

    function discardCard(uint256 tokenId) external onlyOwner {
        CardInfo storage card = cards[tokenId];
        card.hasBeenDiscarded = true;
        emit CardDiscarded(tokenId);
    }

    function getCardInfo(uint256 tokenId) public view returns(CardInfo memory) {
        return cards[tokenId];
    }

    function pause() public onlyOwner {
        _pause();
        emit ContractPaused();
    }

    function unpause() public onlyOwner {
        _unpause();
        emit ContractUnpaused();
    }

    function safeMint(address to) internal returns(uint256) {
        uint256 tokenId = _tokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }
}