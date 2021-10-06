# SuperCollateral

A dapp that enables users to use a salary NFT as a collateral for a loan. Salary NFT is an NFT that receives a salary in stream and redirects it to its owner. We use Superfuid to stream salary and Chainlink Keeper to trigger the required actions after the loan is repaid.


# 🏄‍♂️ Quick Start

Prerequisites: [Node](https://nodejs.org/en/download/) plus [Yarn](https://classic.yarnpkg.com/en/docs/install/) and [Git](https://git-scm.com/downloads)

> install your 👷‍ Hardhat chain:

```bash
cd super-collateral
yarn install
```

> start your local fork of Kovan testnet:

```bash
cd super-collateral
cp packages/hardhat/example.env packages/hardhat/.env
```

Set `KOVAN_ALCHEMY_KEY` in `packages/hardhat/.env` to your [Alchemy](https://www.alchemy.com/) key. Then:

```bash
cd super-collateral
yarn chain
```

> in a second terminal window, start your 📱 frontend:

```bash
cd super-collateral
yarn start
```

> in a third terminal window, 🛰 deploy your contract:

```bash
cd super-collateral
yarn deploy
```

🔏 Edit your smart contracts in `packages/hardhat/contracts`

📝 Edit your frontend `App.jsx` in `packages/react-app/src`

💼 Edit your deployment scripts in `packages/hardhat/deploy`

📱 Open http://localhost:3000 to see the app
