# Su (Alpha)

Su is a DeFi application designed to mint and burn coins backed by Sui with different [beta](<https://www.wikiwand.com/en/Greeks_(finance)>) values. It issues two coins:

- **fSui** - It has a beta of 0.1. When the Sui USD price goes up by 1 USD, fSui goes up by 0.1 USD.
- **xSui** - It has a variable beta value. It absorbs the price volatility of fSui to ensure it keeps a beta of 0.1.

### Run tests

```bash
  sui move test
```

### Publish

```bash
  sui client publish --gas-budget 500000000
```

## Repo Structure

- **coins:** It contains the coins used by the protocol.
  - **f_sui:** Fractional Sui coin with a beta of 0.1.
  - **x_sui:** Leveraged Sui coin with a variable beta.
  - **i_sui:** Represents an LST implementation (to be updated).
- **structs** Data structures.
  - **ema:** It keeps track of the exponential moving average of Sui
  - **su_state** It contains all the invariant logic of the protocol.
- **admin:** Contains the admin-gated functions
- **rebalance_f_pool:** A pool that redeems F_SUI to increase the CR.
- **treasury:** Controls minting/redeeming, fees logic, and balances
- **vault:** The public API to interact with Su.

### TODOS

- Replace I_SUI with an LST
- Add Events
- Tests & more tests
- Need more granular tests
