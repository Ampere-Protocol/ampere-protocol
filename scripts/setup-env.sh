#!/bin/bash

# Setup script for Ampere Protocol Demo
# This script exports your Sui private key from the CLI and sets environment variables

echo "🔑 Ampere Protocol - Environment Setup"
echo "═══════════════════════════════════════════════"
echo ""

# Get the active address
ACTIVE_ADDRESS=$(sui client active-address)
echo "📍 Active Address: $ACTIVE_ADDRESS"
echo ""

# Export private key (in Bech32 format)
echo "🔐 Exporting private key..."
EXPORT_JSON=$(sui keytool export --key-identity "$ACTIVE_ADDRESS" --json)

# Extract the private key
PRIV_KEY=$(echo "$EXPORT_JSON" | grep -o '"exportedPrivateKey":"[^"]*"' | cut -d'"' -f4)

echo "✅ Private key exported: $PRIV_KEY"
echo ""

# Convert Bech32 to hex (for TypeScript SDK)
# Note: The SDK expects the raw 32-byte private key in hex format
echo "⚠️  Important: The SDK needs the raw hex private key."
echo "   The Bech32 format starts with 'suiprivkey1'"
echo ""
echo "To use with the demo scripts, you have two options:"
echo ""
echo "Option 1: Use sui keytool to get hex format"
echo "  sui keytool export --key-identity $ACTIVE_ADDRESS"
echo ""
echo "Option 2: Set the Bech32 key and convert in the script"
echo "  export SUI_PRIVATE_KEY='$PRIV_KEY'"
echo ""

# Create a .env file
cat > .env << EOF
# Sui Wallet Configuration
SUI_ADDRESS=$ACTIVE_ADDRESS
SUI_PRIVATE_KEY_BECH32=$PRIV_KEY

# Deployed Contract Addresses
AMPERE_PACKAGE=0xcea0d7d35eed45dc26fbd3ec0a84378bbd95d83118b501540650e267ad42bfdf
TEST_TOKENS_PACKAGE=0x29dcaea77cd8bb362a5d57249ed1b967f59215d0f5de809236615668365329c7

# Treasury Caps
USDC_TREASURY=0xe031699bcf32c5fd6c80f2911fba491c1b90056c73420fe70eed9405b2023097
USDT_TREASURY=0x2a8d421bb9f8b7e281a2d16322b2e1dfa2d286e975b8e30e2159e2a113c94a5e
LP_TREASURY_CAP=0x66e102ed0de02d1ca7f90540d2554d6bcdfe2b9d56b3760cc1431e4a6a4b848f

# Pool Configuration
POOL_ID=0x3d696725312d22e0c92305385857a9a8fe25bb85c374babd34d9536af3ca15f2
POOL_SHARED_VERSION=349181292

# Type Arguments
TYPE_A=0x29dcaea77cd8bb362a5d57249ed1b967f59215d0f5de809236615668365329c7::usdc::USDC
TYPE_B=0x29dcaea77cd8bb362a5d57249ed1b967f59215d0f5de809236615668365329c7::usdt::USDT
TYPE_C=0x2::sui::SUI
TYPE_LP=0x29dcaea77cd8bb362a5d57249ed1b967f59215d0f5de809236615668365329c7::lp::LP

# Decimals
DECIMALS_A=6
DECIMALS_B=6
DECIMALS_C=9

# RPC Configuration
SUI_RPC=https://fullnode.testnet.sui.io:443
PACKAGE_ID=0xcea0d7d35eed45dc26fbd3ec0a84378bbd95d83118b501540650e267ad42bfdf
EOF

echo "✅ Created .env file with your configuration"
echo ""
echo "📝 Next steps:"
echo "1. Source the .env file: source .env"
echo "2. Run the demo: bun run examples/mint-tokens.ts"
echo ""
echo "⚠️  Keep your private key secure and never commit .env to git!"
