
//SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

import "hardhat/console.sol";

import {SalaryAnchorNFT} from "./SalaryAnchorNFT.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/SafeCast.sol";
import "@chainlink/contracts/src/v0.7/interfaces/KeeperCompatibleInterface.sol";


contract LoanContract is KeeperCompatibleInterface {
    using SafeCast for int256;
    using SafeCast for uint256;

    address payable public lender;
    address payable public borrower;
    SalaryAnchorNFT public collateralSalaryNFT;
    uint256 public loanAmount;
    uint256 public totalInterest;
    int96 public repayRate; // the same as Superfluid uints: wei per second
    uint256 public overpayReturnDeposit;
    uint256 public loanInitializedTimestamp;
    // status
    // 0 - contract empty waiting for the lender to provide funds and terms
    // 1 - funds and terms provided. Waiting for the borrower to approve the collateral and initialize the loan.
    // 2 - Loan in progress. Borrower received the funds, lender receives repayment in stream.
    uint16 public status;

    constructor() {
        status = 0;
    }

    function prepareLoan(
        address payable _borrower,
        SalaryAnchorNFT _collateralSalaryNFT,
        uint256 _loanAmount,
        uint256 _totalInterest,
        int96 _repayRate
    ) external payable {
        // lender provides the funds and terms of the loan
        require(status == 0, "Loan contract must be empty");

        lender = msg.sender;
        borrower = _borrower;
        collateralSalaryNFT = _collateralSalaryNFT;
        
        loanAmount = _loanAmount;
        totalInterest = _totalInterest;
        repayRate = _repayRate;
        overpayReturnDeposit = msg.value - _loanAmount;

        status = 1;
    }

    function terminateEarly() external onlyLender() {
        // In case lender already prepared the loan but borrower changed her mind, we need a way for the lender to recover the funds.
        require(status == 1, "Loan already initialized or loan contract empty");

        (bool sent,) = lender.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
        
        status = 0;
    }

    function initializeLoan() external onlyBorrower() {
        // Borrower initializes the loan - accepts the terms, receives the funds and temporarily transfers ownership of the collateral.
        require(status == 1, "Loan already initialized or funds and terms not yet provided");
        require(collateralSalaryNFT.getApproved(1) == address(this), "Need to approve collateral salary NFT for this contract before initializing the loan");

        collateralSalaryNFT.transferFrom(borrower, address(this), 1);
        collateralSalaryNFT.updateOutflow(lender, repayRate);
        collateralSalaryNFT.changePrimaryReceiver(borrower);
        (bool sent,) = borrower.call{value: loanAmount}("");
        require(sent, "Failed to send Ether");

        loanInitializedTimestamp = block.timestamp;
        status = 2;
    }

    function onLoanReapid() public {
        // Actions that need to be performed when the loan is repayed.
        require(status == 2);
        require(isLoanRepaid(), "Loan not repaid yet!");

        // Stop the repayment stream to the lender
        collateralSalaryNFT.updateOutflow(lender, int96(0));
        // Transfer the salary NFT back to the borrower
        collateralSalaryNFT.approve(borrower, 1);
        collateralSalaryNFT.transferFrom(address(this), borrower, 1);
        
        // This function might be triggerd with delay, not exactly the moment the loan is repaid.
        // During this delay period the repayment stream to the lender is still open. We need to return the overpay to the borrower.
        uint256 amountOverpaid = getAmountRepaid() - (loanAmount + totalInterest);
        uint256 amountToReturn = amountOverpaid;
        if (amountOverpaid > overpayReturnDeposit) {
            amountToReturn = overpayReturnDeposit;
        }
        (bool sent,) = borrower.call{value: amountToReturn}("");
        require(sent, "Failed to send Ether");
        
        // Send the remainder of deposit for the case of overpay to the lender.
        (sent,) = lender.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");

        // Reset the contract so it can be used for another loan.
        status = 0;
    }

    function isLoanRepaid() public view returns (bool) {
        return getAmountRepaid() >= loanAmount + totalInterest;
    }

    function getAmountRepaid() public view returns (uint256) {
        // repayRate is in super wei/ second
        // timestamp is in seconds
        return (block.timestamp - loanInitializedTimestamp) * uint256(repayRate); 
    }

    // modifiers
    modifier onlyBorrower() {
        require(msg.sender == borrower);
        _;
    }

    modifier onlyLender() {
        require(msg.sender == lender);
        _;
    }

    // functions to make the contract compatible with the Chainlink Keeper
    function checkUpkeep(bytes calldata /* checkData */) external override returns (bool upkeepNeeded, bytes memory /* performData */) {
        upkeepNeeded = isLoanRepaid() && status == 2;
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        onLoanReapid();
    }
}