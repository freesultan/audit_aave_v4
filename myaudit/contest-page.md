 
## The initial deployment target is Ethereum mainnet


## Only explicitly whitelisted ERC20 tokens are accepted. Whitelisting is enforced via governance-controlled configuration and assumes:

ERC20 compliance without non-standard hooks (no ERC777, no callbacks).
No fee-on-transfer, rebasing, reflection, or balance-mutation side effects.
Asset onboarding follows the Aave DAO’s technical and risk due diligence process, executed by service providers before governance approval. If the tokens are incompatible with the codebase, then they won't be used.

 
## Privileged roles are trusted actors (Aave DAO and governance-approved executors). Their parameter changes are considered honest, and misconfiguration is out of scope.

That said, the codebase does enforce specific hard limits on certain configuration values:

Asset decimals: Assets must `fall within a predefined minimum (MIN_ALLOWED_UNDERLYING_DECIMALS) and maximum (MAX_ALLOWED_UNDERLYING_DECIMALS) decimal range;` assets outside these bounds cannot be listed.
Collateral risk score (collateralFactor): `Each asset’s collateral risk value is capped by a maximum allowed risk, preventing governance from setting risk scores beyond the upper bound enforced by the protocol.`
Liquidation logic: `the maximum liquidation bonus (maxLiquidationBonus) is constrained to a protocol-defined minimum`; the product of the maximum liquidation bonus and the collateral risk score is bounded by a global upper limit; and the liquidation fee (liquidationFee) itself is capped by a protocol‑defined maximum.
Beyond these explicit constraints, `most configuration values rely on governance processes` rather than on-chain caps, consistent with the “trusted admin” assumption.

 
`Protocols the system depends on (such as Chainlink price feeds, listed collateral assets, and other external primitives) are treated as trusted, governance-vetted dependencies`. Only whitelisted assets and governance-approved integrations are permitted. These components are assumed to behave consistently with their established interfaces and not introduce arbitrary semantic changes (e.g., unexpected proxy upgrades or non-standard ERC20 behavior).

`Evaluation of these dependencies (including oracle configuration, asset onboarding, and integration changes) is handled through Aave’s governance processes and risk frameworks`. Under the contest’s trust assumptions, these dependencies are considered stable, predictable, and non-malicious.

 
EIP712 is implemented for typed signatures used by the Spoke `setUserPositionManeger` intent and for all intents processed through the S`ignature Gateway`. Apart from it, no other EIP compliance requirements beyond standard ERC20 interactions for assets.
For an EIP-violation issue to be valid, it has to qualify for at least Medium severity based on the severity definitions in the "Additional audit info" question.

 

The `only off-chain dependency is Chainlink oracle infrastructure`. These feeds are assumed to operate correctly, remain available, and not deviate from expected behavior.

 
# Invariants at the the Hub level:

Total borrowed assets <= total supplied assets
Total borrowed shares == sum of Spoke debt shares
Hub added assets >= sum of Spoke added assets (converted from shares)
Hub added shares == sum of Spoke added shares
Supply share price and drawn index cannot decrease (remains constant or increases)
`Issues breaking the above invariants may be considered Medium severity even if the actual impact is Low, considering it doesn't conflict with common sense`.

 
Aave V4 adopts a `Liquidity Hub` as the `canonical accounting layer for all assets`: available liquidity, drawn and premium liabilities. User flows are implemented in external Spokes, which initiate Hub mutations and perform asset transfers. The Hub enforces global invariants and liquidity provisioning; `Spokes handle borrow logic `and risk configuration logic.

All `Spokes are governance-permissioned modules.` Governance explicitly authorizes which Spokes may call Hub mutators for each asset and maintains the allowlist.

 

The system defines an asymmetric trust model:

The Hub is the authoritative ledger.
Permissioned Spokes orchestrate user actions and decide operational details such as:
- the `source` and `destination` addresses for `ERC20 transfers` between the user and the Hub,
- when user `premium` bookkeeping occurs,
- manage `donations` within the Spoke.
- Spokes operate under Hub-enforced global invariants and `per-Spoke caps/flags` that throttle or isolate flows without halting the protocol.

 :

A malicious or compromised Spoke could misuse its privileges. E.g., drawing all the liquidity up to the draw cap and never return it. This risk is out of scope and mitigated by governance gatekeeping, since only approved Spokes can invoke Hub mutators. Hence, `**Spokes are considered trusted entities**`, working in a legit way.
 
`Each reserve receives a dynamic risk score (0–1000 %) controlled by governance`. This score feeds into the final interest rate computation resulting in a risk-adjusted rate: low-risk assets map to lower borrowing costs, and higher-risk assets incur higher effective rates.

  [Aave v4 document](https://aave.com/docs/aave-v4)
  [Aave v4 Technical Overview](https://github.com/aave/aave-v4/blob/main/docs/overview.md)
  [Aave Potential](https://governance.aave.com/t/the-potential-of-aave-v4/23150)

 
`Hub is immutable`; its `only mutable surface is through external setters (asset/spoke config) managed by governance process`.
`Spoke is upgradeable,` allowing parameter tuning or full redeployment while leaving Hub liquidity untouched.

 Critical severity:
Direct loss of funds without (extensive) limitations of external conditions. The loss of the affected party must exceed 20% and 100 USD.
Examples:

Users lose more than 20% and more than 100 USD of their principal.
Users lose more than 20% and more than 100 USD of their yield.
The protocol loses more than 20% and more than 100 USD of the fees.

High severity:
Direct loss of funds without (extensive) limitations of external conditions. The loss of the affected party must exceed 5% and 50 USD.
Examples:

Users lose more than 5% and more than 50 USD of their principal.
Users lose more than 5% and more than 50 USD of their yield.
The protocol loses more than 5% and more than 50 USD of the fees.
Medium severity:
Causes a loss of funds but requires certain external conditions or specific states, or a loss is highly constrained. The loss of the affected part must exceed 1% and 10 USD.
Breaks core contract functionality, rendering the contract useless or leading to loss of funds of the affected party that exceeds 1% and 10 USD.
Note: If a single attack can cause a 1% loss but can be replayed indefinitely, it may be considered a 100% loss and can be medium or higher severity, depending on the constraints.
Examples:

Users lose more than 1% and more than 10 USD of their principal.
Users lose more than 1% and more than 10 USD of their yield.
The protocol loses more than 1% and more than 10 USD of the fees.

Gas optimisation severity:
The report must show how the gas cost for the transaction can be reduced by 5% and the protocol team has to implement a change in the code for the issue to be considered valid. Gas optimisation severity won't have duplicates and only the first one will be considered valid.

Point weights breakdown:

A critical severity finding is worth 30 points.
A high severity finding is worth 10 points.
A medium severity finding is worth 5 points.
Gas optimisation severity doesn't get points and is a separate severity with a separate pot.