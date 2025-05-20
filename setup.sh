#!/bin/bash
set -e

# Install dependencies for Foundry
apt-get update
apt-get install -y curl build-essential pkg-config libssl-dev git clang cmake

# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
export PATH="\$HOME/.foundry/bin:\$PATH"

# Update Foundry (installs forge and cast)
~/.foundry/bin/foundryup
