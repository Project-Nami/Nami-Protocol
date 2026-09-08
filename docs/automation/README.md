# Automation

Automation lets a holder hand a permanent lock, or plain NAMI, to a managed account. Every deposit is pooled into one shared lock that votes for all depositors at once, and each account holds a share of it. A keeper drives the weekly vote and hands each account its share of what those votes earned, so a position stays productive without its owner acting each week. Accounts live on the hub.

## Contracts

| Contract | Role |
|---|---|
| `AutomationDiamond` | The factory and the ledger. Each position is an ERC-721, and the diamond holds the configuration and the keeper entry points. |
| `AutomationAccount` | One account per position, deployed as a proxy at a deterministic address. |
| `AutomationPositionManager` | The shared lock that every deposit joins. It is the only position that votes. |

## Positions

Opening a position deposits a permanent lock, or plain NAMI, into the shared lock and mints an ERC-721 that represents the deposit. The account itself holds no lock, only shares. A position can be topped up, merged with another owned by the same address, or closed, which splits a fresh lock back out. Closing outside the voting window is possible but may forfeit an unsettled rebase.

Positions that fall below the minimum are closed by the keeper and returned to their owner rather than left holding capacity.

## Servicing

The shared lock votes once per epoch, cast by a keeper in the final hour before the epoch flips. One vote covers every depositor, so there is nothing to re-cast per account.

Once the epoch's rewards are final, a keeper distributes them to accounts in proportion to their shares. The protocol takes a configured fee, capped in the contract. Claiming the rebase is permissionless, since it only ever helps the holders.

Independently of all of this, a keeper job runs on every chain from launch to trigger fee claims on each gauge, which is what moves pool fees into voter rewards.

## Strategies

Rewards and top-ups land on the account as plain balances. A keeper can then run a strategy against it to put them to work. A strategy is a small contract that runs inside the account, so it acts on the account's own balances, and it only runs if the admin has whitelisted it. Anything a strategy produces stays on the account until it is swept to the owner.

| Strategy | What it does |
|---|---|
| Lock | Reinvests the account's NAMI into the shared position while the account is active, and wraps it into wveNami for the owner otherwise. |
| ogNami staking | Stakes the account's ogNami on the owner's behalf. |
| Swap | Converts what the account holds through an allowlisted router, so an owner can be paid out in a whitelisted token such as WETH, WBTC, USDC, USDT and more. |
| Vault | Deposits into or redeems from an allowlisted vault for the owner, within that vault's own limits, returning whatever it cannot place. |

## Trust notes

- Strategies execute inside the account, so only whitelisted strategies can run and adding one is a governance action.
- The keeper casts the shared vote and distributes rewards. It cannot move a position to itself, and closing is limited to positions under the minimum.
- Deposits are pooled into one permanent position for maximal efficiency, so an account holds shares of it rather than a lock of its own.

## Related

- [ve](../ve/README.md), the permanent locks deposited into the shared position
- [voter](../voter/README.md), where the shared position casts its vote
- [rewards](../rewards/README.md), what servicing collects
- [lending](../lending/README.md), the other module built on the shared position layer
