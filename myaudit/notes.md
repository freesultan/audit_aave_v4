# aave v4 
## excalidraw whiteboard
[whiteboard](https://excalidraw.com/#json=uArLdwspLNqyTeyjKZksd,xgbalUTHpyC5_5OeJyZnxQ)
## Always read comments if there is refs to other protocols check if there is a problem (check forked from protocols)
## focus on pattern detection
drawnIndex(t) = drawnIndex(t-1) × (1 + drawnRate × Δtime)     
drawnRate = draw/borrow interest rate in a second

## position manager roles
- user can set a position manager as approved 
- a position manager can renounce the approval of users who has approved
- Big note: PMs have full control on users positions. 2 position managers are introduced by the protocol but any PM can be used by users although they should be approved by Governance 

## Invariants
```console
Invariants at the the Hub level:

Total borrowed assets <= total supplied assets
Total borrowed shares == sum of Spoke debt shares
Hub added assets >= sum of Spoke added assets (converted from shares)
Hub added shares == sum of Spoke added shares
Supply share price and drawn index cannot decrease (remains constant or increases)
```

### Questions
- How procotol manage risk config logic with Spokes?
- where do donations occure in spokes?

## EIP 712 meta transactions
- we use this eip in signatureGateway and  setUserPositionManagerWithSig

## Gas optimization is in scope

## points 
- Determines available actions — new borrows or collateral withdrawals `are blocked` if they would reduce the Health Factor below 1.0
- can it be a dos chance?
- 
## Dynamic config keys (Dynamic risk configuration)
- With each change in configs (Collateral Factor, Liquidation bonus, Protocol fee), the new config adds to the last configs with new config key.
- New positions use the new config but earlier positions continue to use old config
- Each reserver retains the latest `configKey` but every user position keeps snapshot of active `configKey` at the time of its last risk-increasing event (remove collateral, get loan)

`Each reserve stores the latest configKey, which represents the current up-to-date risk configuration. In contrast, every user position retains a snapshot of the active configKey corresponding to the configuration in effect at the time of its last risk-increasing event. This snapshot is refreshed across all assets of a user position only when the user performs an action which elevates the risk posed to the system, such as disabling an asset as collateral, withdrawing, or borrowing. When a user designates a new asset as collateral, only the configKey snapshot of the asset in play is refreshed.`

- This means we have more than one config and each user position has it's own config which was active scince his last risk-increasing interaction , but each reserve has the latest configKey

## after Fusaka upgrade, the limit of block and TXs have decreased. this creates new opportunities for GAS DOS now

