//SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

import "hardhat/console.sol";
import {
    ISuperfluid,
    ISuperToken,
    ISuperApp,
    ISuperAgreement,
    SuperAppDefinitions
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {
    SuperAppBase
} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";


contract LoanContract is SuperAppBase {
    address public borrower;
    address public lender;
    address public collateralSalaryAnchor;
    uint256 loanAmount;
    bool fundsProvided;
    uint256 feePercentage; // as percentage
    uint256 repayFlowRate; // as percentage
    
    constructor() {

    }

    function provideFunds() external payable {
        // in parameters lender specifies the NFT he'll accept here (as the address)
        lender = msg.sender;
        fundsProvided = true;
        // calculate e.g. loanAmount = 9/10 * msg.value. The rest stays as deposit. 
    }

    function cancelEarly() external {
        // some limits on who can call it and when? E.g. only lender or borrower?
        // transfer all funds to the lender 
        // in selfdestruct with the address of the lender as the target? But it only works with ETH...
    }

    function borrow() external {
        // require: NFT approved for the this contract
        require(fundsProvided);
        // call transfer NFT
        borrower = msg.sender;
        // transfer loanAmount to borrower
        // starts the streams. With repayFlowRate to the lender and with the rest (how to caculate it) to the borrower
    }

    function onLoanRepaid() external {
        // triggered by the Chainlink Keeper
        // calculate repaidAmount
        // transfer repaidAmount - (loanAmount + interest) to borrower
        // transfer the remaining funds from the contract to the lender
    }

    function isLoanRepaid() external {
        // Chainlink Keeper checks this
        // repaidAmount >= loanAmount + interest
        // how to get repaidAmount? Some how we need to ask Superfluid contracts. How do we check balances with Superfluid?
    }

    function _getRepaidAmount() internal {
        // we somehow need to ask the Superfluid protocol
    }

    function _getTotalInterest() internal {
        // caclulate based on loanAmount. Maybe just the lender specifies?
    }

    // callbacks
    // what happens when the stream to NFT changes? Streams from the loan smart contract should also change... 
    // Let's ask Superfluid people if this will be handled in the future.
    // 

}
