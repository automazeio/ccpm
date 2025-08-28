# CCPM - Cross-Platform Command Project Manager
# Makefile for cross-platform development, testing, and installation

# Detect operating system
UNAME_S := $(shell uname -s 2>/dev/null || echo Windows)
UNAME_M := $(shell uname -m 2>/dev/null || echo unknown)

# Platform-specific variables
# Check for Windows in multiple ways (native Windows, Git Bash, MSYS2, etc.)
# Prefer MSYS/MINGW (Git Bash) detection first; fall back to native Windows
ifneq ($(findstring MINGW,$(UNAME_S)),)
    PLATFORM := windows
    NATIVE_WINDOWS := false
else ifneq ($(findstring MSYS,$(UNAME_S)),)
    PLATFORM := windows
    NATIVE_WINDOWS := false
else ifeq ($(OS),Windows_NT)
    PLATFORM := windows
    NATIVE_WINDOWS := true
else
    ifeq ($(UNAME_S),Darwin)
        PLATFORM := macos
    else ifeq ($(UNAME_S),Linux)
        PLATFORM := linux
    else
        PLATFORM := unix
    endif
    NATIVE_WINDOWS := false
endif

# Set platform-specific variables
ifeq ($(PLATFORM),windows)
    SHELL_EXT := .bat
    PYTHON := python
    # Use forward slashes for Git Bash compatibility even on Windows
    PATH_SEP := /
    ifeq ($(NATIVE_WINDOWS),true)
        DELETE_CMD := del /q
        DELETE_DIR_CMD := rmdir /s /q
        NULL_DEVICE := nul
    else
        # Git Bash environment
        DELETE_CMD := rm -f
        DELETE_DIR_CMD := rm -rf
        NULL_DEVICE := /dev/null
    endif
else
    SHELL_EXT := .sh
    DELETE_CMD := rm -f
    DELETE_DIR_CMD := rm -rf
    NULL_DEVICE := /dev/null
    PYTHON := python3
    PATH_SEP := /
    NATIVE_WINDOWS := false
endif

# Colors for output (only on Unix-like systems)
ifneq ($(NATIVE_WINDOWS),true)
    GREEN := \033[0;32m
    YELLOW := \033[0;33m
    RED := \033[0;31m
    BLUE := \033[0;34m
    NC := \033[0m # No Color
else
    GREEN := 
    YELLOW := 
    RED := 
    BLUE := 
    NC := 
endif

# Directories
SCRIPTS_DIR := .claude$(PATH_SEP)scripts
PM_SCRIPTS_DIR := $(SCRIPTS_DIR)$(PATH_SEP)pm
INSTALL_DIR := install
LOGS_DIR := tests$(PATH_SEP)logs

# Project info
PROJECT_NAME := ccpm
REPO_URL := https://github.com/automazeio/ccpm.git

.PHONY: all help info install install-unix install-windows \
        test test-pm test-scripts \
        pm-help pm-status pm-standup pm-init pm-blocked pm-next pm-search validate \
        clean clean-logs clean-all \
        check-python check-git check-system dev

# Default target
all: info

# Help target - shows available commands
help:
	@echo "$(BLUE)CCPM - Cross-Platform Command Project Manager$(NC)"
	@echo "=================================================="
	@echo ""
	@echo "$(YELLOW)Platform detected: $(PLATFORM)$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@echo "  help          - Show this help message"
	@echo "  info          - Show system and project information"
	@echo "  install       - Install CCPM (platform-specific)"
	@echo "  install-unix  - Install CCPM on Unix/Linux/Mac"
	@echo "  install-windows - Install CCPM on Windows"
	@echo "  test          - Run all tests"
	@echo "  test-pm       - Test PM scripts functionality"
	@echo "  validate      - Validate PM system"
	@echo "  pm-help       - Show PM system help"
	@echo "  clean         - Clean temporary files"
	@echo "  clean-logs    - Clean test logs"
	@echo "  clean-all     - Clean everything (logs, temp files, etc.)"
	@echo ""
	@echo "$(GREEN)PM Commands:$(NC)"
	@echo "  pm-status     - Show current status"
	@echo "  pm-standup    - Generate standup report"
	@echo "  pm-init       - Initialize PM system"
	@echo "  pm-blocked    - Show blocked tasks"
	@echo "  pm-next       - Show next tasks"
	@echo "  pm-search     - Search (use: make pm-search QUERY='search term')"
	@echo ""

# Show system and project information
info:
	@echo "$(BLUE)CCPM System Information$(NC)"
	@echo "========================"
	@echo "Platform: $(PLATFORM)"
	@echo "Architecture: $(UNAME_M)"
	@echo "Script extension: $(SHELL_EXT)"
	@echo "Python command: $(PYTHON)"
	@echo "Scripts directory: $(SCRIPTS_DIR)"
	@echo "Install directory: $(INSTALL_DIR)"
	@echo "Repository URL: $(REPO_URL)"
	@echo ""
	@echo "$(GREEN)Directory structure:$(NC)"
	@echo "├── $(SCRIPTS_DIR)$(PATH_SEP)"
	@echo "│   ├── test-and-log$(SHELL_EXT)"
	@echo "│   └── pm$(PATH_SEP) (PM management scripts)"
	@echo "└── $(INSTALL_DIR)$(PATH_SEP)"
	@echo "    ├── ccpm.sh (Unix/Linux/Mac installer)"
	@echo "    └── ccpm.bat (Windows installer)"

# Platform-specific installation
ifeq ($(PLATFORM),windows)
install: install-windows
else
install: install-unix
endif

# Unix/Linux/Mac installation
install-unix:
	@echo "$(GREEN)Installing CCPM for Unix/Linux/Mac...$(NC)"
	@if [ -f "$(INSTALL_DIR)/ccpm.sh" ]; then \
		chmod +x $(INSTALL_DIR)/ccpm.sh; \
		cd $(INSTALL_DIR) && ./ccpm.sh; \
	else \
		echo "$(RED)Error: $(INSTALL_DIR)/ccpm.sh not found$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Installation completed!$(NC)"

# Windows installation
install-windows:
	@echo "Installing CCPM for Windows..."
	@if exist "$(INSTALL_DIR)\ccpm.bat" ( \
		cd $(INSTALL_DIR) && ccpm.bat \
	) else ( \
		echo Error: $(INSTALL_DIR)\ccpm.bat not found && exit 1 \
	)
	@echo "Installation completed!"

# Test targets
test: test-pm test-scripts
	@echo "$(GREEN)All tests completed!$(NC)"

# Test PM scripts functionality
test-pm:
	@echo "$(YELLOW)Testing PM scripts...$(NC)"
	@mkdir -p $(LOGS_DIR)
# Use consistent approach across all platforms with forward slashes
	@echo "Testing PM help..." && chmod +x $(PM_SCRIPTS_DIR)/*.sh 2>$(NULL_DEVICE) || true && $(PM_SCRIPTS_DIR)/help.sh > $(LOGS_DIR)/pm-help-test.log 2>&1
	@echo "Testing PM status..." && $(PM_SCRIPTS_DIR)/status.sh > $(LOGS_DIR)/pm-status-test.log 2>&1
	@echo "Testing PM validate..." && $(PM_SCRIPTS_DIR)/validate.sh > $(LOGS_DIR)/pm-validate-test.log 2>&1
	@echo "$(GREEN)PM tests completed. Check $(LOGS_DIR) for detailed logs.$(NC)"

# Test scripts functionality
test-scripts:
	@echo "$(YELLOW)Testing core scripts...$(NC)"
	@mkdir -p $(LOGS_DIR)
	@echo "Testing test-and-log script..."
	@echo "print('Hello from test script')" > temp_test.py
	@chmod +x $(SCRIPTS_DIR)/test-and-log.sh 2>$(NULL_DEVICE) || true
	@if [ -f "$(SCRIPTS_DIR)/test-and-log.sh" ]; then \
		./$(SCRIPTS_DIR)/test-and-log.sh temp_test.py test-makefile-run || echo "$(YELLOW)Test script execution completed with warnings$(NC)"; \
	else \
		echo "$(RED)Test script not found$(NC)"; \
	fi
	@$(DELETE_CMD) temp_test.py 2>$(NULL_DEVICE) || true
	@echo "$(GREEN)Script tests completed.$(NC)"

# PM command shortcuts - Use shell scripts universally
pm-help:
	@cd $(PM_SCRIPTS_DIR) && chmod +x help.sh 2>$(NULL_DEVICE) || true && ./help.sh

pm-status:
	@cd $(PM_SCRIPTS_DIR) && chmod +x status.sh 2>$(NULL_DEVICE) || true && ./status.sh

pm-standup:
	@cd $(PM_SCRIPTS_DIR) && chmod +x standup.sh 2>$(NULL_DEVICE) || true && ./standup.sh

pm-init:
	@cd $(PM_SCRIPTS_DIR) && chmod +x init.sh 2>$(NULL_DEVICE) || true && ./init.sh

pm-blocked:
	@cd $(PM_SCRIPTS_DIR) && chmod +x blocked.sh 2>$(NULL_DEVICE) || true && ./blocked.sh

pm-next:
	@cd $(PM_SCRIPTS_DIR) && chmod +x next.sh 2>$(NULL_DEVICE) || true && ./next.sh

pm-search:
ifndef QUERY
	@echo "$(RED)Error: Please provide a search query. Usage: make pm-search QUERY='your search term'$(NC)"
else
	@cd $(PM_SCRIPTS_DIR) && chmod +x search.sh 2>$(NULL_DEVICE) || true && ./search.sh "$(QUERY)"
endif

validate:
	@cd $(PM_SCRIPTS_DIR) && chmod +x validate.sh 2>$(NULL_DEVICE) || true && ./validate.sh

# Cleanup targets
clean-logs:
	@echo "$(YELLOW)Cleaning test logs...$(NC)"
	@$(DELETE_DIR_CMD) $(LOGS_DIR) 2>$(NULL_DEVICE) || true
	@echo "$(GREEN)Test logs cleaned.$(NC)"

clean:
	@echo "$(YELLOW)Cleaning temporary files...$(NC)"
	@$(DELETE_CMD) *.tmp *.log temp_*.py 2>$(NULL_DEVICE) || true
	@echo "$(GREEN)Temporary files cleaned.$(NC)"

clean-all: clean clean-logs
	@echo "$(GREEN)All cleanup completed!$(NC)"

# Check if Python is available
check-python:
	@echo "$(YELLOW)Checking Python installation...$(NC)"
	@$(PYTHON) --version >$(NULL_DEVICE) 2>&1 && echo "$(GREEN)Python: OK$(NC)" || echo "$(RED)Python not found$(NC)"

# Check if git is available
check-git:
	@echo "$(YELLOW)Checking Git installation...$(NC)"
	@git --version >$(NULL_DEVICE) 2>&1 && echo "$(GREEN)Git: OK$(NC)" || echo "$(RED)Git not found$(NC)"

# Run all system checks
check-system: check-python check-git
	@echo "$(GREEN)System check completed.$(NC)"

# Development target - run checks and tests
dev: check-system test
	@echo "$(GREEN)Development environment ready!$(NC)"