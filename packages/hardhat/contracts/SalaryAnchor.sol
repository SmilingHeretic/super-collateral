//SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

import "hardhat/console.sol";

import {RedirectAll, ISuperToken, IConstantFlowAgreementV1, ISuperfluid} from "./RedirectAll.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract SalaryAnchor is ERC721, RedirectAll { 
    constructor(
        address owner, 
        string memory _name, 
        string memory _symbol, 
        ISuperfluid host, 
        IConstantFlowAgreementV1 cfa, 
        ISuperToken acceptedToken
    ) ERC721( _name, _symbol) RedirectAll(host, cfa, acceptedToken, owner) {
        _mint(owner, 1);
        console.log(owner);
    }

    function _beforeTokenTransfer(address, address to, uint256) internal override {
        _changeReceiver(to);
    }
}
