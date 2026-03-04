SHELL := /bin/bash

# Configuration
CHECKSUM       ?= 1
NON_MATCHING   ?= 0
SKIP_ASM       ?= 0

# Enables usage of the `COMMON` segment.
# The compiler can create a segment call `COMMON` intended to handle repetitive
# global variables declared in files which later becomes simple data that then
# get assigned into some data segment. This comes as default and can be disabled,
# however, MASPSX by default do not emit the segment and instead assign data
# directly into the data segments. The importance of having this segment
# supported is specially in the way MASPSX handle data order in a different way
# to how the actual `COMMON` segment handles data order. It is required to have
# the segment supported in the linker script, even though Splat doesn't natively
# support it. Additionally, the linker will reorder variables based on their names.
USE_COMMON     ?= 0

# Game configuration
#
# Versions supported
#
# Retail:
# American
# European
# Japanese

GAME_NAME := "<GAME_NAME>"
GAME_VERSION := USA

# PSYQ Version
PSYQ_VERSION   ?= 2.7.2

ifeq ($(GAME_VERSION), USA)

# Version - Retail NTSC (1.1)

GAME_NAME        := SLUS-XXXXX
GAME_VERSION_DIR := USA
GAME_EXECUTABLE  := SLUS_XXX.XX

else ifeq ($(GAME_VERSION), EUR)

# Version - Retail PAL (1.0)

GAME_NAME        := SLES-XXXXX
GAME_VERSION_DIR := EUR
GAME_EXECUTABLE  := SLES_XXX.XX

else ifeq ($(GAME_VERSION), JAP0)

# Version - Retail NTSC-J (1.0)

GAME_NAME        := SLPM-86192
GAME_VERSION_DIR := JAP0
GAME_EXECUTABLE  := SLPM_XXX.XX

endif

# Paths
ROOT_DIR     := $(CURDIR)
ASSETS_DIR   := assets
BUILD_DIR    := build
CONFIG_DIR   := config
SRC_DIR      := src
TOOLS_DIR    := tools
SPLAT_DIR    := $(TOOLS_DIR)/splat
M2C_DIR      := $(TOOLS_DIR)/m2c
M2CTXT_DIR   := $(TOOLS_DIR)/m2ctxt
MASPSX_DIR   := $(TOOLS_DIR)/maspsx

# Toolset
CROSS   := mips-linux-gnu
AS      := $(CROSS)-as
LD      := $(CROSS)-ld
OBJCOPY := $(CROSS)-objcopy
OBJDUMP := $(CROSS)-objdump
CPP     := $(CROSS)-cpp
CC      := $(TOOLS_DIR)/gcc-$(PSYQ_VERSION)-psx/cc1
OBJDIFF := $(TOOLS_DIR)/objdiff

PYTHON 	:= python3
PYTHON_VENV := $(TOOLS_DIR)/python
PYTHON_PIP := $(PYTHON_VENV)/bin/pip
PYTHON_BIN := $(PYTHON_VENV)/bin/python

SPLAT := $(PYTHON) $(TOOLS_DIR)/splat/splat.py
MASPSX          := $(PYTHON) $(TOOLS_DIR)/maspsx/maspsx.py
DUMPSXISO       := $(TOOLS_DIR)/mkpsxiso/dumpsxiso
MKPSXISO        := $(TOOLS_DIR)/mkpsxiso/mkpsxiso

# Flags
OPT_FLAGS           := -O2
DL_FLAGS            := -G0
ENDIAN              := -EL
INCLUDE_FLAGS       := -Iinclude -I $(BUILD_DIR) -Iinclude/psyq
DEFINE_FLAGS        := -D_LANGUAGE_C -DUSE_INCLUDE_ASM
CPP_FLAGS           := $(INCLUDE_FLAGS) $(DEFINE_FLAGS) -P -MMD -MP -undef -Wall -lang-c -nostdinc -DVER_${GAME_VERSION}


# Define color variables using tput
RED := $(shell tput setaf 1)
GREEN := $(shell tput setaf 2)
BLUE := $(shell tput setaf 4)
RESET := $(shell tput sgr0)

# Ruleset

.PHONY: help clean setup
default: help

# Setup environment
setup: python-setup

## Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)	

## Python setup
python-setup: python-venv python-deps

## Create Python virtual environment
python-venv:
	@echo "${BLUE}>>> ${GREEN}Creating virtual environment...${RESET}"
	$(PYTHON) -m venv "$(PYTHON_VENV)"

## Install Python dependencies
python-deps:
	@echo "${BLUE}>>> ${GREEN}Installing dependencies...${RESET}"
	$(PYTHON_PIP) install -r "$(SPLAT_DIR)/requirements.txt"

## Show available commands
help: motd
	@echo "${GREEN}Usage: make [command]${RESET}"
	@echo "${GREEN}Available commands:${RESET}"
	@echo "${GREEN}  make ${RESET}setup${GREEN}          - Set up the development environment (Python virtual environment and dependencies)${RESET}"
	@echo "${GREEN}  make ${RESET}clean${GREEN}          - Clean build artifacts${RESET}"
	@echo "${GREEN}  make ${RESET}help${GREEN}           - Show this help message${RESET}"

## Display a message of the day (MOTD)
motd:
	@echo "${BLUE}-----------------------------------------${RESET}"
	@echo "${GREEN}        PSX Decompilation Project${RESET}"
	@echo ""
	@echo "${RED}	⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣷⣶⣤⣤⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀${RESET}"
	@echo "${RED}	⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⠿⣿⣷⣶⣄⠀⠀⠀⠀⠀⠀⠀⠀${RESET}"
	@echo "${RED}	⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⡇⠀⢸⣿⣿⣿⣷⡄⠀⠀⠀⠀⠀⠀${RESET}"
	@echo "${RED}	⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⡇⠀⢸⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀${RESET}"
	@echo "${RED}	⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⡇⠀⢸⣿⣿⣿⣿⡿⠀⠀⠀⠀⠀⠀${RESET}"
	@echo "${RED}	⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⡇⠀⢸⣿⣿⣿⣿⠇⠀⠀⠀⠀⠀⠀${RESET}"
	@echo "${RED}	⠀⠀⠀⠀⠀⠀⠀⣀⣤⠀⣿⣿⣿⣿⡇⠀⠈⠉⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀${RESET}"
	@echo "${RED}	⠀⢀⣠⣤⣶⣾⣿⣿⡿⠀⣿⣿⣿⣿⡇⠀⢰⣶⣿⣿⣿⠿⠿⢿⣶⣦⣤⡀${RESET}"
	@echo "${RED}	⢰⣿⣿⣿⡿⠛⠉⢀⣀⠀⣿⣿⣿⣿⡇⠀⠘⠋⠉⠀⣀⣠⣴⣾⣿⣿⣿⠇${RESET}"
	@echo "${RED}	⠈⠻⠿⣿⣿⣿⣿⣿⠿⠀⣿⣿⣿⣿⡇⠀⢠⣶⣾⣿⣿⡿⠿⠟⠋⠉⠀⠀${RESET}"
	@echo "${RED}	⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠛⠿⢿⡇⠀⠸⠟⠛⠋⠁⠀⠀⠀⠀⠀⠀⠀${RESET}"
	@echo "${BLUE}-----------------------------------------${RESET}"
	@echo "${GREEN}Game: ${RESET}$(GAME_NAME)"
	@echo "${GREEN}PSYQ Version: ${RESET}$(PSYQ_VERSION)"
	@echo "${BLUE}-----------------------------------------${RESET}"