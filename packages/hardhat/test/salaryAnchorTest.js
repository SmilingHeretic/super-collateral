// const { ethers } = require("hardhat");
const { use, expect } = require("chai");
const hre = require("hardhat");
const { deployContract, MockProvider, solidity } = require("ethereum-waffle");

use(solidity);

const superfluidHostAddress = "0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3";
const CFAaddress = "0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F";
const ETHxAddress = "0xdd5462a7db7856c9128bc77bd65c2919ee23c6e1";

const employerAddress = "0x1C8a834124C23480C69BB12870d596556d54360A"; 
const userEmmyAddress = "0xB31a3E12121Dff522e0f0Dac1C99A4EBFD7a2dE5";
const SCDappAddress = "0x1E7017E6b71727cA47d220c6ABe7E82c7A2E0d41";

const daiAddress = "0xE680fA3CF20cAaB259Ab3E2d55a29C942ad72d01";
const linkAddress = "0xa36085f69e2889c224210f603d836748e7dc0088";


describe("SuperCollateral Dapp", function () {
    it("Should deploy SalaryAnchor smart contract", async function () {
        const SalaryAnchor = await ethers.getContractFactory("SalaryAnchor");
        const salaryAnchor = await SalaryAnchor.deploy(
            userEmmyAddress,
            "Salary Anchor",
            "SALARY", 
            superfluidHostAddress, 
            CFAaddress, 
            ETHxAddress
        );
        expect(await salaryAnchor.balanceOf(userEmmyAddress)).to.equal(1);
    })
})
