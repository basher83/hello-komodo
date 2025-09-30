#!/bin/bash
# Development setup script for hello-komodo

set -e

echo "🚀 Setting up hello-komodo development environment..."

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed."
    exit 1
fi

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo "⚠️  Node.js not found. Installing markdownlint-cli2 will be skipped."
    echo "   Install Node.js to enable markdown linting."
    NODE_AVAILABLE=false
else
    NODE_AVAILABLE=true
fi

echo "📦 Installing Python dependencies..."
pip install --user -r requirements.txt

if [ "$NODE_AVAILABLE" = true ]; then
    echo "📦 Installing Node.js dependencies..."
    npm install
fi

echo "🔧 Building collection..."
mkdir -p build
ansible-galaxy collection build ansible_collections/basher83/komodo/ --output-path ./build/

echo "✅ Setup complete!"
echo ""
echo "Available commands:"
echo "  🔍 ansible-lint                     # Lint Ansible files"
if [ "$NODE_AVAILABLE" = true ]; then
echo "  🔍 npm run lint:markdown            # Lint markdown files"
fi
echo "  🔍 yamllint .                       # Lint YAML files"
echo "  🏗️  ansible-galaxy collection build  # Build collection"
echo "  🧪 ansible-playbook --syntax-check  # Test playbook syntax"
echo ""
echo "📚 See README.md for more information."