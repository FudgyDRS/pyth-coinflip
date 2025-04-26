#!/bin/bash

# Load environment variables
if [ -f .env ]; then
  source .env
else
  echo "Error: .env file not found"
  exit 1
fi

# Check required environment variables
if [ -z "$SONIC_RPC" ] || [ -z "$ETHERSCAN_API_KEY" ] || [ -z "$SONIC_ETHERSCAN_ENDPOINT" ]; then
  echo "Error: Missing required environment variables."
  echo "Required: SONIC_RPC, ETHERSCAN_API_KEY, SONIC_ETHERSCAN_ENDPOINT"
  exit 1
fi

# Set contract address and path manually or pass as arguments
CONTRACT_ADDRESS=$1
CONTRACT_PATH=$2
CONTRACT_NAME=$3

if [ -z "$CONTRACT_ADDRESS" ] || [ -z "$CONTRACT_PATH" ] || [ -z "$CONTRACT_NAME" ]; then
  echo "Usage: $0 <contract_address> <contract_path> <contract_name>"
fi

# Generate standard JSON input
echo "Generating standard input JSON..."
forge verify-contract $CONTRACT_ADDRESS $CONTRACT_PATH:$CONTRACT_NAME \
  --verifier etherscan \
  --rpc-url $SONIC_RPC \
  --show-standard-json-input > standard_input.json

# Submit to Sonic explorer (Etherscan-compatible API)
echo "Submitting verification request..."
curl -X POST "$SONIC_ETHERSCAN_ENDPOINT/api" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data @standard_input.json \
  --data-urlencode "apikey=$ETHERSCAN_API_KEY"
