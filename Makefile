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

GAME_NAME        	:= "<GAME_NAME>"
GAME_VERSION 		:= USA

# PSYQ Version
PSYQ_VERSION   		?= 2.7.2

ifeq ($(GAME_VERSION), USA)

# Version - Retail NTSC (1.0)

GAME_NAME        	:= SLUS-01032
GAME_VERSION_DIR 	:= USA
GAME_EXECUTABLE  	:= SLUS_010.32

else ifeq ($(GAME_VERSION), EUR)

# Version - Retail PAL (1.0)

GAME_NAME        	:= SLES-XXXXX
GAME_VERSION_DIR 	:= EUR
GAME_EXECUTABLE  	:= SLES_XXX.XX

else ifeq ($(GAME_VERSION), JAP0)

# Version - Retail NTSC-J (1.0)

GAME_NAME        	:= SLPM-86192
GAME_VERSION_DIR 	:= JAP0
GAME_EXECUTABLE  	:= SLPM_XXX.XX

endif

# Paths
ROOT_DIR     		:= $(CURDIR)
ASSETS_DIR   		:= assets
ASM_DIR	 			:= asm
BUILD_DIR    		:= build
CONFIG_DIR   		:= config
ISO_DIR 	 		:= iso
LINKER_DIR   		:= linker
SRC_DIR      		:= src
SYMBOLS_DIR 		:= symbols
TOOLS_DIR    		:= tools
SPLAT_DIR    		:= $(TOOLS_DIR)/splat
SPLAT_EXT_DIR 		:= $(TOOLS_DIR)/splat_ext
M2C_DIR      		:= $(TOOLS_DIR)/m2c
M2CTXT_DIR   		:= $(TOOLS_DIR)/m2ctxt
MASPSX_DIR   		:= $(TOOLS_DIR)/maspsx
MKPSXISO_DIR 		:= $(TOOLS_DIR)/mkpsxiso

# Toolset
CROSS   			:= mips-linux-gnu
AS      			:= $(CROSS)-as
LD      			:= $(CROSS)-ld
OBJCOPY 			:= $(CROSS)-objcopy
OBJDUMP 			:= $(CROSS)-objdump
CPP     			:= $(CROSS)-cpp
CC      			:= $(TOOLS_DIR)/gcc-$(PSYQ_VERSION)-psx/cc1
OBJDIFF 			:= $(TOOLS_DIR)/objdiff

GIT 				:= git
CMAKE 				:= cmake

PYTHON 				:= python3
PYTHON_VENV 		:= $(TOOLS_DIR)/python
PYTHON_PIP 			:= $(PYTHON_VENV)/bin/pip
PYTHON_BIN 			:= $(PYTHON_VENV)/bin/python

SPLAT 				:= $(PYTHON_BIN) "$(TOOLS_DIR)/splat/splat.py"
MASPSX          	:= $(PYTHON_BIN) "$(TOOLS_DIR)/maspsx/maspsx.py"
DUMPSXISO       	:= $(TOOLS_DIR)/mkpsxiso/dumpsxiso
MKPSXISO        	:= $(TOOLS_DIR)/mkpsxiso/mkpsxiso
YQ		 			:= $(TOOLS_DIR)/yq

# Flags
OPT_FLAGS           := -O2
DL_FLAGS            := -G0
ENDIAN              := -EL
INCLUDE_FLAGS       := -Iinclude -I $(BUILD_DIR) -Iinclude/psyq
DEFINE_FLAGS        := -D_LANGUAGE_C -DUSE_INCLUDE_ASM
CPP_FLAGS           := $(INCLUDE_FLAGS) $(DEFINE_FLAGS) -P -MMD -MP -undef -Wall -lang-c -nostdinc -DVER_${GAME_VERSION}


# Define color variables using tput
RED 				:= $(shell tput setaf 1)
GREEN 				:= $(shell tput setaf 2)
BLUE 				:= $(shell tput setaf 4)
YELLOW 				:= $(shell tput setaf 3)
RESET 				:= $(shell tput sgr0)

# Ruleset

.PHONY: help clean setup tools-setup
default: help

# Generate disassembly
generate:
	$(PYTHON_BIN) "$(SPLAT_DIR)/split.py" "$(CONFIG_DIR)/$(GAME_VERSION_DIR)/$(GAME_EXECUTABLE).yaml"

# Setup environment
setup: git-submodules python-setup tools-setup mkpsxiso-extract splat-setup

## Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)	

## Initialize git submodules
git-submodules:
	@echo "${BLUE}>>> ${GREEN}Initializing git submodules...${RESET}"
	$(GIT) submodule update --init --recursive

## Set up tools
tools-setup: mkpsxiso-setup yq-setup

## Set up mkpsxiso
mkpsxiso-setup:
	@echo "${BLUE}>>> ${GREEN}Setting up mkpsxiso...${RESET}"
	$(CMAKE) -S "$(MKPSXISO_DIR)" -B "$(MKPSXISO_DIR)"
	$(MAKE) -C "$(MKPSXISO_DIR)"

## Set up yq
yq-setup:
	@echo "${BLUE}>>> ${GREEN}Setting up yq...${RESET}"
	wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O tools/yq &&\
    chmod +x tools/yq

## Extract ISO contents using mkpsxiso's dumpsxiso tool
mkpsxiso-extract:
	@echo "${BLUE}>>> ${GREEN}Extracting ISO contents...${RESET}"
	$(DUMPSXISO) -x "$(ISO_DIR)/$(GAME_VERSION_DIR)" -s "$(ISO_DIR)/$(GAME_NAME).xml" "${ISO_DIR}/${GAME_NAME}.cue"
	sha256sum "$(ISO_DIR)/$(GAME_NAME).cue" > "$(CONFIG_DIR)/$(GAME_VERSION_DIR)/$(GAME_EXECUTABLE).sha256"

## Generate Splat configuration file and set up paths
splat-setup:
	@echo "${BLUE}>>> ${GREEN}Setting up Splat configuration...${RESET}"
	$(PYTHON_BIN) "$(SPLAT_DIR)/create_config.py" "${ISO_DIR}/${GAME_VERSION}/${GAME_EXECUTABLE}"
	cp "$(GAME_EXECUTABLE).yaml" "$(CONFIG_DIR)/$(GAME_VERSION_DIR)/$(GAME_EXECUTABLE).yaml"
	rm "$(GAME_EXECUTABLE).yaml"
	$(YQ) -i '.options.base_path = "../../"' "$(CONFIG_DIR)/$(GAME_VERSION_DIR)/$(GAME_EXECUTABLE).yaml"
	$(YQ) -i '.options.ld_script_path = "$(LINKER_DIR)/${GAME_VERSION_DIR}/${GAME_EXECUTABLE}.ld"' "$(CONFIG_DIR)/$(GAME_VERSION_DIR)/$(GAME_EXECUTABLE).yaml"
	$(YQ) -i '.options.undefined_funcs_auto_path = "$(LINKER_DIR)/${GAME_VERSION_DIR}/undefined_funcs_auto.${GAME_EXECUTABLE}.txt"' "$(CONFIG_DIR)/$(GAME_VERSION_DIR)/$(GAME_EXECUTABLE).yaml"
	$(YQ) -i '.options.undefined_syms_auto_path = "$(LINKER_DIR)/${GAME_VERSION_DIR}/undefined_syms_auto.${GAME_EXECUTABLE}.txt"' "$(CONFIG_DIR)/$(GAME_VERSION_DIR)/$(GAME_EXECUTABLE).yaml"
	$(YQ) -i '.options.symbol_addrs_path = "$(SYMBOLS_DIR)/${GAME_VERSION_DIR}/symbol_addrs.${GAME_EXECUTABLE}.txt"' "$(CONFIG_DIR)/$(GAME_VERSION_DIR)/$(GAME_EXECUTABLE).yaml"
	$(YQ) -i '.options.reloc_addrs_path = "$(SYMBOLS_DIR)/${GAME_VERSION_DIR}/reloc_addrs.${GAME_EXECUTABLE}.txt"' "$(CONFIG_DIR)/$(GAME_VERSION_DIR)/$(GAME_EXECUTABLE).yaml"
	$(YQ) -i '.options.target_path = "$(ISO_DIR)/${GAME_VERSION_DIR}/$(GAME_EXECUTABLE)"' "$(CONFIG_DIR)/$(GAME_VERSION_DIR)/$(GAME_EXECUTABLE).yaml"
	$(YQ) -i '.options.elf_path = "$(BUILD_DIR)/${GAME_VERSION_DIR}/${GAME_EXECUTABLE}.elf"' "$(CONFIG_DIR)/$(GAME_VERSION_DIR)/$(GAME_EXECUTABLE).yaml"
	$(YQ) -i '.options.asm_path = "$(ASM_DIR)/${GAME_VERSION_DIR}"' "$(CONFIG_DIR)/$(GAME_VERSION_DIR)/$(GAME_EXECUTABLE).yaml"
	$(YQ) -i '.options.src_path = "$(SRC_DIR)/${GAME_VERSION_DIR}"' "$(CONFIG_DIR)/$(GAME_VERSION_DIR)/$(GAME_EXECUTABLE).yaml"
	$(YQ) -i '.options.build_path = "$(BUILD_DIR)/${GAME_VERSION_DIR}"' "$(CONFIG_DIR)/$(GAME_VERSION_DIR)/$(GAME_EXECUTABLE).yaml"
	$(YQ) -i '.options.asset_path = "$(ASSETS_DIR)/${GAME_VERSION_DIR}"' "$(CONFIG_DIR)/$(GAME_VERSION_DIR)/$(GAME_EXECUTABLE).yaml"
	$(YQ) -i '.options.extensions_path = "$(SPLAT_EXT_DIR)"' "$(CONFIG_DIR)/$(GAME_VERSION_DIR)/$(GAME_EXECUTABLE).yaml"

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
	@echo "${BLUE}  make ${RESET}setup${GREEN}          - Set up the development environment (Python virtual environment and dependencies)${RESET}"
	@echo "${BLUE}  make ${RESET}generate${GREEN}       - Generate disassembly${RESET}"
	@echo "${BLUE}  make ${RESET}report${GREEN}         - Generate a report of the comparison results${RESET}"
	@echo "${BLUE}  make ${RESET}build${GREEN}          - Build the project (assemble and link)${RESET}"
	@echo "${BLUE}  make ${RESET}clean${GREEN}          - Clean build artifacts${RESET}"
	@echo "${BLUE}  make ${RESET}help${GREEN}           - Show this help message${RESET}"

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
	@echo "${YELLOW}	⠀⠀⠀⠀⠀⠀⠀⣀⣤⠀${RED}⣿⣿⣿⣿⡇${GREEN}⠈⠉⠉⠉⠁${RESET}"
	@echo "${YELLOW}	⠀⢀⣠⣤⣶⣾⣿⣿⡿⠀${RED}⣿⣿⣿⣿⡇${GREEN}⢰⣶⣿⣿⣿⠿⠿${BLUE}⢿⣶⣦⣤⡀${RESET}"
	@echo "${YELLOW}	⢰⣿⣿⣿⡿⠛⠉⢀⣀⠀${RED}⣿⣿⣿⣿⡇${GREEN}⠘⠋⠉⠀⣀⣠⣴⣾${BLUE}⣿⣿⣿⠇${RESET}"
	@echo "${YELLOW}	⠈⠻⠿⣿⣿⣿⣿⣿⠿⠀${RED}⣿⣿⣿⣿⡇${GREEN}⢠⣶⣾⣿⣿⡿⠿⠟${BLUE}⠋⠉${RESET}"
	@echo "${YELLOW}	⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀${RED}⠙⠛⠿⢿⡇${YELLOW}⠸⠟${GREEN}⠛⠋⠁${RESET}"
	@echo ""
	@echo "${GREEN}Powered by:"
	@echo "${RED}https://decomp.me ${GREEN}and ${RED}https://decomp.dev${RESET}"
	@echo "${BLUE}-----------------------------------------${RESET}"
	@echo "${GREEN}Game: ${RESET}$(GAME_NAME)"
	@echo "${GREEN}PSYQ Version: ${RESET}$(PSYQ_VERSION)"
	@echo "${BLUE}-----------------------------------------${RESET}"
