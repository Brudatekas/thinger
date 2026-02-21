# ==============================================================================
# Thinger - macOS Notch Utility App
# ==============================================================================
# A macOS notch utility with:
#   - Widget display (Shelf for files/text/links)
#   - AirDrop drag-and-drop integration
# ==============================================================================

# Project Configuration
PROJECT_NAME := thinger
SCHEME_NAME := thinger
BUILD_DIR := build
CONFIGURATION := Debug

# Tool Configuration
SHELL := /bin/bash
XCBEAUTIFY := xcbeautify
SWIFTLINT := swiftlint
SWIFTFORMAT := swiftformat

# ==============================================================================
# Default & Help
# ==============================================================================

.PHONY: help
help: ## Show this help message
	@echo "Thinger - macOS Notch Utility App"
	@echo "=================================="
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Build Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help

# ==============================================================================
# Build Targets
# ==============================================================================

.PHONY: build-run build run clean

build-run: build run ## Build and run the application

build: ## Build the application
	@echo "🔨 Building $(PROJECT_NAME)..."
	set -o pipefail && xcodebuild \
		-project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME_NAME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(BUILD_DIR) \
		build | $(XCBEAUTIFY)
	@echo "✅ Build complete!"

build-release: ## Build release configuration
	@echo "🚀 Building release..."
	set -o pipefail && xcodebuild \
		-project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME_NAME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		build | $(XCBEAUTIFY)

run: ## Run the application
	@echo "🚀 Launching $(PROJECT_NAME)..."
	open $(BUILD_DIR)/Build/Products/$(CONFIGURATION)/$(PROJECT_NAME).app

clean: ## Clean build artifacts
	@echo "🧹 Cleaning build directory..."
	rm -rf $(BUILD_DIR)
	xcodebuild clean -project $(PROJECT_NAME).xcodeproj -scheme $(SCHEME_NAME) 2>/dev/null || true
	@echo "✅ Clean complete!"

# ==============================================================================
# Testing Targets
# ==============================================================================

.PHONY: test test-unit

test: test-unit ## Run all tests

test-unit: ## Run unit tests
	@echo "🧪 Running unit tests..."
	set -o pipefail && xcodebuild test \
		-project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME_NAME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(BUILD_DIR) \
		| $(XCBEAUTIFY)

# ==============================================================================
# Code Quality Targets
# ==============================================================================

.PHONY: lint format lint-fix

lint: ## Run SwiftLint
	@echo "🔍 Linting Swift code..."
	@if command -v $(SWIFTLINT) >/dev/null 2>&1; then \
		$(SWIFTLINT) lint $(PROJECT_NAME)/; \
	else \
		echo "⚠️  SwiftLint not installed. Install with: brew install swiftlint"; \
	fi

lint-fix: ## Fix linting issues automatically
	@echo "🔧 Fixing lint issues..."
	@if command -v $(SWIFTLINT) >/dev/null 2>&1; then \
		$(SWIFTLINT) lint --fix $(PROJECT_NAME)/; \
	else \
		echo "⚠️  SwiftLint not installed. Install with: brew install swiftlint"; \
	fi

format: ## Format Swift code
	@echo "✨ Formatting Swift code..."
	@if command -v $(SWIFTFORMAT) >/dev/null 2>&1; then \
		$(SWIFTFORMAT) $(PROJECT_NAME)/; \
	else \
		echo "⚠️  SwiftFormat not installed. Install with: brew install swiftformat"; \
	fi

# ==============================================================================
# Agent Observability (AI Development Tools)
# ==============================================================================

.PHONY: debug-snapshot peekaboo axe

DEBUG_OUTPUT_DIR := debug-output

debug-snapshot: peekaboo axe ## Export full app state for AI analysis
	@echo "📸 Debug snapshot complete!"
	@echo "Output saved to $(DEBUG_OUTPUT_DIR)/"
	@mkdir -p $(DEBUG_OUTPUT_DIR)
	@echo '{"app":"$(PROJECT_NAME)","timestamp":"'$$(date -u +%Y-%m-%dT%H:%M:%SZ)'","configuration":"$(CONFIGURATION)"}' > $(DEBUG_OUTPUT_DIR)/metadata.json
	@echo "✅ Snapshot includes: screenshot.png, hierarchy.json, metadata.json"

peekaboo: ## Capture screenshot of running app
	@echo "📷 Capturing screenshot..."
	@mkdir -p $(DEBUG_OUTPUT_DIR)
	@if command -v peekaboo >/dev/null 2>&1; then \
		peekaboo capture --output $(DEBUG_OUTPUT_DIR)/screenshot.png; \
	else \
		echo "⚠️  Peekaboo not installed. Run: make install-peekaboo"; \
		echo "Falling back to screencapture..."; \
		screencapture -x $(DEBUG_OUTPUT_DIR)/screenshot.png; \
	fi
	@echo "✅ Screenshot saved to $(DEBUG_OUTPUT_DIR)/screenshot.png"

axe: ## Dump accessibility hierarchy of running app
	@echo "♿ Inspecting accessibility hierarchy..."
	@mkdir -p $(DEBUG_OUTPUT_DIR)
	@if command -v axe >/dev/null 2>&1; then \
		axe dump --format json > $(DEBUG_OUTPUT_DIR)/hierarchy.json; \
		axe dump; \
	else \
		echo "⚠️  Axe not installed. Run: make install-axe"; \
		echo "Alternative: Use Xcode Accessibility Inspector"; \
	fi

# ==============================================================================
# Agent Tools Installation
# ==============================================================================

.PHONY: install-agent-tools install-peekaboo install-axe

install-agent-tools: install-peekaboo install-axe ## Install all AI agent tools
	@echo "✅ All agent tools installed!"

install-peekaboo: ## Install Peekaboo screenshot tool
	@echo "📷 Installing Peekaboo..."
	@if command -v peekaboo >/dev/null 2>&1; then \
		echo "✅ Peekaboo already installed"; \
	else \
		echo "Install Peekaboo from: https://github.com/steipete/Peekaboo"; \
		echo "Or via Homebrew: brew install steipete/formulae/peekaboo"; \
	fi

install-axe: ## Install Axe accessibility inspector
	@echo "♿ Installing Axe..."
	@if command -v axe >/dev/null 2>&1; then \
		echo "✅ Axe already installed"; \
	else \
		echo "Install Axe from: https://github.com/nicklockwood/Axe"; \
		echo "Or build from source with: swift build"; \
	fi

# ==============================================================================
# Setup & Installation
# ==============================================================================

.PHONY: setup install-tools

setup: install-tools ## Full project setup
	@echo "✅ Project setup complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Run 'make build' to build the app"
	@echo "  2. Run 'make run' to launch the app"
	@echo "  3. Run 'make help' to see all available commands"

install-tools: ## Install development tools
	@echo "🛠️ Installing development tools..."
	@command -v xcbeautify >/dev/null 2>&1 || brew install xcbeautify
	@command -v swiftlint >/dev/null 2>&1 || brew install swiftlint
	@command -v swiftformat >/dev/null 2>&1 || brew install swiftformat
	@echo "✅ Tools installed!"
