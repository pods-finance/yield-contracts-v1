<p align="center"> Pods - Yield </p>


<p align="center">
  <a href="https://github.com/pods-finance/lisbon/actions?query=workflow:test">
    <img src="https://github.com/pods-finance/yield-contracts/workflows/lint+compile+test/badge.svg" alt="test"/>
  </a>
  
  <a href='https://coveralls.io/github/pods-finance/yield-contracts?branch=main'>
    <img src='https://coveralls.io/repos/github/pods-finance/yield-contracts/badge.svg?branch=main&amp;t=WNIoc0' alt='Coverage Status' />
  </a>

  <a href="http://gplv3.fsf.org/">
    <img src="https://img.shields.io/badge/license-AGPL--3-blue" alt="License AGPL-3">
  </a>

# Overview / Context

In this new project, Pods team is launching a 1-click exposure to strategy. The strategy consists in:

A) Allocate users deposits to a Yield Source (Lido, AAVE, AMM Pools). At the moment we're working only with Lido.

B) Each week, invest part of the yield generated weekly to buy weekly Call Options on ETH 10-20% _out-of-the-money_

By doing so, the depositor won't risk their principal amount and only take risks with the yield. This type of strategy is called Principal Protected.

# Points of centralization

Although we wished to build a strategy fully on-chain, for some reasons it's not possible right now. On the part B) (Buying weekly options) we don't have yet mature option protocols in the market with enough liquidity and low slippage. 
So, under the hood, on the part B) of the process, we transfer part of the yield to an **Investor** contract(Multisig) that will have the freedom to find the best place to buy those options (Ribbon auction / Pods AMM / OTC with Market Makers).

In case of Multisig hack, the only balances that **the Multisig have access are the yield generated between rounds**.

# Operation Flowchart
Red -> Any address can call this function

Black -> Only the Vault Controller

```mermaid
flowchart LR
    classDef anyaddress fill:#f555;
    A[Deposit]:::anyaddress -->|increase \nidleAmount| B(EndRound)
    B --> C{Are there \ndeposits to process?}
    C -->|yes| D[processQueuedDeposits]:::anyaddress --> E
    C --> |no|E[StartRound]
    E --> A


```

# System Actors

### User 
That EOA or a contract can interact with three functions: deposit, withdraw and processDeposits.

### Investor
A contract or Multisig that would be weekly funded to buy options

### Vault Controller
That vault controller have the power to:
- Start round
- Process deposits
- End round

# Steps

## End Round
During end round the vault will perform 3 things:


a) Set the flag `isProcessingDeposits` to true. This should block any deposit or withdraw.

b) Check the interest generated between rounds

c) Pull tokens from the **Investor**. If the option from the last week ended up ITM, the **Investor** should leave the profit available in the contract before the Vault Controller calls the End Round function.

d) After checking interest generated, part of that yield will be transferred back to **Investor** based on the `investorRatio` variable.

## Start Round
During this step, we perform the following logics:

a) Re-enable deposits and withdraws by setting the `isProcessingDeposits` to false.

b) Store the initial round balance and initial round share price.

## Test

```shell
npx hardhat test
```
## Deploy and config

Deploy the contracts

```shell
npx hardhat run ./scripts/deployTestnet.ts --network <network>
```
Populate the system with a few transactions
```shell
npx hardhat run ./scripts/populateTestnet.ts --network <network>
```
