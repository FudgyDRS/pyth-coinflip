#!/bin/bash

# Load environment variables
if [ -f .env ]; then
  source .env
else
  echo "Error: .env file not found"
  exit 1
fi

# Check required environment variables
if [ -z "$SONIC_RPC" ] || [ -z "$SONIC_ETHERSCAN_ENDPOINT" ] || [ -z "$DEPLOYER_PRIVATE_KEY" ]; then
  echo "Error: Missing required environment variables. Please check your .env file."
  echo "Required: SONIC_RPC, SONIC_ETHERSCAN_ENDPOINT, DEPLOYER_PRIVATE_KEY"
  exit 1
fi

# Create output directory for deployment artifacts
mkdir -p deployments

# Deploy the contracts
echo "🚀 Starting deployment of Coinflip contract..."

DEPLOYMENT_OUTPUT=$(forge script script/deploy/deploy_coinflip.s.sol:DeployCoinflipScript \
  --rpc-url "$SONIC_RPC" \
  --private-key "$DEPLOYER_PRIVATE_KEY" \
  --broadcast \
  --via-ir \
  --slow \
  --verify \
  --etherscan-api-key "$SONIC_ETHERSCAN_ENDPOINT" \
  --verifier custom \
  -vvv)

# Extract deployed contract address
CONTRACT_ADDRESS=$(echo "$DEPLOYMENT_OUTPUT" | grep "Deployed to:" | awk '{ print $NF }')

if [ -z "$CONTRACT_ADDRESS" ]; then
  echo "❌ Error: Failed to extract contract address from deployment output."
  exit 1
fi

echo "✅ Contract deployed at: $CONTRACT_ADDRESS"

# Define contract source info
CONTRACT_PATH="src/Coinflip.sol"
CONTRACT_NAME="Coinflip"

# Generate standard input JSON
echo "🛠️  Generating standard input JSON..."
forge verify-contract "$CONTRACT_ADDRESS" "$CONTRACT_PATH:$CONTRACT_NAME" \
  --verifier etherscan \
  --rpc-url "$SONIC_RPC" \
  --show-standard-json-input > standard_input.json

# Prompt manual upload
echo ""
echo "✅ Standard input JSON saved to: standard_input.json"
echo "🔗 Please go to $SONIC_ETHERSCAN_ENDPOINT, find your contract, and use the 'Verify & Publish' feature."
echo "📎 Then paste the contents of standard_input.json when prompted."
