#!/bin/bash
# Setup script for HiveMind pre-commit hooks

set -e

echo "🔧 Setting up HiveMind pre-commit hooks..."

# Check if pre-commit is installed
if ! command -v pre-commit &> /dev/null; then
    echo "📦 Installing pre-commit..."

    # Try different installation methods
    if command -v pip &> /dev/null; then
        pip install pre-commit
    elif command -v pip3 &> /dev/null; then
        pip3 install pre-commit
    elif command -v conda &> /dev/null; then
        conda install -c conda-forge pre-commit
    elif command -v brew &> /dev/null; then
        brew install pre-commit
    else
        echo "❌ Could not install pre-commit automatically"
        echo "Please install pre-commit manually:"
        echo "  pip install pre-commit"
        echo "  or visit: https://pre-commit.com/#installation"
        exit 1
    fi
fi

# Check if lua is available
if ! command -v lua &> /dev/null; then
    echo "❌ Lua is not installed or not in PATH"
    echo "Please install Lua 5.3 or later:"
    echo "  Ubuntu/Debian: apt install lua5.3"
    echo "  macOS: brew install lua"
    echo "  Windows: Download from https://www.lua.org"
    exit 1
fi

# Install the pre-commit hooks
echo "⚙️  Installing pre-commit hooks..."
pre-commit install

echo "✅ Pre-commit setup complete!"
echo ""
echo "📋 Available commands:"
echo "  pre-commit run --all-files     # Run all hooks on all files"
echo "  pre-commit run                 # Run hooks on staged files"
echo "  pre-commit run --hook-stage manual --all-files  # Run performance tests"
echo ""
echo "🎯 Pre-commit will now automatically run tests before each commit!"
echo "   To skip pre-commit: git commit --no-verify"
