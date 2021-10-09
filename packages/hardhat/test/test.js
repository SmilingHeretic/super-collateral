// const { ethers } = require("hardhat");
require("dotenv").config();
const { use, expect } = require("chai");
const hre = require("hardhat");
const { deployContract, MockProvider, solidity } = require("ethereum-waffle");
const hostABI = require("@superfluid-finance/ethereum-contracts/build/contracts/Superfluid.json");
const cfaABI = require("@superfluid-finance/ethereum-contracts/build/contracts/ConstantFlowAgreementV1.json");
const { ethers } = require("hardhat");

use(solidity);

// addresses on Kovan testnet we'll use
const superfluidHostAddress = "0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3";
const cfaAddress = "0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F";
const ethxAddress = "0xdd5462a7db7856c9128bc77bd65c2919ee23c6e1";

const employerAddress = "0x1C8a834124C23480C69BB12870d596556d54360A"; 
const emmyAddress = "0xB31a3E12121Dff522e0f0Dac1C99A4EBFD7a2dE5";
const dappAddress = "0x1E7017E6b71727cA47d220c6ABe7E82c7A2E0d41";

const daiAddress = "0xE680fA3CF20cAaB259Ab3E2d55a29C942ad72d01";
const linkAddress = "0xa36085f69e2889c224210f603d836748e7dc0088";

// abi's to interact with existing contracts
const tokenABI = [
    "function balanceOf(address owner) view returns (uint256)",
    "function symbol() view returns (string)",
]

const ethxABI = [
    "function upgradeByETH() external payable",
    "function balanceOf(address owner) view returns (uint256)",
    "function symbol() view returns (string)",
]


const tokenPerMonth = 385802469136

describe("SuperCollateral Dapp", function () {
    let emmySigner;
    let employerSigner;
    let dappSigner;
    let salaryAnchor;
    let loanContract;
    
    let cfaContract;
    let hostContract;
    let ethxContract;
    let daiContract;
    let linkContract;


    // function to advance time
    // waiting for someone to write it


    beforeEach(async () => {
        await network.provider.request({
            method: "hardhat_reset",
            params: [
              {
                forking: {
                  jsonRpcUrl: `https://eth-kovan.alchemyapi.io/v2/${process.env.KOVAN_ALCHEMY_KEY}`,
                  blockNumber: 27560058,
                },
              },
            ],
          });


        const [addr0, addr1] = await ethers.getSigners();
        await addr0.sendTransaction({to: emmyAddress, value: ethers.utils.parseEther("0.1")})
        await addr0.sendTransaction({to: employerAddress, value: ethers.utils.parseEther("1000")})
        await addr0.sendTransaction({to: dappAddress, value: ethers.utils.parseEther("1")})

        // function to print balances of all relevant tokens
        logBalances = async (name, signer) => {
            console.log(name)
            console.log("ETH", await ethers.utils.formatUnits(await signer.getBalance()))
            console.log(await ethxContract.symbol(), await ethers.utils.formatUnits(await ethxContract.balanceOf(signer.getAddress())))
            console.log(await linkContract.symbol(), await ethers.utils.formatUnits((await linkContract.balanceOf(signer.getAddress()))))
            console.log()
        }

        logFlows = async () => {
            console.log("Net flows")
            console.log("Employer", ((await cfaContract.getNetFlow(ethxAddress, employerAddress)) / tokenPerMonth))
            console.log("SalaryNFT", ((await cfaContract.getNetFlow(ethxAddress, salaryAnchor.address)) / tokenPerMonth))
            console.log("Emmy", ((await cfaContract.getNetFlow(ethxAddress, emmyAddress )) / tokenPerMonth))
            console.log("Dapp", ((await cfaContract.getNetFlow(ethxAddress, dappAddress)) / tokenPerMonth))
            console.log()

            console.log("Flows from to")
            console.log("Employer -> SalaryNFT", (await cfaContract.getFlow(ethxAddress, employerAddress, salaryAnchor.address))['flowRate'] / tokenPerMonth)
            console.log("SalaryNFT -> Emmy", (await cfaContract.getFlow(ethxAddress, salaryAnchor.address, emmyAddress))['flowRate'] / tokenPerMonth)
            console.log("SalaryNFT -> Dapp", (await cfaContract.getFlow(ethxAddress, salaryAnchor.address, dappAddress))['flowRate'] / tokenPerMonth)
            console.log()

        }

        // impersonate accounts
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [emmyAddress],
        });
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [employerAddress],
        });
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [dappAddress],
        });
        emmySigner = await ethers.getSigner(emmyAddress)
        employerSigner = await ethers.getSigner(employerAddress)
        dappSigner = await ethers.getSigner(dappAddress)

        // connect to contracts
        cfaContract = new ethers.Contract(cfaAddress, cfaABI.abi, dappSigner)
        hostContract = new ethers.Contract(superfluidHostAddress, hostABI.abi, dappSigner)
        ethxContract = new ethers.Contract(ethxAddress, ethxABI, dappSigner)
        daiContract = new ethers.Contract(daiAddress, tokenABI, dappSigner)
        linkContract = new ethers.Contract(linkAddress, tokenABI, dappSigner)
        
        // deploy salaryNFT with Emmy as owner
        const SalaryAnchor = await ethers.getContractFactory("SalaryAnchorNFT");
        salaryAnchor = await SalaryAnchor.deploy(
            emmyAddress,
            "Salary Anchor",
            "SALARY", 
            superfluidHostAddress, 
            cfaAddress, 
            ethxAddress,
            {value: ethers.utils.parseEther("0.001")}
        );
        await salaryAnchor.deployed();

        // convert ETH of employer to ETHx
        await ethxContract.connect(employerSigner).upgradeByETH({value: ethers.utils.parseEther("0.05")})
    
        // open stream employer -> salaryNFT
        const cfaInterface = new ethers.utils.Interface(cfaABI.abi)
        const txData = await cfaInterface.encodeFunctionData("createFlow", [
            ethxAddress,
            salaryAnchor.address,
            tokenPerMonth,
            "0x"
        ])
        await hostContract.connect(employerSigner).callAgreement(cfaAddress, txData, "0x")

        // Deploy the loan contract
        const LoanContract = await ethers.getContractFactory("LoanContract")
        loanContract = await LoanContract.deploy()
        await loanContract.deployed()

    })

    describe("SalaryAnchorNFT", async function () {
        xit("Emmy should own the salaryNFT and receive stream", async function () {
            expect(await salaryAnchor.ownerOf(1)).to.equal(emmyAddress);
            expect(await (await cfaContract.getNetFlow(ethxAddress, emmyAddress ))).to.equal(tokenPerMonth)
            await logFlows()
            await logBalances("Emmy", emmySigner)
        })

        xit("Emmy transfers salary NFT to the Dapp.", async function () {
            await salaryAnchor.connect(emmySigner).approve(dappAddress, 1)
            await salaryAnchor.connect(emmySigner).transferFrom(emmyAddress, dappAddress, 1)

            expect(await salaryAnchor.ownerOf(1)).to.equal(dappAddress);
            expect(await (await cfaContract.getNetFlow(ethxAddress, emmyAddress))).to.equal(0)
            expect(await (await cfaContract.getNetFlow(ethxAddress, dappAddress))).to.equal(tokenPerMonth)
            expect(await (await cfaContract.getNetFlow(ethxAddress, salaryAnchor.address))).to.equal(0)

            await logFlows()
            await logBalances("Emmy", emmySigner)
        })

        xit("Emmy changes the primary receiver of salary NFT to the Dapp.", async function () {
            await salaryAnchor.connect(emmySigner).changePrimaryReceiver(dappAddress)

            expect(await salaryAnchor.ownerOf(1)).to.equal(emmyAddress);
            expect(await (await cfaContract.getNetFlow(ethxAddress, emmyAddress))).to.equal(0)
            expect(await (await cfaContract.getNetFlow(ethxAddress, dappAddress))).to.equal(tokenPerMonth)
            expect(await (await cfaContract.getNetFlow(ethxAddress, salaryAnchor.address))).to.equal(0)

            await logFlows()
            await logBalances("Emmy", emmySigner)
        })

        xit("Emmy opens additional stream to the Dapp.",  async function () {
            await salaryAnchor.connect(emmySigner).updateOutflow(dappAddress, Math.round(0.2 * tokenPerMonth))

            expect(await salaryAnchor.ownerOf(1)).to.equal(emmyAddress);
            expect(await (await cfaContract.getNetFlow(ethxAddress, emmyAddress))).to.equal(Math.round(0.8 * tokenPerMonth))
            expect(await (await cfaContract.getNetFlow(ethxAddress, dappAddress))).to.equal(Math.round(0.2 * tokenPerMonth))
            expect(await (await cfaContract.getNetFlow(ethxAddress, salaryAnchor.address))).to.equal(0)

            await logFlows()
            await logBalances("Emmy", emmySigner)
        })
        
        xit("Flow from employer to salaryNFT increases",  async function () {
            const cfaInterface = new ethers.utils.Interface(cfaABI.abi)
            const txData = await cfaInterface.encodeFunctionData("updateFlow", [
                ethxAddress,
                salaryAnchor.address,
                tokenPerMonth * 2,
                "0x"
            ])
            await hostContract.connect(employerSigner).callAgreement(cfaAddress, txData, "0x")

            expect(await salaryAnchor.ownerOf(1)).to.equal(emmyAddress);
            expect(await (await cfaContract.getNetFlow(ethxAddress, emmyAddress))).to.equal(2 * tokenPerMonth)
            expect(await (await cfaContract.getNetFlow(ethxAddress, dappAddress))).to.equal(0)
            expect(await (await cfaContract.getNetFlow(ethxAddress, salaryAnchor.address))).to.equal(0)

            await logFlows()
            await logBalances("Emmy", emmySigner)
        })

        xit("Flow from employer to salaryNFT decreases.",  async function () {
            const cfaInterface = new ethers.utils.Interface(cfaABI.abi)
            const txData = await cfaInterface.encodeFunctionData("updateFlow", [
                ethxAddress,
                salaryAnchor.address,
                Math.round(tokenPerMonth * 0.5),
                "0x"
            ])
            await hostContract.connect(employerSigner).callAgreement(cfaAddress, txData, "0x")
            

            expect(await salaryAnchor.ownerOf(1)).to.equal(emmyAddress);
            expect(await (await cfaContract.getNetFlow(ethxAddress, emmyAddress))).to.equal(0.5 * tokenPerMonth)
            expect(await (await cfaContract.getNetFlow(ethxAddress, dappAddress))).to.equal(0)
            expect(await (await cfaContract.getNetFlow(ethxAddress, salaryAnchor.address))).to.equal(0)

            await logFlows()
            await logBalances("Emmy", emmySigner)
        })

        xit("Everything happens.",  async function () {
            await logFlows()

            await salaryAnchor.connect(emmySigner).updateOutflow(dappAddress, Math.round(0.2 * tokenPerMonth))

            await logFlows()

            await salaryAnchor.connect(emmySigner).approve(dappAddress, 1)
            await salaryAnchor.connect(emmySigner).transferFrom(emmyAddress, dappAddress, 1)

            await logFlows()

            
            await salaryAnchor.connect(dappSigner).updateOutflow(emmyAddress, Math.round(0.1 * tokenPerMonth))

            await logFlows()

            const cfaInterface = new ethers.utils.Interface(cfaABI.abi)
            const txData = await cfaInterface.encodeFunctionData("updateFlow", [
                ethxAddress,
                salaryAnchor.address,
                Math.round(tokenPerMonth * 0.5),
                "0x"
            ])
            await hostContract.connect(employerSigner).callAgreement(cfaAddress, txData, "0x")

            await logFlows()

            await salaryAnchor.connect(dappSigner).approve(emmyAddress, 1)
            await salaryAnchor.connect(dappSigner).transferFrom(dappAddress, emmyAddress, 1)

            await logFlows()
        })
    })

    describe("Loan contract", async function () {
        it("User story", async function () {
            console.log("After deployment")
            await logFlows()
            await logBalances("Emmy", emmySigner)
            await logBalances("Dapp", dappSigner)
            console.log("upkeep?", (await loanContract.isLoanRepaid()))
            
            console.log("The loan is prepared")
            await loanContract.connect(dappSigner).prepareLoan(
                emmyAddress,
                salaryAnchor.address,
                ethers.utils.parseEther("0.5"),
                ethers.utils.parseEther("0.1"),
                Math.round(tokenPerMonth * 0.1),
                {value: ethers.utils.parseEther("0.55")}
            )

            console.log(await loanContract.lender())
            console.log(await loanContract.borrower())
            console.log(ethers.utils.formatUnits(await loanContract.loanAmount()))
            console.log(ethers.utils.formatUnits(await loanContract.totalInterest()))
            console.log(ethers.utils.formatUnits(await loanContract.repayRate()))
            console.log(ethers.utils.formatUnits(await loanContract.overpayReturnDeposit()))
            console.log((await loanContract.loanInitializedTimestamp()).toString())
            console.log(await loanContract.status())
            console.log()
            
            console.log("Loan is being initialized")
            await salaryAnchor.connect(emmySigner).approve(loanContract.address, 1)
            await loanContract.connect(emmySigner).initializeLoan()
            
            console.log("After initialization of the loan")
            await logFlows()
            await logBalances("Emmy", emmySigner)
            await logBalances("Dapp", dappSigner)
            console.log("init timestamp", (await loanContract.loanInitializedTimestamp()).toString())
            console.log("status", await loanContract.status())
            console.log()
            console.log("repaid", ethers.utils.formatUnits(await loanContract.getAmountRepaid()))
            console.log("repaid", await loanContract.isLoanRepaid())
            console.log()

            // advance time
            await hre.network.provider.request({
                method: "evm_increaseTime",
                params: [10* 24 * 3600],
            })
            await hre.network.provider.request({
                method: "evm_mine",
                params: [],
            })
            
            console.log("After some time, the loan is being repaid")
            await logFlows()
            await logBalances("Emmy", emmySigner)
            await logBalances("Dapp", dappSigner)
            console.log("init timestamp", (await loanContract.loanInitializedTimestamp()).toString())
            console.log("status", await loanContract.status())
            console.log()
            console.log("repaid", ethers.utils.formatUnits(await loanContract.getAmountRepaid()))
            console.log("repaid?", await loanContract.isLoanRepaid())
            // await loanContract.connect(emmySigner).performUpkeep("0x") // should fail
            console.log()

            console.log("Advance time some more")
            await hre.network.provider.request({
                method: "evm_increaseTime",
                params: [6 * 30 * 24 * 3600],
            })
            await hre.network.provider.request({
                method: "evm_mine",
                params: [],
            })
            console.log("After some time, the loan is being repaid")
            await logFlows()
            await logBalances("Emmy", emmySigner)
            await logBalances("Dapp", dappSigner)
            console.log("init timestamp", (await loanContract.loanInitializedTimestamp()).toString())
            console.log("status", await loanContract.status())
            console.log()
            console.log("repaid", ethers.utils.formatUnits(await loanContract.getAmountRepaid()))
            console.log("repaid?", await loanContract.isLoanRepaid())
            console.log()

            console.log("Perform upkeep")
            await loanContract.connect(emmySigner).performUpkeep("0x")

            console.log("After onLoanRepaid()")
            await logFlows()
            await logBalances("Emmy", emmySigner)
            await logBalances("Dapp", dappSigner)
            console.log("init timestamp", (await loanContract.loanInitializedTimestamp()).toString())
            console.log("status", await loanContract.status())
            console.log()
            console.log("repaid", ethers.utils.formatUnits(await loanContract.getAmountRepaid()))
            console.log("upkeep?", await loanContract.isLoanRepaid())
        })
    })

})
