# Bitcoin Microloan System
A decentralized microloan platform enabling farmers to access loans using BTC as collateral.

## 🚀 Features

- Secure loan creation with BTC collateral
- Automated loan management and liquidation
- Borrower statistics tracking
- Configurable loan parameters
- Real-time loan status monitoring

## 🔒 Security Features

- Input validation for loan amounts
- Collateral ratio enforcement
- Access control checks
- Secure fund transfers
- Liquidation protection mechanisms

## 🛠 Technical Details

- Minimum loan amount: 1,000,000 µSTX
- Maximum loan amount: 100,000,000 µSTX
- Collateral ratio: 150%
- Loan duration: 144 blocks
- Liquidation penalty: 10%

## 📋 Usage Instructions

1. Deploy contract using Clarinet:
```bash
clarinet deploy
```

2. Request loan:
```bash
clarinet contract-call .request-loan [amount] [collateral]
```

3. Repay loan:
```bash
clarinet contract-call .repay-loan [loan-id]
```

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

## 💻 UI Components

- Loan Request Dashboard
- Active Loans Monitor
- Borrower Statistics Page
- Collateral Management Interface
- Loan History Tracker
