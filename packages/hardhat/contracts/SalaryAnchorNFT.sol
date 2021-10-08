//SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

import "hardhat/console.sol";

import {RedirectStreams, IConstantFlowAgreementV1, ISuperfluid, ISuperToken, ISETHCustom} from "./RedirectStreams.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract SalaryAnchorNFT is ERC721, RedirectStreams {
    constructor (
        address owner, 
        string memory _name, 
        string memory _symbol, 
        ISuperfluid host, 
        IConstantFlowAgreementV1 cfa,
        ISuperToken ethx
    ) payable ERC721( _name, _symbol) RedirectStreams(host, cfa, ethx) {
        _mint(owner, 1);
    }

    function changePrimaryReceiver(address newPrimaryReceiver) external onlyOwner() {
        _changePrimaryReceiver(newPrimaryReceiver);
    }

    function updateOutflow(address receiver, int96 flowRate) external onlyOwner() {
        require(receiver != primaryReceiver);
        _updateOutflow(receiver, flowRate);
        _updatePrimaryOutflow();
    }

    function _beforeTokenTransfer(address, address to, uint256) internal override {
        _changePrimaryReceiver(to);
    }

    modifier onlyOwner() {
        require(msg.sender == ownerOf(1));
        _;
    }
}
