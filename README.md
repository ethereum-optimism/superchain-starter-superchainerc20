# Superchain Starter Kit: InitialSupplySuperchainERC20

> Generated from [superchain-starter](https://github.com/ethereum-optimism/superchain-starter). See the original repository for a more detailed development guide.

Example SuperchainERC20 token (contract + frontend) implementation. The frontend includes a simple bridge interface & event log viewer to see the flow funds.

<img width="1580" alt="Screenshot 2025-02-18 at 9 12 01 PM" src="https://github.com/user-attachments/assets/b891cd06-04d0-4a3a-ae78-2dcce569b3cc" />


## 🔗 Contracts

### [CrossChainMultisend.sol](./contracts/src/CrossChainMultisend.sol)

- An implementation of [SuperchainERC20](https://specs.optimism.io/interop/token-bridging.html#superchainerc20-standard)
- Uses a solady implementation of the token
- Mints initial supply to the owner on a "home chain"
- Contract can be deployed to other chains on the same address, but no new liquidity will be minted

## 📝 Overview

InitialSupplySuperchainERC20 is a SuperchainERC20-compatible token that implements a "home chain" minting model. The contract:

1. Mints the entire token supply once on a designated "home chain"
2. Can be deployed across multiple chains at the same address
3. Allows tokens to be bridged between chains using standard SuperchainERC20 mechanisms

## 🎯 Patterns

### 1. Deterministic addresses & constructor arguments using CREATE2

[SuperchainERC20](https://specs.optimism.io/interop/token-bridging.html#superchainerc20-standard:~:text=and%20crosschainBurn.-,Be%20deployed,-at%20the%20same) standard requires that the contact be deployed on the same address across multiple chains.

A pattern for achieving deterministic addresses is using CREATE2. The CREATE2 deterministic address depends on

1. deployer address
2. salt value
3. init code

#### 1. deployer address

A common practice for keeping a stable deployer address across deploys is to use a well known CREATE2 deployer that is available on every chain. Every OP Stack chain includes the following deployers as [preinstalls](https://specs.optimism.io/protocol/preinstalls.html) by default.

- [Create2Deployer](https://specs.optimism.io/protocol/preinstalls.html#create2deployer)
- [CreateX](https://specs.optimism.io/protocol/preinstalls.html#createx) - this is what super-cli `sup` uses under the hood
- [Arachnid's Deterministic Deployment Proxy](https://specs.optimism.io/protocol/preinstalls.html#arachnids-deterministic-deployment-proxy) - note this is the default CREATE2 deployer used by Foundry

#### 2. init code

The contract's `init code` consists of constructor code, arguments, and bytecode. To achieve identical addresses across chains, the constructor arguments must be exactly the same on every deployment. This consistency is maintained by passing the same values for `owner_`, `name_`, `symbol_`, `decimals_`, `initialSupply_`, and `initialSupplyChainId_` on all chains. The supply minting logic is then handled at runtime using `block.chainid`:

#### 3. salt value

The optional salt value can be specified. This is easy to keep consistent. If you ever lose it, you will be able to recover it by tracing the deploy transaction.

By keeping the above parameters constant, CREATE2 will generate identical contract addresses across all chains, satisfying the SuperchainERC20 standard's same-address requirement

#### Alternative patterns

<details>
<summary>Click to see</summary>

- Reserving nonces on an EOA then sending a CREATE1 transaction
  - This requires careful nonce management across all chains
  - More prone to errors if transactions are sent out of order
- Using a proxy pattern with an implementation contract
  - Deploy a proxy contract at a deterministic address (still using CREATE2)
  - The implementation contract can be deployed at different addresses on each chain
  - The proxy delegates all calls to the implementation

</details>

### 2. Supply management with `_initialSupplyChainId`

The constructor uses a runtime check to ensure tokens are only minted on the designated home chain:

```solidity
constructor(
    address owner_,
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    uint256 initialSupply_,
    uint256 initialSupplyChainId_
) {
    if (initialSupplyChainId_ == block.chainid) {
        _mint(owner_, initialSupply_);
    }
}
```

This approach maintains the same contract address across chains while preventing accidental supply inflation.

### 3. Implementing the ERC-7802 interface for compatibility with the SuperchainTokenBridge

`InitialSupplySuperchainERC20` uses [`SuperchainERC20`](https://github.com/ethereum-optimism/interop-lib/blob/main/src/SuperchainERC20.sol), an abstract solady implementation of the standard that follows ERC-7802.

[ERC-7802](https://ethereum-magicians.org/t/erc-7802-crosschain-token-interface/21508) is used to give the [`SuperchainTokenBridge`](https://specs.optimism.io/interop/token-bridging.html#superchainerc20bridge) the ability to mint / burn tokens.

- **crosschainMint**: Mints tokens on the destination chain as part of a cross-chain - transfer.
- **crosschainBurn**: Burns tokens on the source chain to facilitate the transfer.
- Events (**CrosschainMint** and **CrosschainBurn**): Emit when tokens are minted or burned, enabling transparent tracking of cross-chain transactions.

Under the hood, this is what happens when `x` amount of SuperchainERC20 is transferred between chains.

```mermaid

sequenceDiagram
  participant from
  participant L2SBA as SuperchainTokenBridge (Chain A)
  participant SuperERC20_A as SuperchainERC20 (Chain A)
  participant Messenger_A as L2ToL2CrossDomainMessenger (Chain A)
  participant Relayer as from (any)
  participant Messenger_B as L2ToL2CrossDomainMessenger (Chain B)
  participant L2SBB as SuperchainTokenBridge (Chain B)
  participant SuperERC20_B as SuperchainERC20 (Chain B)

  from->>L2SBA: 1. sendERC20(tokenAddr, to, amount, chainID)
  L2SBA->>SuperERC20_A: 2. crosschainBurn(from, amount)
  SuperERC20_A-->SuperERC20_A: emit CrosschainBurn(from, amount, sender)
  L2SBA->>Messenger_A: 3. sendMessage(chainId, message)
  Messenger_A->>L2SBA: return msgHash_
  L2SBA-->L2SBA: emit SentERC20(tokenAddr, from, to, amount, destination)
  L2SBA->>from: return msgHash_
  Relayer->>Messenger_B: 4. relayMessage()
  Messenger_B->>L2SBB: 5. relayERC20(tokenAddr, from, to, amount)
  L2SBB->>SuperERC20_B: 6. crosschainMint(to, amount)
  SuperERC20_B-->SuperERC20_B: emit CrosschainMint(to, amount, sender)
  L2SBB-->L2SBB: emit RelayedERC20(tokenAddr, from, to, amount, source)

```

1. `x` amount of the SuperchainERC20 is burned on the source chain by the SuperchainTokenBridge (see `2. crosschainBurn(from, amount)` in the above diagram)
2. SuperchainTokenBridge on chain A sends a message using the L2ToL2CrossDomainMessenger to the SuperchainTokenBridge on chain B. (`3. sendMessage(chainId, message)`)

3. When the message is relayed, L2ToL2CrossDomainMessenger calls the SuperchainTokenBridge on chain B with the message sent from chain A (see `5. relayERC20(tokenAddr, from, to, amount)`)
4. SuperchainTokenBridge on chain B receives the message from its counterpart on chain A, then mints `x` amount of the SuperchainERC20 to the recipient (see `6. crosschainMint(to, amount)`)

Notice the SuperchainTokenBridge needs an interface to call into the SuperchainERC20 to be able to mint / burn the tokens, which is the motivation behind ERC-7802.

The SuperchainERC20 implementation guards the `crosschainMint` and `crosschainBurn` functions to make sure that ONLY the SuperchainTokenBridge has this permission with the [following check]()

```solidity
require(msg.sender == PredeployAddresses.SUPERCHAIN_TOKEN_BRIDGE, "Unauthorized");
```

## 🚀 Getting started

### Prerequisites: Foundry & Node

Follow [this guide](https://book.getfoundry.sh/getting-started/installation) to install Foundry

### 1. Create a new repository using this template:

Click the "Use this template" button above on GitHub, or [generate directly](https://github.com/new?template_name=superchain-starter&template_owner=ethereum-optimism)

### 2. Clone your new repository

```bash
git clone <your-new-repository-url>
cd superchain-starter-initial-supply-token
```

### 3. Install dependencies

```bash
pnpm i
```

### 4. Get started

```bash
pnpm dev
```

This command will:

- Start a local Superchain network (1 L1 chain and 2 L2 chains) using [supersim](https://github.com/ethereum-optimism/supersim)
- Launch the frontend development server at (http://localhost:5173)
- Deploy the tokens all of the L2 chains in the local network

Start building on the Superchain!

## 📚 More examples, docs

- Interop recipies / guides: https://docs.optimism.io/app-developers/tutorials/interop
- Superchain Dev Console: https://console.optimism.io/

## ⚖️ License

Files are licensed under the [MIT license](./LICENSE).

<a href="./LICENSE"><img src="https://user-images.githubusercontent.com/35039927/231030761-66f5ce58-a4e9-4695-b1fe-255b1bceac92.png" alt="License information" width="200" /></a>
