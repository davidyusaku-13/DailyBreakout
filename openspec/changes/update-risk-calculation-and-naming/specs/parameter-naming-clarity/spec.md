# Specification: Parameter Naming Clarity

**Specification ID:** `parameter-naming-clarity`  
**Related Change:** `update-risk-calculation-and-naming`  
**Status:** Draft

## MODIFIED Requirements

### Requirement: Base Lot Parameter Renamed

**ID:** `naming-base-lot`

**Description:**  
The `lot` input parameter is renamed to `base_lot` to clarify its role as the foundational lot unit used in autolot calculations. This improves code readability and intent clarity.

**Type:** Naming/Clarity

**Current Name:** `lot`  
**New Name:** `base_lot`  
**Comment:** `Base lot size for autolot calculation`

**Acceptance Criteria:**

- [ ] Input parameter definition updated: `input double base_lot = 0.01;`
- [ ] All references in `CalculateLotSize()` function updated to `base_lot`
- [ ] All print statements reference `base_lot` instead of `lot`
- [ ] No remaining references to `lot` in parameter context (except internal calculations)
- [ ] Code compiles without undefined variable warnings

#### Scenario: Autolot Calculation with base_lot

- Given: account_balance = $20,000, base_balance = 100, base_lot = 0.01
- When: lot size is calculated
- Then: lot_size = (20,000 / 100) \* 0.01 = 2.0 (scaled proportionally)

#### Scenario: Print Output Clarity

- Given: Autolot is enabled with base_lot = 0.01
- When: order is placed
- Then: Print statement shows "Base lot: 0.01" making the parameter's role clear

### Requirement: Risk Percentage Documentation

**ID:** `naming-risk-percentage-doc`

**Description:**  
The `risk_percentage` parameter documentation is updated to clearly indicate it now represents a percentage of account balance for stop loss calculation, not a percentage of the daily range.

**Type:** Documentation/Clarity

**Old Comment:** `Risk Percentage in % of the range for SL (0=off)`  
**New Comment:** `Risk Percentage of account balance for SL (0=off)`

**Acceptance Criteria:**

- [ ] Parameter comment updated to reflect balance-based calculation
- [ ] Default value reconsidered (previously 90, recommended 2 for professional risk management)
- [ ] Documentation distinguishes this from take_profit (which remains range-based)
- [ ] Related code comments throughout file updated

#### Scenario: Code Review Understanding

- Given: Developer reads input parameters
- When: They see `risk_percentage` with updated comment
- Then: They immediately understand it's balance-based, not range-based

#### Scenario: Print Logs Clarity

- Given: SL calculation is logged
- When: Debug output is printed
- Then: Context makes clear that risk is calculated as percentage of account balance

## REMOVED Requirements

### Requirement: Ambiguous Lot Parameter Name

**ID:** `naming-lot-ambiguous` (DEPRECATED)

**Description:**  
The parameter name `lot` is removed. It was ambiguous in context, particularly in the autolot calculation where it serves as a multiplier, not an absolute lot size.

```mql5
// OLD - NO LONGER USED
input double lot = 0.01;  // Lot size for each base_balance unit
```

**Reason:** Renamed to `base_lot` for clarity and intent.

## Design Rationale

### Why `base_lot`?

- **Explicit Intent:** Name immediately indicates it's a base unit for scaling
- **Context Fit:** In `balance_ratio * base_lot`, the name makes the formula self-documenting
- **Convention Alignment:** Similar to industry standards and other EA implementations
- **Searchability:** Unique name avoids conflicts with other `lot` variables

### Why Update Risk Percentage Documentation?

- **User Understanding:** Clear indication that this parameter works with account balance
- **Prevents Misuse:** Users won't try to apply range-based logic concepts
- **Professional Standard:** Establishes that the EA uses industry-standard risk management
- **Maintenance:** Future developers understand the parameter's semantic meaning

## Cross-References

- Related: `balance-based-risk-calculation` (works together with risk calculation change)
- Coordinates with: Parameter default value review

## Implementation Notes

- Simple rename throughout codebase
- No logic changes in `CalculateLotSize()` function
- Print statements need updating for consistency
- No backward compatibility (this is a breaking change)
