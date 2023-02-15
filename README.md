Compound Protocol Foundry tests
=================

This repo has Foundry frameworks tests for the Compound protocol as a learning tool.
Tests cover main protocol usages as supply and redemption of tokens and borrowing, via the usage of a Contract (SupplyTokenCompound). 
Tests are run against a local Ethereum mainnet fork.

Usage
=================
To launch tests follow the steps below:

* create a .env file with an RPC_URL env variable in it whose value is your Ethereum mainnet rpc endpoint url (for example via Infura or Alchemy)
* launch tests by executing: `forge test --fork-url $RPC_URL -vvv`
