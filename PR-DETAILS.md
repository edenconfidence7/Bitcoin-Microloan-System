# Loan Insurance System for Borrower Protection

## Overview
This feature introduces a comprehensive Loan Insurance System that allows borrowers to purchase insurance policies to protect against liquidation penalties. The system provides a risk mitigation mechanism that reduces the financial impact of loan liquidation by up to 50% for insured borrowers.

## Technical Implementation

### Key Functions Added

#### Core Insurance Functions
- **`purchase-insurance(loan-id)`**: Allows borrowers to purchase insurance for their active loans
- **`claim-insurance(policy-id, loan-id)`**: Enables borrowers to claim coverage after liquidation
- **`liquidate-loan-with-insurance-check(loan-id)`**: Enhanced liquidation with automatic insurance protection

#### Read-Only Functions
- **`get-insurance-policy(policy-id)`**: Retrieves insurance policy details
- **`get-insurance-stats(borrower)`**: Returns borrower insurance statistics
- **`calculate-insurance-premium(loan-amount, borrower)`**: Computes dynamic premium based on credit score
- **`calculate-insurance-coverage(loan-amount)`**: Determines coverage amount for loan liquidation penalty
- **`is-insurance-valid(policy-id)`**: Validates if insurance policy is active and not expired

### Data Structures

#### Insurance Policy Map
```clarity
{
    loan-id: uint,
    borrower: principal,
    premium-paid: uint,
    coverage-amount: uint,
    start-height: uint,
    end-height: uint,
    status: (string-ascii 20),
    claimed: bool,
}
```

#### Insurance Statistics Map
```clarity
{
    total-policies: uint,
    total-premiums-paid: uint,
    total-claims: uint,
    active-policies: uint,
}
```

### Premium Calculation Algorithm
- **Base Premium**: 3% of loan amount
- **Credit Score Adjustment**: Reduces premium for borrowers with credit scores above 70
- **Maximum Premium Cap**: 8% of loan amount
- **Minimum Premium Floor**: 100,000 μSTX

### Liquidation Penalty Reduction
- **Coverage Ratio**: 50% of liquidation penalty
- **Automatic Protection**: Insurance-protected loans automatically receive reduced penalties
- **Seamless Integration**: Works with existing liquidation mechanisms

## Testing & Validation

✅ **Contract passes `clarinet check`**
- Syntax validation successful
- No compilation errors
- Clarity v3 compliant

✅ **All npm tests successful**
- Existing functionality preserved
- No breaking changes introduced
- Insurance features fully isolated

✅ **CI/CD pipeline configured**
- GitHub Actions workflow created
- Automated contract syntax checking
- Push-triggered validation

✅ **Clarity v3 compliant with proper error handling**
- Comprehensive error constants defined
- Proper data type usage (uint, principal, bool)
- Secure assertion checks throughout

## Security Features

- **Access Control**: Only loan borrowers can purchase/claim insurance
- **Validation Checks**: Multi-layer validation for policy creation and claims
- **Liquidation Protection**: Prevents double-claiming and ensures policy validity
- **Premium Security**: Secure STX transfers with contract escrow

## Independent Architecture

This insurance system is completely independent with:
- **No Cross-Contract Calls**: Self-contained within the main contract
- **No Trait Dependencies**: Direct implementation without external traits
- **Backward Compatibility**: Existing functions remain unchanged
- **Isolated Data**: Separate data maps and variables for insurance

## Statistics and Tracking

The system provides comprehensive tracking:
- Total insurance policies created
- Aggregate premiums collected
- Claim statistics and payouts
- Per-borrower insurance history