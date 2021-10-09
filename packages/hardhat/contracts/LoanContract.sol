
//SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

import "hardhat/console.sol";

import {SalaryAnchorNFT} from "./SalaryAnchorNFT.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/SafeCast.sol";


contract LoanContract {
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
    bool public initialized;

    constructor(
        address payable _borrower,
        SalaryAnchorNFT _collateralSalaryNFT,
        
        uint256 _loanAmount,
        uint256 _totalInterest,
        int96 _repayRate

    ) payable {
        lender = msg.sender;
        borrower = _borrower;
        collateralSalaryNFT = _collateralSalaryNFT;
        
        loanAmount = _loanAmount;
        totalInterest = _totalInterest;
        repayRate = _repayRate;
        
        overpayReturnDeposit = msg.value - _loanAmount;
        initialized = false;
    }

    function terminateEarly() external onlyLender() {
        require(!initialized);
        selfdestruct(lender);
    }

    function initializeLoan() external onlyBorrower() {
        require(!initialized);
        require(collateralSalaryNFT.getApproved(1) == address(this), "Need to approve collateral salary NFT for this contract before staring the loan");
        collateralSalaryNFT.transferFrom(borrower, address(this), 1);
        collateralSalaryNFT.updateOutflow(lender, repayRate);
        collateralSalaryNFT.changePrimaryReceiver(borrower);
        (bool sent,) = borrower.call{value: loanAmount}("");
        require(sent, "Failed to send Ether");

        initialized = true;
        loanInitializedTimestamp = block.timestamp;
    }

    function onLoanReapid() external {
        require(initialized);
        require(isLoanRepaid(), "Loan not repaid yet!");
        collateralSalaryNFT.updateOutflow(lender, int96(0));
        collateralSalaryNFT.approve(borrower, 1);
        collateralSalaryNFT.transferFrom(address(this), borrower, 1);
        
        uint256 amountOverpaid = getAmountRepaid() - (loanAmount + totalInterest);
        uint256 amountToReturn = amountOverpaid;
        if (amountOverpaid > address(this).balance) {
            amountToReturn = address(this).balance;
        }

        (bool sent,) = borrower.call{value: amountToReturn}("");
        require(sent, "Failed to send Ether");
        selfdestruct(lender);
    }

    function isLoanRepaid() public view returns (bool) {
        return getAmountRepaid() >= loanAmount + totalInterest;
    }

    function getAmountRepaid() public view returns (uint256) {
        return (block.timestamp - loanInitializedTimestamp) * uint256(repayRate); // does it work this way? Make sure.
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
}