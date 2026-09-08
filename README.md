<p align="center">
  <img src="docs/_imgs/NamiCover.png" alt="Nami" width="100%">
</p>

# Nami Protocol

**Coming soon.** Nami is a d(3,3) protocol: lock NAMI into a vote-escrowed position, direct emissions to the pools you back, and earn the trading fees and incentives that follow. Voting is omnichain, so a position on any chain can vote for pools on every chain Nami runs on. Follow the launch at [nami.fi](https://nami.fi).

This repository is the public home of the protocol's contracts. Modules are published here as they go live, byte identical to the code verified on chain, each with its addresses, its audit and the tests that cover it.

## Modules

| Module | Status | What it is | Docs | Addresses |
|---|---|---|---|---|
| Batcher | Deployed on 14 chains | One smart account per user, at the same address on every supported chain. It batches operations across the protocol into a single transaction, reaching each module through versioned facets, and it is the execution layer behind OmniSwap. | [docs/batcher](docs/batcher/README.md) | [deployment/batcher.json](deployment/batcher.json) |
| Token | At launch | NAMI, minted on the hub and bridged to every spoke. wveNami, a liquid share of a pooled permanent lock. ogNami, the fixed-supply presale token, which earns 10% of trading fees. | [docs/token](docs/token/README.md) | |
| Vote escrow | At launch | Lock NAMI for a veNFT with decaying power, or a permanent iNFT with constant power that earns the rebase and can bridge between chains. | [docs/ve](docs/ve/README.md) | |
| Voter | At launch | Where positions direct emissions. A position votes on the chain it lives on and can name pools on any chain. | [docs/voter](docs/voter/README.md) | |
| Emissions | At launch | The weekly mint, its split into rebase, lock incentive and gauges, and the disputable settlement root that carries each chain and gauge its share. | [docs/emissions](docs/emissions/README.md) | |
| Rewards | At launch | Fees and bribes to voters, the rebase to permanent locks, farming incentives, and the claimer that locks a share of every claim into wveNami. | [docs/rewards](docs/rewards/README.md) | |
| Pools and gauges | At launch | Algebra concentrated-liquidity pools with Nami's plugin, one gauge per pool, and the factories that create and register them. | [docs/gauges](docs/gauges/README.md) | |
| Omnichain | At launch | The hub and spoke topology, the shared view of pool state, and the routers and adapters that move tokens, positions and messages between chains. | [docs/omnichain](docs/omnichain/README.md) | |
| Staking | At launch | Stake ogNami on Base to earn 10% of trading fees, streamed weekly as USDC. | [docs/staking](docs/staking/README.md) | |
| Lending | Later wave | Borrow a stable asset against a permanent lock without selling or unlocking it, with the lock's own earnings paying the loan down. | [docs/lending](docs/lending/README.md) | |
| Automation | Later wave | Hand a permanent lock to a managed account that votes and collects on schedule, serviced each epoch by a keeper. | [docs/automation](docs/automation/README.md) | |

The Batcher is live ahead of launch so that OmniSwap can open first. Most of the remaining modules follow at launch, and the two marked as a later wave come after that.

## Layout

- `contracts/` Solidity sources
- `test/` Foundry tests
- `deployment/` deployment details per chain
- `docs/` module documentation
- `audits/` audit reports

## Build and test

Requires [Foundry](https://book.getfoundry.sh/).

```shell
git clone --recurse-submodules <repository>
forge build
forge test
```

## Audits

- [BailSec, Core, Batcher, September 2026](audits/09_2026_BailSec_Nami_Core_Batcher.pdf)

## License

Nami Protocol is licensed under the [Business Source License 1.1](LICENSE).
