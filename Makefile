.PHONY: help test test-all test-multisig test-counter test-verbose test-quiet test-coverage test-gas test-specific clean install-deps

# Default target
help:
	@echo "OpenBids Contract Testing Commands"
	@echo "=================================="
	@echo ""
	@echo "Test Commands:"
	@echo "  test-contracts          - Run all tests with default verbosity"
	@echo "  test-contracts-all      - Run all tests with verbose output"
	@echo "  test-contracts-multisig - Run MultiSigWallet tests only"
	@echo "  test-contracts-verbose  - Run all tests with maximum verbosity (-vvv)"
	@echo "  test-contracts-quiet    - Run all tests with minimal output (-q)"
	@echo "  test-contracts-coverage - Generate test coverage report"
	@echo "  test-contracts-gas      - Generate gas usage report"
	@echo "  test-contracts-specific - Run specific test (use TEST=testName)"
	@echo ""
	@echo "Utility Commands:"
	@echo "  install-deps-contracts  - Install Foundry dependencies"
	@echo "  clean-contracts         - Clean build artifacts"
	@echo "  help          - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make test-contracts-multisig"
	@echo "  make test-contracts-specific TEST=testConstructor"
	@echo "  make test-contracts-coverage"

# Change to contracts directory for all commands
test-contracts:
	@cd contracts && forge test

test-contracts-all:
	@cd contracts && forge test -vv

test-contracts-multisig:
	@cd contracts && forge test --match-contract MultiSigWalletTest -vv

test-contracts-verbose:
	@cd contracts && forge test -vvv

test-contracts-quiet:
	@cd contracts && forge test -q

test-contracts-coverage:
	@cd contracts && forge coverage --report lcov
	@echo "Coverage report generated in contracts/lcov.info"

test-contracts-gas:
	@cd contracts && forge test --gas-report

test-contracts-specific:
	@if [ -z "$(TEST)" ]; then \
		echo "Error: Please specify a test name using TEST=testName"; \
		echo "Example: make test-specific TEST=testConstructor"; \
		exit 1; \
	fi
	@cd contracts && forge test --match-test "$(TEST)" -vv

# Constructor tests
test-contracts-constructor:
	@cd contracts && forge test --match-test testConstructor -vv

# Integration tests
test-contracts-integration:
	@cd contracts && forge test --match-test "testCompleteWorkflow|testMultipleTransactions" -vv

# Security tests
test-contracts-security:
	@cd contracts && forge test --match-test "testConstructorInvalid|testSubmitTransactionNotOwner|testExecuteTransactionInsufficientConfirmations" -vv

# Owner management tests
test-contracts-owners:
	@cd contracts && forge test --match-test "testAddOwner|testRemoveOwner|testRequiredConfirmations" -vv

# Transaction tests
test-contracts-transactions:
	@cd contracts && forge test --match-test "testSubmitTransaction|testConfirmTransaction|testExecuteTransaction|testRevokeConfirmation" -vv

# Install dependencies
install-deps-contracts:
	@cd contracts && forge install foundry-rs/forge-std --no-commit

# Clean build artifacts
clean-contracts:
	@cd contracts && forge clean
	@echo "Build artifacts cleaned"

# Build contracts
build-contracts:
	@cd contracts && forge build

# Snapshot tests (for gas tracking)
snapshot-contracts:
	@cd contracts && forge snapshot

# Run tests with specific verbosity levels
test-contracts-v1:
	@cd contracts && forge test -v

test-contracts-v2:
	@cd contracts && forge test -vv

test-contracts-v3:
	@cd contracts && forge test -vvv

test-contracts-v4:
	@cd contracts && forge test -vvvv

# Run tests with fuzzing
test-contracts-fuzz:
	@cd contracts && forge test --fuzz-runs 1000 -vv

# Run tests with specific seed
test-contracts-seed:
	@if [ -z "$(SEED)" ]; then \
		echo "Error: Please specify a seed using SEED=12345"; \
		echo "Example: make test-seed SEED=12345"; \
		exit 1; \
	fi
	@cd contracts && forge test --fuzz-seed "$(SEED)" -vv

# Run tests and show storage layout
test-contracts-storage:
	@cd contracts && forge test --sizes

# Run tests with specific contract and show storage
test-contracts-storage-multisig:
	@cd contracts && forge test --match-contract MultiSigWalletTest --sizes

# Run tests and generate debug info
test-contracts-debug:
	@cd contracts && forge test --debug

# Run specific test with debug info
test-contracts-debug-specific:
	@if [ -z "$(TEST)" ]; then \
		echo "Error: Please specify a test name using TEST=testName"; \
		echo "Example: make test-debug-specific TEST=testConstructor"; \
		exit 1; \
	fi
	@cd contracts && forge test --match-test "$(TEST)" --debug -vv

# Run tests and show call traces
test-contracts-trace:
	@cd contracts && forge test --trace

# Run specific test with call traces
test-contracts-trace-specific:
	@if [ -z "$(TEST)" ]; then \
		echo "Error: Please specify a test name using TEST=testName"; \
		echo "Example: make test-trace-specific TEST=testConstructor"; \
		exit 1; \
	fi
	@cd contracts && forge test --match-test "$(TEST)" --trace -vv

# Run tests and show all debug info
test-contracts-full-debug:
	@cd contracts && forge test --debug --trace --verbosity 4

# Check if Foundry is installed
check-foundry-contracts:
	@if ! command -v forge &> /dev/null; then \
		echo "Foundry not found. Installing..."; \
		curl -L https://foundry.paradigm.xyz | bash; \
		echo "Please restart your terminal or run: source ~/.bashrc"; \
		exit 1; \
	else \
		echo "Foundry is installed ✓"; \
	fi

# Setup development environment
setup-contracts:
	@make check-foundry-contracts
	@make install-deps-contracts
	@make build-contracts
	@echo "Development environment setup complete ✓"

# Run all test categories
test-categories: test-constructor test-integration test-security test-owners test-transactions
	@echo "All test categories completed ✓"

# Run comprehensive test suite
test-comprehensive: test-all test-coverage test-gas
	@echo "Comprehensive test suite completed ✓"
