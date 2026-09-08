# Supported swap routers

Every OmniSwap route runs through the user's Batcher Account, and its SwapFacet will only call a router that is registered in the per-chain AddressSetRegistry. This file tracks that allowlist: which chains are wired, which aggregators serve them, and the exact contract each aggregator's calldata targets plus the contract the facet approves before the call.

Approve target is the contract the facet grants the per-call allowance to. It is the router itself except for OKX, whose DexRouter pulls tokens through a separate TokenApprove contract that must be registered as that router's approve target.

## Supported chains

| Chain | Chain id | Wrapped native | Aggregators |
|---|---|---|---|
| Ethereum | 1 | WETH `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | 15 of 15 |
| Optimism | 10 | WETH `0x4200000000000000000000000000000000000006` | 15 of 15 |
| BSC | 56 | WBNB `0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c` | 15 of 15 |
| Unichain | 130 | WETH `0x4200000000000000000000000000000000000006` | 12 of 15 |
| Polygon | 137 | WPOL `0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270` | 15 of 15 |
| Monad | 143 | WMON `0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A` | 13 of 15 |
| Sonic | 146 | wS `0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38` | 12 of 15 |
| HyperEVM | 999 | WHYPE `0x5555555555555555555555555555555555555555` | 14 of 15 |
| MegaETH | 4326 | WETH `0x4200000000000000000000000000000000000006` | 7 of 15 |
| Robinhood | 4663 | WETH `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` | 10 of 15 |
| Base | 8453 | WETH `0x4200000000000000000000000000000000000006` | 15 of 15 |
| Arbitrum | 42161 | WETH `0x82aF49447D8a07e3bd95BD0d56f35241523fBab1` | 15 of 15 |
| Avalanche | 43114 | WAVAX `0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7` | 15 of 15 |
| Berachain | 80094 | WBERA `0x6969696969696969696969696969696969696969` | 10 of 15 |

## Supported aggregators

| Aggregator | Type | Address pattern | Approve target | Not on |
|---|---|---|---|---|
| KyberSwap | Same-chain DEX aggregator | Same on every chain | Router | - |
| ParaSwap / Velora | Same-chain DEX aggregator | Same on every chain | Router | Monad, HyperEVM, MegaETH, Berachain |
| OpenOcean | Same-chain DEX aggregator | Same on every chain | Router | MegaETH, Robinhood |
| 0x | Same-chain DEX aggregator | Same on every chain | Router | MegaETH |
| 1inch | Same-chain DEX aggregator | Same on most chains, own deployment on HyperEVM and Robinhood | Router | MegaETH, Berachain |
| OKX DEX | Same-chain DEX aggregator | Per chain | TokenApprove, a separate contract | MegaETH, Berachain |
| Enso | Same-chain routing | Same on most chains, newer deployment on Monad, MegaETH and Robinhood | Router | - |
| Bebop | RFQ and solver aggregation | Same on every chain, three contracts | Router for RFQ, BalanceManager for JAM | Unichain, Monad, Sonic, MegaETH, Berachain |
| Fly.trade | Same-chain and cross-chain aggregator | Same on every chain | Router | Robinhood |
| LI.FI / Jumper | Bridge and swap aggregator | Per chain | Router | - |
| Bungee / Socket | Bridge and swap aggregator | Same on every chain | Router | Robinhood |
| Squid | Bridge and swap aggregator | Two router generations | Router | Unichain, MegaETH, Robinhood |
| Relay | Solver bridge and swaps | Same on every chain, three contracts | Router | - |
| deBridge | Solver bridge, cross-chain only | Same on every chain, two contracts | Router | Unichain, Sonic, Berachain |
| Rubic | Aggregator of aggregators | Same on every chain | Router | Sonic, MegaETH, Robinhood |

## Per chain

### Ethereum (1)

| Aggregator | Contract | Router | Approve target |
|---|---|---|---|
| KyberSwap | MetaAggregationRouterV2 | `0x6131B5fae19EA4f9D964eAc0408E4408b66337b5` | Router |
| ParaSwap / Velora | Augustus v6.2 | `0x6A000F20005980200259B80c5102003040001068` | Router |
| OpenOcean | Exchange V2 | `0x6352a56caadC4F1E25CD6c75970Fa768A3304e64` | Router |
| 0x | AllowanceHolder | `0x0000000000001fF3684f28c67538d4D072C22734` | Router |
| 1inch | AggregationRouterV6 | `0x111111125421cA6dc452d289314280a0f8842A65` | Router |
| OKX DEX | DexRouter | `0x8feAB81D36E7576107D5dE0758c1b839Be31B4F6` | `0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f` |
| OKX DEX | DexRouter (exactOut) | `0xa875Fb2204cE71679BE054d97f7fAFFeb6536D67` | `0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f` |
| Enso | Router V2 | `0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf` | Router |
| Bebop | BebopRouter (RFQ) | `0xBeb0009ACa35087ce7cCF11637E24dd1Aad3bf2A` | Router |
| Bebop | BebopSettlement (RFQ) | `0xbbbbbBB520d69a9775E85b458C58c648259FAD5F` | Router |
| Bebop | JamSettlement (aggregation) | `0xbeb0b0623f66bE8cE162EbDfA2ec543A522F4ea6` | `0xC5a350853E4e36b73EB0C24aaA4b8816C9A3579a` |
| Fly.trade | Magpie Router | `0x20f6ee51340adeed01a59b0e65cb3703f3dc860c` | Router |
| LI.FI / Jumper | Diamond | `0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE` | Router |
| Bungee / Socket | AllowanceHolder | `0x50c4E75a512F2A14A7b304787Adf79C4531A5909` | Router |
| Squid | Router | `0xce16F69375520ab01377ce7B88f5BA8C48F8D666` | Router |
| Relay | ApprovalProxy (same-chain swaps) | `0xCcC88a9d1B4ED6b0EABA998850414b24f1c315bE` | Router |
| Relay | Depository (bridge deposits) | `0x4cD00E387622C35bDDB9b4c962C136462338BC31` | Router |
| Relay | Router | `0xb92fe925DC43a0ECdE6c8b1a2709c170Ec4fFf4f` | Router |
| deBridge | CrosschainForwarder (orders with a source-side swap) | `0x663DC15D3C1aC63ff12E45Ab68FeA3F0a883C251` | Router |
| deBridge | DlnSource (order placement) | `0xeF4fB24aD0916217251F553c0596F8Edc630EB66` | Router |
| Rubic | Router | `0x3335733c454805df6a77f825f266e136FB4a3333` | Router |

### Optimism (10)

| Aggregator | Contract | Router | Approve target |
|---|---|---|---|
| KyberSwap | MetaAggregationRouterV2 | `0x6131B5fae19EA4f9D964eAc0408E4408b66337b5` | Router |
| ParaSwap / Velora | Augustus v6.2 | `0x6A000F20005980200259B80c5102003040001068` | Router |
| OpenOcean | Exchange V2 | `0x6352a56caadC4F1E25CD6c75970Fa768A3304e64` | Router |
| 0x | AllowanceHolder | `0x0000000000001fF3684f28c67538d4D072C22734` | Router |
| 1inch | AggregationRouterV6 | `0x111111125421cA6dc452d289314280a0f8842A65` | Router |
| OKX DEX | DexRouter | `0x1f5B43127414E36c31eCb5Ff5567262997CD24D0` | `0x68D6B739D2020067D1e2F713b999dA97E4d54812` |
| Enso | Router V2 | `0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf` | Router |
| Bebop | BebopRouter (RFQ) | `0xBeb0009ACa35087ce7cCF11637E24dd1Aad3bf2A` | Router |
| Bebop | BebopSettlement (RFQ) | `0xbbbbbBB520d69a9775E85b458C58c648259FAD5F` | Router |
| Bebop | JamSettlement (aggregation) | `0xbeb0b0623f66bE8cE162EbDfA2ec543A522F4ea6` | `0xC5a350853E4e36b73EB0C24aaA4b8816C9A3579a` |
| Fly.trade | Magpie Router | `0x20f6ee51340adeed01a59b0e65cb3703f3dc860c` | Router |
| LI.FI / Jumper | Diamond | `0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE` | Router |
| Bungee / Socket | AllowanceHolder | `0x50c4E75a512F2A14A7b304787Adf79C4531A5909` | Router |
| Squid | Router | `0xce16F69375520ab01377ce7B88f5BA8C48F8D666` | Router |
| Relay | ApprovalProxy (same-chain swaps) | `0xCcC88a9d1B4ED6b0EABA998850414b24f1c315bE` | Router |
| Relay | Depository (bridge deposits) | `0x4cD00E387622C35bDDB9b4c962C136462338BC31` | Router |
| Relay | Router | `0xb92fe925DC43a0ECdE6c8b1a2709c170Ec4fFf4f` | Router |
| deBridge | CrosschainForwarder (orders with a source-side swap) | `0x663DC15D3C1aC63ff12E45Ab68FeA3F0a883C251` | Router |
| deBridge | DlnSource (order placement) | `0xeF4fB24aD0916217251F553c0596F8Edc630EB66` | Router |
| Rubic | Router | `0x3335733c454805df6a77f825f266e136FB4a3333` | Router |

### BSC (56)

| Aggregator | Contract | Router | Approve target |
|---|---|---|---|
| KyberSwap | MetaAggregationRouterV2 | `0x6131B5fae19EA4f9D964eAc0408E4408b66337b5` | Router |
| ParaSwap / Velora | Augustus v6.2 | `0x6A000F20005980200259B80c5102003040001068` | Router |
| OpenOcean | Exchange V2 | `0x6352a56caadC4F1E25CD6c75970Fa768A3304e64` | Router |
| 0x | AllowanceHolder | `0x0000000000001fF3684f28c67538d4D072C22734` | Router |
| 1inch | AggregationRouterV6 | `0x111111125421cA6dc452d289314280a0f8842A65` | Router |
| OKX DEX | DexRouter | `0x5994814f2C4040b863A0125A45DE152a8c2A4DEc` | `0x2c34A2Fb1d0b4f55de51E1d0bDEfaDDce6b7cDD6` |
| Enso | Router V2 | `0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf` | Router |
| Bebop | BebopRouter (RFQ) | `0xBeb0009ACa35087ce7cCF11637E24dd1Aad3bf2A` | Router |
| Bebop | BebopSettlement (RFQ) | `0xbbbbbBB520d69a9775E85b458C58c648259FAD5F` | Router |
| Bebop | JamSettlement (aggregation) | `0xbeb0b0623f66bE8cE162EbDfA2ec543A522F4ea6` | `0xC5a350853E4e36b73EB0C24aaA4b8816C9A3579a` |
| Fly.trade | Magpie Router | `0x20f6ee51340adeed01a59b0e65cb3703f3dc860c` | Router |
| LI.FI / Jumper | Diamond | `0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE` | Router |
| Bungee / Socket | AllowanceHolder | `0x50c4E75a512F2A14A7b304787Adf79C4531A5909` | Router |
| Squid | Router | `0xce16F69375520ab01377ce7B88f5BA8C48F8D666` | Router |
| Relay | ApprovalProxy (same-chain swaps) | `0xCcC88a9d1B4ED6b0EABA998850414b24f1c315bE` | Router |
| Relay | Depository (bridge deposits) | `0x4cD00E387622C35bDDB9b4c962C136462338BC31` | Router |
| Relay | Router | `0xb92fe925DC43a0ECdE6c8b1a2709c170Ec4fFf4f` | Router |
| deBridge | CrosschainForwarder (orders with a source-side swap) | `0x663DC15D3C1aC63ff12E45Ab68FeA3F0a883C251` | Router |
| deBridge | DlnSource (order placement) | `0xeF4fB24aD0916217251F553c0596F8Edc630EB66` | Router |
| Rubic | Router | `0x3335733c454805df6a77f825f266e136FB4a3333` | Router |

### Unichain (130)

| Aggregator | Contract | Router | Approve target |
|---|---|---|---|
| KyberSwap | MetaAggregationRouterV2 | `0x6131B5fae19EA4f9D964eAc0408E4408b66337b5` | Router |
| ParaSwap / Velora | Augustus v6.2 | `0x6A000F20005980200259B80c5102003040001068` | Router |
| OpenOcean | Exchange V2 | `0x6352a56caadC4F1E25CD6c75970Fa768A3304e64` | Router |
| 0x | AllowanceHolder | `0x0000000000001fF3684f28c67538d4D072C22734` | Router |
| 1inch | AggregationRouterV6 | `0x111111125421cA6dc452d289314280a0f8842A65` | Router |
| OKX DEX | DexRouter | `0xe3dAb8Bf5187F9B4E8E89FF5414D7CF71E2C82e1` | `0x2e28281Cf3D58f475cebE27bec4B8a23dFC7782c` |
| Enso | Router V2 | `0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf` | Router |
| Fly.trade | Magpie Router | `0x20f6ee51340adeed01a59b0e65cb3703f3dc860c` | Router |
| LI.FI / Jumper | Diamond | `0x864b314D4C5a0399368609581d3E8933a63b9232` | Router |
| Bungee / Socket | AllowanceHolder | `0x50c4E75a512F2A14A7b304787Adf79C4531A5909` | Router |
| Relay | ApprovalProxy (same-chain swaps) | `0xCcC88a9d1B4ED6b0EABA998850414b24f1c315bE` | Router |
| Relay | Depository (bridge deposits) | `0x4cD00E387622C35bDDB9b4c962C136462338BC31` | Router |
| Relay | Router | `0xb92fe925DC43a0ECdE6c8b1a2709c170Ec4fFf4f` | Router |
| Rubic | Router | `0x3335733c454805df6a77f825f266e136FB4a3333` | Router |

### Polygon (137)

| Aggregator | Contract | Router | Approve target |
|---|---|---|---|
| KyberSwap | MetaAggregationRouterV2 | `0x6131B5fae19EA4f9D964eAc0408E4408b66337b5` | Router |
| ParaSwap / Velora | Augustus v6.2 | `0x6A000F20005980200259B80c5102003040001068` | Router |
| OpenOcean | Exchange V2 | `0x6352a56caadC4F1E25CD6c75970Fa768A3304e64` | Router |
| 0x | AllowanceHolder | `0x0000000000001fF3684f28c67538d4D072C22734` | Router |
| 1inch | AggregationRouterV6 | `0x111111125421cA6dc452d289314280a0f8842A65` | Router |
| OKX DEX | DexRouter | `0x3C4829196BFadFF4394726b45159aeaAC6FCd41c` | `0x3B86917369B83a6892f553609F3c2F439C184e31` |
| Enso | Router V2 | `0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf` | Router |
| Bebop | BebopRouter (RFQ) | `0xBeb0009ACa35087ce7cCF11637E24dd1Aad3bf2A` | Router |
| Bebop | BebopSettlement (RFQ) | `0xbbbbbBB520d69a9775E85b458C58c648259FAD5F` | Router |
| Bebop | JamSettlement (aggregation) | `0xbeb0b0623f66bE8cE162EbDfA2ec543A522F4ea6` | `0xC5a350853E4e36b73EB0C24aaA4b8816C9A3579a` |
| Fly.trade | Magpie Router | `0x20f6ee51340adeed01a59b0e65cb3703f3dc860c` | Router |
| LI.FI / Jumper | Diamond | `0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE` | Router |
| Bungee / Socket | AllowanceHolder | `0x50c4E75a512F2A14A7b304787Adf79C4531A5909` | Router |
| Squid | Router | `0xce16F69375520ab01377ce7B88f5BA8C48F8D666` | Router |
| Relay | ApprovalProxy (same-chain swaps) | `0xCcC88a9d1B4ED6b0EABA998850414b24f1c315bE` | Router |
| Relay | Depository (bridge deposits) | `0x4cD00E387622C35bDDB9b4c962C136462338BC31` | Router |
| Relay | Router | `0xb92fe925DC43a0ECdE6c8b1a2709c170Ec4fFf4f` | Router |
| deBridge | CrosschainForwarder (orders with a source-side swap) | `0x663DC15D3C1aC63ff12E45Ab68FeA3F0a883C251` | Router |
| deBridge | DlnSource (order placement) | `0xeF4fB24aD0916217251F553c0596F8Edc630EB66` | Router |
| Rubic | Router | `0x3335733c454805df6a77f825f266e136FB4a3333` | Router |

### Monad (143)

| Aggregator | Contract | Router | Approve target |
|---|---|---|---|
| KyberSwap | MetaAggregationRouterV2 | `0x6131B5fae19EA4f9D964eAc0408E4408b66337b5` | Router |
| OpenOcean | Exchange V2 | `0x6352a56caadC4F1E25CD6c75970Fa768A3304e64` | Router |
| 0x | AllowanceHolder | `0x0000000000001fF3684f28c67538d4D072C22734` | Router |
| 1inch | AggregationRouterV6 | `0x111111125421cA6dc452d289314280a0f8842A65` | Router |
| OKX DEX | DexRouter | `0xc1C76E784Db8D68585fb608ce68FC5DcFF14000E` | `0xf534A8a1CAD0543Cd6438f7534CA3486c01998d4` |
| Enso | Router V2 (newer deployment) | `0xCfBAa9Cfce952Ca4F4069874fF1Df8c05e37a3c7` | Router |
| Fly.trade | Magpie Router | `0x20f6ee51340adeed01a59b0e65cb3703f3dc860c` | Router |
| LI.FI / Jumper | Diamond | `0x026F252016A7C47CDEf1F05a3Fc9E20C92a49C37` | Router |
| Bungee / Socket | AllowanceHolder | `0x50c4E75a512F2A14A7b304787Adf79C4531A5909` | Router |
| Squid | Router (newer deployment) | `0x2B4d4Cf15dAD79D3426D19674Bd237C1dc9144aa` | Router |
| Relay | ApprovalProxy (same-chain swaps) | `0xCcC88a9d1B4ED6b0EABA998850414b24f1c315bE` | Router |
| Relay | Depository (bridge deposits) | `0x4cD00E387622C35bDDB9b4c962C136462338BC31` | Router |
| Relay | Router | `0xb92fe925DC43a0ECdE6c8b1a2709c170Ec4fFf4f` | Router |
| deBridge | CrosschainForwarder (orders with a source-side swap) | `0x663DC15D3C1aC63ff12E45Ab68FeA3F0a883C251` | Router |
| deBridge | DlnSource (order placement) | `0xeF4fB24aD0916217251F553c0596F8Edc630EB66` | Router |
| Rubic | Router | `0x3335733c454805df6a77f825f266e136FB4a3333` | Router |

### Sonic (146)

| Aggregator | Contract | Router | Approve target |
|---|---|---|---|
| KyberSwap | MetaAggregationRouterV2 | `0x6131B5fae19EA4f9D964eAc0408E4408b66337b5` | Router |
| ParaSwap / Velora | Augustus v6.2 | `0x6A000F20005980200259B80c5102003040001068` | Router |
| OpenOcean | Exchange V2 | `0x6352a56caadC4F1E25CD6c75970Fa768A3304e64` | Router |
| 0x | AllowanceHolder | `0x0000000000001fF3684f28c67538d4D072C22734` | Router |
| 1inch | AggregationRouterV6 | `0x111111125421cA6dc452d289314280a0f8842A65` | Router |
| OKX DEX | DexRouter | `0xd72f9Af181A0eB1B8550a00124ECdb71Bb758C89` | `0xD321ab5589d3E8FA5Df985ccFEf625022E2DD910` |
| Enso | Router V2 | `0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf` | Router |
| Fly.trade | Magpie Router | `0x20f6ee51340adeed01a59b0e65cb3703f3dc860c` | Router |
| LI.FI / Jumper | Diamond | `0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE` | Router |
| Bungee / Socket | AllowanceHolder | `0x50c4E75a512F2A14A7b304787Adf79C4531A5909` | Router |
| Squid | Router (newer deployment) | `0x2B4d4Cf15dAD79D3426D19674Bd237C1dc9144aa` | Router |
| Relay | ApprovalProxy (same-chain swaps) | `0xCcC88a9d1B4ED6b0EABA998850414b24f1c315bE` | Router |
| Relay | Depository (bridge deposits) | `0x4cD00E387622C35bDDB9b4c962C136462338BC31` | Router |
| Relay | Router | `0xb92fe925DC43a0ECdE6c8b1a2709c170Ec4fFf4f` | Router |

### HyperEVM (999)

| Aggregator | Contract | Router | Approve target |
|---|---|---|---|
| KyberSwap | MetaAggregationRouterV2 | `0x6131B5fae19EA4f9D964eAc0408E4408b66337b5` | Router |
| OpenOcean | Exchange V2 | `0x6352a56caadC4F1E25CD6c75970Fa768A3304e64` | Router |
| 0x | AllowanceHolder | `0x0000000000001fF3684f28c67538d4D072C22734` | Router |
| 1inch | AggregationRouterV6 (HyperEVM deployment) | `0x5281602aDc446A94eb48D055f514A6d8D5bee176` | Router |
| OKX DEX | DexRouter | `0xb193874f0C77948d2bCFeC2EfAF8Bc65B4C2ca89` | `0x56e6983D59bF472Ced0E63966A14d94A3A291589` |
| Enso | Router V2 | `0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf` | Router |
| Bebop | BebopRouter (RFQ) | `0xBeb0009ACa35087ce7cCF11637E24dd1Aad3bf2A` | Router |
| Bebop | BebopSettlement (RFQ) | `0xbbbbbBB520d69a9775E85b458C58c648259FAD5F` | Router |
| Bebop | JamSettlement (aggregation) | `0xbeb0b0623f66bE8cE162EbDfA2ec543A522F4ea6` | `0xC5a350853E4e36b73EB0C24aaA4b8816C9A3579a` |
| Fly.trade | Magpie Router | `0x20f6ee51340adeed01a59b0e65cb3703f3dc860c` | Router |
| LI.FI / Jumper | Diamond | `0x0a0758d937d1059c356D4714e57F5df0239bce1A` | Router |
| Bungee / Socket | AllowanceHolder | `0x50c4E75a512F2A14A7b304787Adf79C4531A5909` | Router |
| Squid | Router (newer deployment) | `0x2B4d4Cf15dAD79D3426D19674Bd237C1dc9144aa` | Router |
| Relay | ApprovalProxy (same-chain swaps) | `0xCcC88a9d1B4ED6b0EABA998850414b24f1c315bE` | Router |
| Relay | Depository (bridge deposits) | `0x4cD00E387622C35bDDB9b4c962C136462338BC31` | Router |
| Relay | Router | `0xb92fe925DC43a0ECdE6c8b1a2709c170Ec4fFf4f` | Router |
| deBridge | CrosschainForwarder (orders with a source-side swap) | `0x663DC15D3C1aC63ff12E45Ab68FeA3F0a883C251` | Router |
| deBridge | DlnSource (order placement) | `0xeF4fB24aD0916217251F553c0596F8Edc630EB66` | Router |
| Rubic | Router | `0x3335733c454805df6a77f825f266e136FB4a3333` | Router |

### MegaETH (4326)

| Aggregator | Contract | Router | Approve target |
|---|---|---|---|
| KyberSwap | MetaAggregationRouterV2 | `0x6131B5fae19EA4f9D964eAc0408E4408b66337b5` | Router |
| Enso | Router V2 (newer deployment) | `0xCfBAa9Cfce952Ca4F4069874fF1Df8c05e37a3c7` | Router |
| Fly.trade | Magpie Router | `0x20f6ee51340adeed01a59b0e65cb3703f3dc860c` | Router |
| LI.FI / Jumper | Diamond | `0x026F252016A7C47CDEf1F05a3Fc9E20C92a49C37` | Router |
| Bungee / Socket | AllowanceHolder | `0x50c4E75a512F2A14A7b304787Adf79C4531A5909` | Router |
| Relay | ApprovalProxy (same-chain swaps) | `0xCcC88a9d1B4ED6b0EABA998850414b24f1c315bE` | Router |
| Relay | Depository (bridge deposits) | `0x4cD00E387622C35bDDB9b4c962C136462338BC31` | Router |
| Relay | Router | `0xb92fe925DC43a0ECdE6c8b1a2709c170Ec4fFf4f` | Router |
| deBridge | CrosschainForwarder (orders with a source-side swap) | `0x663DC15D3C1aC63ff12E45Ab68FeA3F0a883C251` | Router |
| deBridge | DlnSource (order placement) | `0xeF4fB24aD0916217251F553c0596F8Edc630EB66` | Router |

### Robinhood (4663)

| Aggregator | Contract | Router | Approve target |
|---|---|---|---|
| KyberSwap | MetaAggregationRouterV2 | `0x6131B5fae19EA4f9D964eAc0408E4408b66337b5` | Router |
| ParaSwap / Velora | Augustus v6.2 | `0x6A000F20005980200259B80c5102003040001068` | Router |
| 0x | AllowanceHolder | `0x0000000000001fF3684f28c67538d4D072C22734` | Router |
| 1inch | Router (Robinhood deployment) | `0x5A705DE8982235a7fa45bB83dCaCf03a211389C7` | Router |
| OKX DEX | DexRouter | `0x6e2A35A7AD683cF634D91492d73bb7FF774c6919` | `0x42170295F1173c9e5874ea9d00c6d137E1a4f53d` |
| Enso | Router V2 (newer deployment) | `0xCfBAa9Cfce952Ca4F4069874fF1Df8c05e37a3c7` | Router |
| Bebop | BebopRouter (RFQ) | `0xBeb0009ACa35087ce7cCF11637E24dd1Aad3bf2A` | Router |
| Bebop | BebopSettlement (RFQ) | `0xbbbbbBB520d69a9775E85b458C58c648259FAD5F` | Router |
| LI.FI / Jumper | Diamond | `0xB477751B76CF82d00a686A1232f5fCD772414Af3` | Router |
| Relay | ApprovalProxy (same-chain swaps) | `0xCcC88a9d1B4ED6b0EABA998850414b24f1c315bE` | Router |
| Relay | Depository (bridge deposits) | `0x4cD00E387622C35bDDB9b4c962C136462338BC31` | Router |
| Relay | Router | `0xb92fe925DC43a0ECdE6c8b1a2709c170Ec4fFf4f` | Router |
| deBridge | CrosschainForwarder (orders with a source-side swap) | `0x663DC15D3C1aC63ff12E45Ab68FeA3F0a883C251` | Router |
| deBridge | DlnSource (order placement) | `0xeF4fB24aD0916217251F553c0596F8Edc630EB66` | Router |

### Base (8453)

| Aggregator | Contract | Router | Approve target |
|---|---|---|---|
| KyberSwap | MetaAggregationRouterV2 | `0x6131B5fae19EA4f9D964eAc0408E4408b66337b5` | Router |
| ParaSwap / Velora | Augustus v6.2 | `0x6A000F20005980200259B80c5102003040001068` | Router |
| OpenOcean | Exchange V2 | `0x6352a56caadC4F1E25CD6c75970Fa768A3304e64` | Router |
| 0x | AllowanceHolder | `0x0000000000001fF3684f28c67538d4D072C22734` | Router |
| 1inch | AggregationRouterV6 | `0x111111125421cA6dc452d289314280a0f8842A65` | Router |
| OKX DEX | DexRouter | `0x67d03631FE51B741C0C00c4E16eb662AC84381df` | `0x57df6092665eb6058DE53939612413ff4B09114E` |
| OKX DEX | DexRouter (exactOut) | `0x77449Ff075C0A385796Da0762BCB46fd5cc884c6` | `0x57df6092665eb6058DE53939612413ff4B09114E` |
| Enso | Router V2 | `0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf` | Router |
| Bebop | BebopRouter (RFQ) | `0xBeb0009ACa35087ce7cCF11637E24dd1Aad3bf2A` | Router |
| Bebop | BebopSettlement (RFQ) | `0xbbbbbBB520d69a9775E85b458C58c648259FAD5F` | Router |
| Bebop | JamSettlement (aggregation) | `0xbeb0b0623f66bE8cE162EbDfA2ec543A522F4ea6` | `0xC5a350853E4e36b73EB0C24aaA4b8816C9A3579a` |
| Fly.trade | Magpie Router | `0x20f6ee51340adeed01a59b0e65cb3703f3dc860c` | Router |
| LI.FI / Jumper | Diamond | `0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE` | Router |
| Bungee / Socket | AllowanceHolder | `0x50c4E75a512F2A14A7b304787Adf79C4531A5909` | Router |
| Squid | Router | `0xce16F69375520ab01377ce7B88f5BA8C48F8D666` | Router |
| Relay | ApprovalProxy (same-chain swaps) | `0xCcC88a9d1B4ED6b0EABA998850414b24f1c315bE` | Router |
| Relay | Depository (bridge deposits) | `0x4cD00E387622C35bDDB9b4c962C136462338BC31` | Router |
| Relay | Router | `0xb92fe925DC43a0ECdE6c8b1a2709c170Ec4fFf4f` | Router |
| deBridge | CrosschainForwarder (orders with a source-side swap) | `0x663DC15D3C1aC63ff12E45Ab68FeA3F0a883C251` | Router |
| deBridge | DlnSource (order placement) | `0xeF4fB24aD0916217251F553c0596F8Edc630EB66` | Router |
| Rubic | Router | `0x3335733c454805df6a77f825f266e136FB4a3333` | Router |

### Arbitrum (42161)

| Aggregator | Contract | Router | Approve target |
|---|---|---|---|
| KyberSwap | MetaAggregationRouterV2 | `0x6131B5fae19EA4f9D964eAc0408E4408b66337b5` | Router |
| ParaSwap / Velora | Augustus v6.2 | `0x6A000F20005980200259B80c5102003040001068` | Router |
| OpenOcean | Exchange V2 | `0x6352a56caadC4F1E25CD6c75970Fa768A3304e64` | Router |
| 0x | AllowanceHolder | `0x0000000000001fF3684f28c67538d4D072C22734` | Router |
| 1inch | AggregationRouterV6 | `0x111111125421cA6dc452d289314280a0f8842A65` | Router |
| OKX DEX | DexRouter | `0x09f94b5Fc68e227C323A6FbaE3Bd98C97fD8c849` | `0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58` |
| OKX DEX | DexRouter (exactOut) | `0x9736d9a45115E33411390EbD54e5A5C3A6E25aA6` | `0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58` |
| Enso | Router V2 | `0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf` | Router |
| Bebop | BebopRouter (RFQ) | `0xBeb0009ACa35087ce7cCF11637E24dd1Aad3bf2A` | Router |
| Bebop | BebopSettlement (RFQ) | `0xbbbbbBB520d69a9775E85b458C58c648259FAD5F` | Router |
| Bebop | JamSettlement (aggregation) | `0xbeb0b0623f66bE8cE162EbDfA2ec543A522F4ea6` | `0xC5a350853E4e36b73EB0C24aaA4b8816C9A3579a` |
| Fly.trade | Magpie Router | `0x20f6ee51340adeed01a59b0e65cb3703f3dc860c` | Router |
| LI.FI / Jumper | Diamond | `0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE` | Router |
| Bungee / Socket | AllowanceHolder | `0x50c4E75a512F2A14A7b304787Adf79C4531A5909` | Router |
| Squid | Router | `0xce16F69375520ab01377ce7B88f5BA8C48F8D666` | Router |
| Relay | ApprovalProxy (same-chain swaps) | `0xCcC88a9d1B4ED6b0EABA998850414b24f1c315bE` | Router |
| Relay | Depository (bridge deposits) | `0x4cD00E387622C35bDDB9b4c962C136462338BC31` | Router |
| Relay | Router | `0xb92fe925DC43a0ECdE6c8b1a2709c170Ec4fFf4f` | Router |
| deBridge | CrosschainForwarder (orders with a source-side swap) | `0x663DC15D3C1aC63ff12E45Ab68FeA3F0a883C251` | Router |
| deBridge | DlnSource (order placement) | `0xeF4fB24aD0916217251F553c0596F8Edc630EB66` | Router |
| Rubic | Router | `0x3335733c454805df6a77f825f266e136FB4a3333` | Router |

### Avalanche (43114)

| Aggregator | Contract | Router | Approve target |
|---|---|---|---|
| KyberSwap | MetaAggregationRouterV2 | `0x6131B5fae19EA4f9D964eAc0408E4408b66337b5` | Router |
| ParaSwap / Velora | Augustus v6.2 | `0x6A000F20005980200259B80c5102003040001068` | Router |
| OpenOcean | Exchange V2 | `0x6352a56caadC4F1E25CD6c75970Fa768A3304e64` | Router |
| 0x | AllowanceHolder | `0x0000000000001fF3684f28c67538d4D072C22734` | Router |
| 1inch | AggregationRouterV6 | `0x111111125421cA6dc452d289314280a0f8842A65` | Router |
| OKX DEX | DexRouter | `0xAB96dcFA7A7D669d9BF5918faB8641479973dD0A` | `0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f` |
| Enso | Router V2 | `0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf` | Router |
| Bebop | JamSettlement (aggregation) | `0xbeb0b0623f66bE8cE162EbDfA2ec543A522F4ea6` | `0xC5a350853E4e36b73EB0C24aaA4b8816C9A3579a` |
| Fly.trade | Magpie Router | `0x20f6ee51340adeed01a59b0e65cb3703f3dc860c` | Router |
| LI.FI / Jumper | Diamond | `0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE` | Router |
| Bungee / Socket | AllowanceHolder | `0x50c4E75a512F2A14A7b304787Adf79C4531A5909` | Router |
| Squid | Router | `0xce16F69375520ab01377ce7B88f5BA8C48F8D666` | Router |
| Relay | ApprovalProxy (same-chain swaps) | `0xCcC88a9d1B4ED6b0EABA998850414b24f1c315bE` | Router |
| Relay | Depository (bridge deposits) | `0x4cD00E387622C35bDDB9b4c962C136462338BC31` | Router |
| Relay | Router | `0xb92fe925DC43a0ECdE6c8b1a2709c170Ec4fFf4f` | Router |
| deBridge | CrosschainForwarder (orders with a source-side swap) | `0x663DC15D3C1aC63ff12E45Ab68FeA3F0a883C251` | Router |
| deBridge | DlnSource (order placement) | `0xeF4fB24aD0916217251F553c0596F8Edc630EB66` | Router |
| Rubic | Router | `0x3335733c454805df6a77f825f266e136FB4a3333` | Router |

### Berachain (80094)

| Aggregator | Contract | Router | Approve target |
|---|---|---|---|
| KyberSwap | MetaAggregationRouterV2 | `0x6131B5fae19EA4f9D964eAc0408E4408b66337b5` | Router |
| OpenOcean | Exchange V2 | `0x6352a56caadC4F1E25CD6c75970Fa768A3304e64` | Router |
| 0x | AllowanceHolder | `0x0000000000001fF3684f28c67538d4D072C22734` | Router |
| Enso | Router V2 | `0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf` | Router |
| Fly.trade | Magpie Router | `0x20f6ee51340adeed01a59b0e65cb3703f3dc860c` | Router |
| LI.FI / Jumper | Diamond | `0xf909c4Ae16622898b885B89d7F839E0244851c66` | Router |
| Bungee / Socket | AllowanceHolder | `0x50c4E75a512F2A14A7b304787Adf79C4531A5909` | Router |
| Squid | Router (newer deployment) | `0x2B4d4Cf15dAD79D3426D19674Bd237C1dc9144aa` | Router |
| Relay | ApprovalProxy (same-chain swaps) | `0xCcC88a9d1B4ED6b0EABA998850414b24f1c315bE` | Router |
| Relay | Depository (bridge deposits) | `0x4cD00E387622C35bDDB9b4c962C136462338BC31` | Router |
| Relay | Router | `0xb92fe925DC43a0ECdE6c8b1a2709c170Ec4fFf4f` | Router |
| Rubic | Router | `0x3335733c454805df6a77f825f266e136FB4a3333` | Router |
