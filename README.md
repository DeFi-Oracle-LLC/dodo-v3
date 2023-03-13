# DODO V3
## Overview
What is DODO V3?

For market makers, DODO V3 can offer:
- leveraged market making pool
- multi-assets pool
- flexible market-making strategies

For LPs, DODO V3 offers:
- fixed interests return
- no impermanent loss

For traders, DODO V3 offers:
- better liquidity

The DODO V3 smart contract system is composed of three parts: Core, Periphery, and Lib.

The Core contracts are the backbone of DODO V3 and are responsible for defining the functions of pools, determining the rules for pool creation, maintaining the pools, and outlining the procedures for interacting with the assets within the pools.

The Periphery contracts interact with one or more of the Core contracts, but are not considered part of the core. These contracts improve user safety and clarity by offering alternative methods of accessing the core, and also provide necessary external data for core. Being separate from the core contracts, they are upgradeable and replaceable, making the entire contract architecture low-coupled and flexible.

The Lib contracts serve as internal and external libraries that provide frequently used code logic for the Core contracts, helping to reduce the byte size of the Core contracts.
### D3MM (DODO V3 Market Maker)
D3MM is the main contract, often referred as pool. The pool owner can use this contract to do market making work. The LPs can deposit assets into this contract to earn interests. Normal user can swap tokens through this pool.

D3MM contract inherits four contracts:

`D3Funding` manages the deposit and withdrawal of assets

`D3Liquidation` manages the liquidation process

`D3Trading` provides token swaping functions

`D3Maker` provides market making functions for pool owner

### D3MMFactory
D3MMFactory is the factory contract for pool creation and registration.

### Libraries
Libraries are used to save the main contract's code size:

`D3Common` contains the shared logic for other libraries

`FundingLibrary` contains the logic code for `D3Funding`

`LiquidationLibrary` contains the logic code for `D3Liquidation`

`TradingLibrary` contains the logic code for `D3Trading`

`PMMRangeOrder` determines the price-amount curve

## Project Setup

### Install Foundry

First run the command below to get `foundryup`, the Foundry toolchain installer:

```sh
curl -L https://foundry.paradigm.xyz | bash
```

If you do not want to use the redirect, feel free to manually download the
foundryup installation script from
[here](https://raw.githubusercontent.com/gakonst/foundry/master/foundryup/install).

Then, in a new terminal session or after reloading your `PATH`, run it to get
the latest `forge` and `cast` binaries:

```sh
foundryup
```

Advanced ways to use `foundryup`, and other documentation, can be found in the
[foundryup package](./foundryup/README.md). Happy forging!

### Install Hardhat And Packages

```
yarn
```

## Commands

```sh
Scripts available via `npm run-script`:
  compile
    npx hardhat compile
  deploy
    npx hardhat deploy --network goerli
  verify
    npx hardhat verify
```
```sh
Foundry Commands
  unit tests
    forge test
  coverage
    forge coverage
```
## Adding dependency

Prefer `npm` packages when available and update the remappings.

### Example

install:
`yarn add -D @openzeppelin/contracts`

remapping:
`@openzeppelin/contracts=node_modules/@openzeppelin/contracts`

import:
`import "@openzeppelin/contracts/token/ERC20/ERC20.sol";`
