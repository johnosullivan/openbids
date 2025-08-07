#!/bin/bash

# MultiSigWallet Test Runner Script
# This script helps run tests for the MultiSigWallet contract

set -e

echo "🔍 MultiSigWallet Test Suite Runner"
echo "=================================="

# Check if we're in the right directory
if [ ! -f "foundry.toml" ]; then
    echo "❌ Error: foundry.toml not found. Please run this script from the contracts directory."
    exit 1
fi

# Check if Foundry is installed
if ! command -v forge &> /dev/null; then
    echo "⚠️  Foundry not found. Installing Foundry..."
    echo "📥 Downloading and installing Foundry..."
    
    # Try to install Foundry
    if curl -L https://foundry.paradigm.xyz | bash; then
        echo "✅ Foundry installed successfully!"
        echo "🔄 Please restart your terminal or run: source ~/.bashrc"
        echo "Then run this script again."
        exit 0
    else
        echo "❌ Failed to install Foundry automatically."
        echo ""
        echo "📋 Manual installation instructions:"
        echo "1. Visit: https://getfoundry.sh"
        echo "2. Follow the installation instructions for your OS"
        echo "3. Restart your terminal"
        echo "4. Run this script again"
        exit 1
    fi
fi

echo "✅ Foundry is installed!"

# Check if dependencies are installed
echo "🔧 Checking dependencies..."
if [ ! -d "lib/forge-std" ]; then
    echo "📦 Installing dependencies..."
    forge install foundry-rs/forge-std --no-commit
fi

echo "✅ Dependencies are ready!"

# Function to run tests
run_tests() {
    local test_pattern="$1"
    local verbosity="$2"
    
    echo "🧪 Running tests..."
    echo "Pattern: $test_pattern"
    echo "Verbosity: $verbosity"
    echo ""
    
    forge test --match-contract "$test_pattern" "$verbosity"
}

# Function to run specific test
run_specific_test() {
    local test_name="$1"
    local verbosity="$2"
    
    echo "🧪 Running specific test: $test_name"
    echo "Verbosity: $verbosity"
    echo ""
    
    forge test --match-test "$test_name" "$verbosity"
}

# Function to show test coverage
show_coverage() {
    echo "📊 Generating test coverage report..."
    forge coverage --report lcov
    echo "✅ Coverage report generated!"
}

# Function to show gas report
show_gas_report() {
    echo "⛽ Generating gas report..."
    forge test --match-contract MultiSigWalletTest --gas-report
}

# Main menu
show_menu() {
    echo ""
    echo "🎯 Test Options:"
    echo "1) Run all MultiSigWallet tests (verbose)"
    echo "2) Run all MultiSigWallet tests (quiet)"
    echo "3) Run constructor tests only"
    echo "4) Run integration tests only"
    echo "5) Run security tests only"
    echo "6) Generate test coverage report"
    echo "7) Generate gas report"
    echo "8) Run specific test (interactive)"
    echo "9) Show test documentation"
    echo "0) Exit"
    echo ""
}

# Interactive menu
while true; do
    show_menu
    read -p "Select an option (0-9): " choice
    
    case $choice in
        1)
            run_tests "MultiSigWalletTest" "-vv"
            ;;
        2)
            run_tests "MultiSigWalletTest" ""
            ;;
        3)
            run_specific_test "testConstructor" "-vv"
            ;;
        4)
            run_specific_test "testCompleteWorkflow" "-vv"
            ;;
        5)
            echo "🧪 Running security-focused tests..."
            forge test --match-test "testConstructorInvalid\|testSubmitTransactionNotOwner\|testExecuteTransactionInsufficientConfirmations" -vv
            ;;
        6)
            show_coverage
            ;;
        7)
            show_gas_report
            ;;
        8)
            echo "Available test patterns:"
            echo "- testConstructor*"
            echo "- testSubmitTransaction*"
            echo "- testConfirmTransaction*"
            echo "- testExecuteTransaction*"
            echo "- testRevokeConfirmation*"
            echo "- testAddOwner*"
            echo "- testRemoveOwner*"
            echo "- testChangeRequiredConfirmations*"
            echo "- testCompleteWorkflow*"
            echo ""
            read -p "Enter test pattern: " pattern
            run_specific_test "$pattern" "-vv"
            ;;
        9)
            if [ -f "TEST_DOCUMENTATION.md" ]; then
                echo "📖 Opening test documentation..."
                if command -v bat &> /dev/null; then
                    bat TEST_DOCUMENTATION.md
                elif command -v cat &> /dev/null; then
                    cat TEST_DOCUMENTATION.md
                else
                    echo "❌ No suitable viewer found for documentation"
                fi
            else
                echo "❌ Test documentation not found"
            fi
            ;;
        0)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid option. Please select 0-9."
            ;;
    esac
    
    echo ""
    read -p "[Press Enter]"
done 