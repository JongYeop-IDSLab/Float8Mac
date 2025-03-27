# =============================================================================
# Directories
# =============================================================================
SRC_DIR      = src
SYN_DIR      = syn
SIM_DIR      = sim
FSDB_DIR     = fsdb
VERI_DIR     = verification

BEHAV_DIR      = $(VERI_DIR)/behavior
FSDB_OUT_DIR   = $(VERI_DIR)/fsdb
HEX_DIR        = $(VERI_DIR)/hex
REF_DIR        = $(VERI_DIR)/reference_data
TB_DIR         = $(VERI_DIR)/tb
TB_SCRIPT_DIR  = $(VERI_DIR)/scripts
BASE_PATH      = ../..

VSCODE_DIR := .vscode
LINT_DIR := lint
VERILATOR_SCRIPT := $(LINT_DIR)/verilator.sh
VSCODE_SETTINGS := $(VSCODE_DIR)/settings.json
# =============================================================================
# Tool Paths and Options
# =============================================================================
# Synopsys DesignWare library path
SIM_DW_PATH = /ids/tools/SYNOPSYS/syn/S-2021.06-SP4/dw/sim_ver
export ROOT := $(CURDIR)
# Design Tools
VCS           = vcs -full64 
SYN_COMPILER = dc_shell-xg-t -64bit
Verdi        = Verdi

# Tool Options
VCS_OPTS    = -notice -line +lint=all,noVCDE,noUI +v2k \
              -timescale=1ns/10ps -quiet \
              +define+DEBUG -debug_access+all -sverilog -kdb \
              +incdir+$(SRC_DIR) -Mdirectory=$(SIM_DIR)/csrc \
              +vc+list -CC "-I$(VCS_HOME)/include" \
              +incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver

Verdi_OPTS  = "-sv"

# =============================================================================
# Source Files
# =============================================================================
DESIGN_SRCS = $(wildcard $(SRC_DIR)/*.v $(SRC_DIR)/*.sv)
HDRS        = $(wildcard $(SRC_DIR)/*.vh $(VERI_DIR)/tb/*.vh $(VERI_DIR)/behavior/*.vh)
TB_SRCS     = $(wildcard $(TB_DIR)/*.v)

# =============================================================================
# Template Generation Variables
# =============================================================================
TEMPLATE_DIR = templates
DATE       := $(shell date +%Y-%m-%d)
AUTHOR     ?= "Your Name"

# =============================================================================
# Main Targets
# =============================================================================
.PHONY: help clean all sim syn create

help:
	@echo "╔════════════════════════════════════════════════════════════════════╗"
	@echo "║                        Available Targets                           ║"
	@echo "╠════════════════════════════════════════════════════════════════════╣"
	@echo "║ SIMULATION                                                         ║"
	@echo "║   make verification/tb_MODULE=<module_name>.fsdb                   ║"
	@echo "║   → Generate FSDB for specific module and run test script          ║"
	@echo "║                                                                    ║"
	@echo "║ SYNTHESIS                                                          ║"
	@echo "║   make syn/single/<module_name>.syn.v                              ║"
	@echo "║   → Synthesize specific module                                     ║"
	@echo "║                                                                    ║"
	@echo "║ TEMPLATE GENERATION                                                ║"
	@echo "║   make create MODULE=<name> TYPE=<type>                            ║"
	@echo "║   → Create new Verilog file                                        ║"
	@echo "║   → Available types: basic                                         ║"
	@echo "║                                                                    ║"
	@echo "║ UTILITY                                                            ║"
	@echo "║   make clean  : Clean generated files                              ║"
	@echo "║   make help   : Show this help message                             ║"
	@echo "║   make sim    : Run simulation                                     ║"
	@echo "║   make verdi  : Run verdi                                          ║"
	@echo "║   make .vscode/settings.json : Generate verilog linting            ║"
	@echo "╚════════════════════════════════════════════════════════════════════╝"

.SHELL: bash
# -------------- Make commands for automatic single-module testing ---------------- #
# make verif/vcd/tb_<test_name>.vcd will run this command
# requires: verif/tb/tb_<test_name>.v, verif/scripts/tb_<test_name>.py
#@$(VCS) $(VCS_OPTS) $(TB_DIR)/tb_$*.v $(SRC_DIR)/$*.v -o $(SIM_DIR)/$*/simv
$(FSDB_OUT_DIR)/tb_%.fsdb: $(TB_SCRIPT_DIR)/tb_%.py $(SIM_DIR)/%/simv
	@mkdir -p $(FSDB_OUT_DIR)
	@echo "Running test script for $*"
	@python $(TB_SCRIPT_DIR)/tb_$*.py
	@$(SIM_DIR)/$*/simv -k $(SIM_DIR)/$*/ucli.key -q +verbose=1
	@$(Verdi) $(Verdi_OPTS) -ssf $(FSDB_OUT_DIR)/tb_$*.fsdb

$(SIM_DIR)/%/simv: $(SRC_DIR)/%.v $(TB_DIR)/tb_%.v $(TB_DIR)/tb_%.vh
	@mkdir -p $(SIM_DIR)/$*
	@echo "Compiling test simv for $*"
	@$(VCS) $(VCS_OPTS) -diag sys_task_mem -Mdirectory=$(SIM_DIR)/$*/csrc -o $@ $(SRC_DIR)/$*.v $(TB_DIR)/tb_$*.v 

# Synthesize single module
$(SYN_DIR)/single/%.syn.v : $(SRC_DIR)/Sparse_Core/%.sv
	@mkdir -p $(SYN_DIR)/single/$*
	@cp syn/*.tcl $(SYN_DIR)/single/$*/
	@sed -i 's/DESIGN_NAME/$*/g' $(SYN_DIR)/single/$*/top.syn.tcl
	@echo "Synthesizing $*"
	@cd $(SYN_DIR)/single/$* && $(SYN_COMPILER) -f top.syn.tcl | tee synthesis_$*.log
	@cp syn/single/$*/rpts/$*/$*.syn.v $(SYN_DIR)/single/$*/$*.syn.v
	@echo "Synthesis log saved to $(SYN_DIR)/single/$*/synthesis_$*.log"
	@echo "Synthesized $*"

$(SYN_DIR)/syn_bender : 
	@mkdir -p $(SYN_DIR)/syn_bender
	@cp syn/*.tcl $(SYN_DIR)/syn_bender/
	@cp syn/file_list.tcl $(SYN_DIR)/syn_bender/
	@cd $(SYN_DIR)/syn_bender && $(SYN_COMPILER) -f syn.tcl | tee synthesis_bender.log

# =============================================================================
# Custom commands for specific modules
$(FSDB_OUT_DIR)/tb_Float8Mac16_3stage.fsdb: $(TB_SCRIPT_DIR)/tb_Float8Mac16.py $(SIM_DIR)/Float8Mac16_3stage/simv
	@mkdir -p $(FSDB_OUT_DIR)
	@echo "Running test script for $*"
	@python $(TB_SCRIPT_DIR)/tb_Float8Mac16.py
	@$(SIM_DIR)/Float8Mac16_3stage/simv -k $(SIM_DIR)/Float8Mac16_3stage/ucli.key -q +verbose=1
#@$(Verdi) $(Verdi_OPTS) -ssf $(FSDB_OUT_DIR)/tb_Float8Mac16_3stage.fsdb # Uncomment this line to view the waveform

$(SIM_DIR)/Float8Mac16_3stage/simv: $(SRC_DIR)/Float8Mac16_3stage.sv $(TB_DIR)/tb_Float8Mac16_3stage.sv
	@mkdir -p $(SIM_DIR)/Float8Mac16_3stage
	@echo "Compiling test simv for $*"
	@$(VCS) $(VCS_OPTS) -diag sys_task_mem -Mdirectory=$(SIM_DIR)/Float8Mac16_3stage/csrc -o $@ $(SRC_DIR)/Float8Mac16_3stage.sv $(TB_DIR)/tb_Float8Mac16_3stage.sv 
# =============================================================================
# Simulation Targets
# =============================================================================
.PHONY: sim
sim: $(FSDB_OUT_DIR)/tb_Float8Mac16_3stage.fsdb
# =============================================================================
# Delete any log, txt files in the root directory
# =============================================================================
# Clean Target
# =============================================================================
clean:
	@echo "Cleaning up generated files..."
	@rm -rf $(SYN_DIR)/single/*
	@rm -rf $(SIM_DIR)/* $(FSDB_OUT_DIR)/* \
	*.log novas.* VerdiLog build
	@rm -rf verification/hex/input/* verification/hex/ref/* 
	@rm -rf $(SYN_DIR)/syn_bender
	@echo "Clean complete"
