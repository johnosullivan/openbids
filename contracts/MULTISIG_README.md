# MultiSig Wallet Contract

A secure multi-signature wallet contract built with Solidity that requires multiple owners to approve transactions before they can be executed.

## Features

- **Multi-owner support**: Add multiple owners to the wallet
- **Configurable confirmations**: Set the number of required confirmations for transactions
- **Transaction management**: Submit, confirm, and execute transactions
- **Owner management**: Add and remove owners dynamically
- **ETH support**: Send and receive ETH
- **Event logging**: Comprehensive event system for tracking all actions
- **Security**: Built-in safety checks and validations

## Contract Functions

### Core Functions

- `submitTransaction(address _to, uint256 _value, bytes memory _data)`: Submit a new transaction for approval
- `confirmTransaction(uint256 _txIndex)`: Confirm a pending transaction
- `executeTransaction(uint256 _txIndex)`: Execute a confirmed transaction
- `revokeConfirmation(uint256 _txIndex)`: Revoke a confirmation for a transaction

### Owner Management

- `addOwner(address _newOwner)`: Add a new owner to the wallet
- `removeOwner(address _ownerToRemove)`: Remove an owner from the wallet
- `changeRequiredConfirmations(uint256 _requiredConfirmations)`: Change the number of required confirmations

### View Functions

- `getTransaction(uint256 _txIndex)`: Get transaction details
- `getOwners()`: Get all owner addresses
- `getTransactionCount()`: Get the total number of transactions
- `isConfirmedBy(uint256 _txIndex, address _owner)`: Check if a transaction is confirmed by a specific owner

## Usage Example

### 1. Deploy the Contract

```solidity
// Example deployment with 3 owners requiring 2 confirmations
address[] memory owners = [
    0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6,
    0x1234567890123456789012345678901234567890,
    0xabcdefabcdefabcdefabcdefabcdefabcdefabcd
];
uint256 requiredConfirmations = 2;

MultiSigWallet multisig = new MultiSigWallet(owners, requiredConfirmations);
```

### 2. Submit a Transaction

```solidity
// Submit a transaction to send 1 ETH to a recipient
multisig.submitTransaction(recipientAddress, 1 ether, "");
```

### 3. Confirm the Transaction

```solidity
// Owner 2 confirms the transaction
multisig.confirmTransaction(0);

// Owner 3 confirms the transaction
multisig.confirmTransaction(0);
```

### 4. Execute the Transaction

```solidity
// Execute the transaction (requires sufficient confirmations)
multisig.executeTransaction(0);
```

## Testing

Run the test suite to verify the contract functionality:

```bash
forge test --match-contract MultiSigWalletTest
```

## Deployment

1. Set your private key as an environment variable:
```bash
export PRIVATE_KEY=your_private_key_here
```

2. Deploy the contract:
```bash
forge script script/DeployMultiSig.s.sol --rpc-url <your_rpc_url> --broadcast
```

## Security Considerations

- **Owner addresses**: Ensure all owner addresses are valid and secure
- **Confirmation threshold**: Set an appropriate number of required confirmations
- **Transaction data**: Verify transaction data before confirming
- **Owner removal**: Be careful when removing owners to maintain sufficient confirmations
- **Gas limits**: Consider gas limits when executing complex transactions

## Events

The contract emits the following events for tracking:

- `Deposit`: When ETH is received
- `SubmitTransaction`: When a transaction is submitted
- `ConfirmTransaction`: When a transaction is confirmed
- `RevokeConfirmation`: When a confirmation is revoked
- `ExecuteTransaction`: When a transaction is executed
- `OwnerAdded`: When a new owner is added
- `OwnerRemoved`: When an owner is removed
- `RequiredConfirmationsChanged`: When the confirmation threshold is changed

## License

MIT License 