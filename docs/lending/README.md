# Lending

Nami Credit lets the holder of a permanent lock borrow a stable asset against it without selling or unlocking. The lock keeps voting and keeps earning, and what it earns pays the loan down. Lenders supply the asset and earn a share of that income. It runs on the hub only.

## Contracts

| Contract | Role |
|---|---|
| `LendingDiamond` | The loan. Each one is an ERC-721, and the diamond holds the debt, the fees and the market parameters. |
| `Market` | One ERC-4626 vault per asset. Lenders deposit, the diamond borrows and repays against it. |
| `LendingPositionManager` | Merges every borrower's lock into one protocol-owned position and tracks each loan's share of it. |

## How a loan works

A borrower deposits a permanent lock, or plain NAMI that the protocol locks for them. Either way the position manager folds it into a single protocol-owned position and credits the loan a proportional share. That one position is the only thing that votes or claims, so a loan is a claim on a share of it rather than a lock of its own. Only permanent locks are accepted.

Borrowing capacity comes from expected yield rather than a price oracle. The share's size and a configured yield rate set the ceiling, and the vault's utilisation cap and free cash clamp it further. Every draw adds an origination fee to the loan alongside the principal.

Servicing a loan collects what the collateral earned for an epoch and applies it in order: the protocol fee, the lenders' premium, then the loan's own fees and principal. Only once the debt is repaid in full does anything remain, and that surplus accrues to the borrower to claim. Anyone can trigger servicing, and a borrower can also repay directly at any time.

A loan closes once debt and fees are clear and an epoch has passed since it opened. The collateral splits back out as a fresh lock. Two loans held by the same owner can be merged. An admin can liquidate by repaying the loan in full and taking the collateral.

## Trust notes

- The market opens only when an admin activates it, and every parameter, the fees, the yield rate and the utilisation cap, is admin-tunable within bounds.
- Liquidation is an admin action that settles the debt in full rather than a price-triggered auction.
- Collateral is pooled into one permanent position for maximal efficiency, so a loan holds shares of it rather than a lock of its own.

## Related

- [ve](../ve/README.md), the permanent locks used as collateral
- [rewards](../rewards/README.md), the rebase and voter rewards that service a loan
- [automation](../automation/README.md), the keeper layer this module leans on
