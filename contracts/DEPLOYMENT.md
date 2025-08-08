# Contract Deployment Guide

This guide explains how to deploy the contracts in this Foundry project.

## Prerequisites

1. **Foundry installed**: Make sure you have Foundry installed on your system
2. **Environment variables**: Set up your deployment configuration
3. **Network access**: Ensure you have access to the target network

## Environment Setup

Create a `.env` file in the `contracts/` directory with the following variables:

```bash
# Deployment Configuration
PRIVATE_KEY=your_private_key_here

# MultiSig Wallet Configuration
OWNER_1=0x1234567890123456789012345678901234567890
OWNER_2=0x2345678901234567890123456789012345678901
OWNER_3=0x3456789012345678901234567890123456789012
REQUIRED_CONFIRMATIONS=2

# RPC URLs (examples)
# Ethereum Mainnet
# RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
# Polygon
# RPC_URL=https://polygon-rpc.com
# Local Anvil
# RPC_URL=http://localhost:8545
```

## Deployment Commands

### 1. Deploy MultiSig Wallet

```bash
# Load environment variables and deploy
source .env && forge script script/DeployMultiSig.s.sol:DeployMultiSig \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify
```

## Network-Specific Deployment

### Local Development (Anvil)

```bash
# Start local node
anvil

# In another terminal, deploy to local network
forge script script/DeployMultiSig.s.sol:DeployMultiSig \
    --rpc-url http://localhost:8545 \
    --private-key $PRIVATE_KEY \
    --broadcast
```


## Verification

After deployment, you can verify your contracts on Etherscan (if supported by the network):

```bash
# Verify the deployed contract
forge verify-contract \
    DEPLOYED_CONTRACT_ADDRESS \
    src/MultiSigWallet.sol:MultiSigWallet \
    --etherscan-api-key YOUR_ETHERSCAN_API_KEY \
    --chain-id 1
```

## Important Notes

1. **Private Key Security**: Never commit your private key to version control
2. **Gas Estimation**: Use `--gas-estimate-multiplier` if you encounter gas estimation issues
3. **Verification**: Contract verification is network-dependent and may require API keys
4. **MultiSig Setup**: Ensure all owner addresses are valid and you have access to them

## Troubleshooting

### Common Issues

1. **Insufficient Funds**: Ensure your deployer account has enough ETH for gas
2. **RPC Issues**: Check your RPC URL and network connectivity
3. **Gas Estimation**: Some networks may require manual gas limits

### Debug Commands

```bash
# Check contract compilation
forge build

# Run tests to ensure contracts work
forge test

# Check gas usage
forge snapshot
``` 