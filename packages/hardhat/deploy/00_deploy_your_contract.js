// deploy/00_deploy_your_contract.js

//const { ethers } = require("hardhat");

// addresses on Kovan testnet we'll use
const superfluidHostAddress = "0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3";
const cfaAddress = "0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F";
const ethxAddress = "0xdd5462a7db7856c9128bc77bd65c2919ee23c6e1";

const employerAddress = "0x1C8a834124C23480C69BB12870d596556d54360A"; 
const emmyAddress = "0xB31a3E12121Dff522e0f0Dac1C99A4EBFD7a2dE5";
const dappAddress = "0x1E7017E6b71727cA47d220c6ABe7E82c7A2E0d41";

const daiAddress = "0xE680fA3CF20cAaB259Ab3E2d55a29C942ad72d01";
const linkAddress = "0xa36085f69e2889c224210f603d836748e7dc0088";

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  loanContract = await deploy("LoanContract", {
    // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
    from: deployer,
    //args: [ "Hello", ethers.utils.parseEther("1.5") ],
    args: [],
    log: true,
  });  

  salaryAnchorNFT = await deploy("SalaryAnchorNFT", {
    // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
    from: deployer,
    //args: [ "Hello", ethers.utils.parseEther("1.5") ],
    args: [ 
      emmyAddress,
      "Salary Anchor",
      "SALARY", 
      superfluidHostAddress, 
      cfaAddress, 
      ethxAddress,
    ],
    log: true,
    value: ethers.utils.parseEther("0.001"),
  });

  /*
    // Getting a previously deployed contract
    const YourContract = await ethers.getContract("YourContract", deployer);
    await YourContract.setPurpose("Hello");
  
    To take ownership of yourContract using the ownable library uncomment next line and add the 
    address you want to be the owner. 
    // yourContract.transferOwnership(YOUR_ADDRESS_HERE);

    //const yourContract = await ethers.getContractAt('YourContract', "0xaAC799eC2d00C013f1F11c37E654e59B0429DF6A") //<-- if you want to instantiate a version of a contract at a specific address!
  */

  /*
  //If you want to send value to an address from the deployer
  const deployerWallet = ethers.provider.getSigner()
  await deployerWallet.sendTransaction({
    to: "0x34aA3F359A9D614239015126635CE7732c18fDF3",
    value: ethers.utils.parseEther("0.001")
  })
  */

  /*
  //If you want to send some ETH to a contract on deploy (make your constructor payable!)
  const yourContract = await deploy("YourContract", [], {
  value: ethers.utils.parseEther("0.05")
  });
  */

  /*
  //If you want to link a library into your contract:
  // reference: https://github.com/austintgriffith/scaffold-eth/blob/using-libraries-example/packages/hardhat/scripts/deploy.js#L19
  const yourContract = await deploy("YourContract", [], {}, {
   LibraryName: **LibraryAddress**
  });
  */
};
module.exports.tags = ["SalaryAnchorNFT", "LoanContract"];
