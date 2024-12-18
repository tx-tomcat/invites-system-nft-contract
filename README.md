# NFT Gating Implementation

A smart contract system for implementing NFT-based access control with staking requirements and delegation support for the Moca NFT collection.

## Features

- NFT staking with time-lock verification
- Delegation system for wallet authorization
- Email registration with duplicate prevention
- Comprehensive security measures

## Technical Architecture

### Smart Contracts

- `NFTGating.sol`: Main contract handling staking, delegation, and registration
- Integration with Moca NFT collection via IERC721 interface
- Uses OpenZeppelin's security modules

### Core Components

1. **Staking System**

   - Tracks stake timestamp and status
   - Enforces 1-week minimum staking period
   - Prevents double-staking

2. **Delegation Mechanism**

   - Direct wallet-to-wallet delegation
   - Maintains delegation history
   - Integrates with registration system

3. **Email Registration**
   - Hash-based email storage for privacy
   - Single email per effective owner
   - Validates staking requirements

## Setup Instructions

### Prerequisites

- Node.js v16+
- npm or yarn
- Hardhat
- MetaMask or similar Web3 wallet

### Installation

```bash
# Clone the repository
git clone https://github.com/tx-tomcat/nft-gating.git
cd nft-gating

# Install dependencies
npm install

# Copy environment file
cp .env.example .env

# Fill in environment variables
# PRIVATE_KEY=your_private_key
# INFURA_PROJECT_ID=your_infura_id
# ETHERSCAN_API_KEY=your_etherscan_key
```

### Deployment

```bash
# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test

# Deploy to network
npx hardhat run scripts/deploy.js --network [network]
```

## Design Decisions

### 1. Single Contract Architecture

- **Decision**: Combined staking, delegation, and registration in one contract
- **Reasoning**:
  - Reduces cross-contract complexity
  - Minimizes gas costs for users
  - Simplifies state management
- **Trade-offs**:
  - Less modular
  - Larger contract size

### 2. On-chain Email Storage

- **Decision**: Store email hashes instead of plain text
- **Reasoning**:
  - Privacy protection
  - Gas efficiency
  - Immutable proof of registration
- **Trade-offs**:
  - Additional off-chain mapping needed
  - Cannot recover original email

### 3. Direct Delegation

- **Decision**: Simple delegator-to-delegate mapping
- **Reasoning**:
  - Easy to understand and verify
  - Gas efficient
  - Straightforward to implement
- **Trade-offs**:
  - Limited delegation flexibility
  - No time-based delegation

### 4. Staking Implementation

- **Decision**: NFT remains in user's wallet during staking
- **Reasoning**:
  - Better user experience
  - Lower risk for users
  - Simpler implementation
- **Trade-offs**:
  - Requires additional ownership checks
  - Slightly higher gas costs

## Testing Strategy

### Unit Tests

- Individual function testing
- Edge case verification
- Access control validation

### Integration Tests

- Full workflow testing
- Multi-user scenarios
- Network interaction verification

### Security Tests

- Reentrancy checks
- Access control verification
- Gas limit testing

## Future Improvements

### Short Term

1. Gas optimization

   - Batch operations
   - Storage optimization
   - Function optimization

2. Better Delegation
   - Time-based delegation
   - Multi-level delegation
   - Delegation limits

### Long Term

1. Infrastructure

   - Event indexing service
   - Caching layer
   - Monitoring system

2. Feature Expansion

   - Multiple NFT collection support
   - Advanced staking rewards
   - Governance integration

3. User Experience
   - Better error messages
   - Transaction status tracking
   - Gas estimation tools

## Security Considerations

2. **Data Protection**

   - Hashed email storage
   - minimal on-chain data
   - Privacy-focused design

3. **Attack Prevention**
   - Reentrancy guards
   - Input validation
   - Gas limits

## License

MIT
