ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
TOP := video_pipeline_top
TB_TOP := video_pipeline_verilator_tb
BUILD_DIR := $(ROOT_DIR)/build
OBJ_DIR := $(BUILD_DIR)/obj_dir
BIN := $(OBJ_DIR)/V$(TOP)
TB_OBJ_DIR := $(BUILD_DIR)/tb_obj_dir
TB_BIN := $(TB_OBJ_DIR)/V$(TB_TOP)

RTL_SOURCES := \
	$(ROOT_DIR)/rtl/video_types_pkg.sv \
	$(ROOT_DIR)/rtl/axis_skid_buffer.sv \
	$(ROOT_DIR)/rtl/video_rate_gen.sv \
	$(ROOT_DIR)/rtl/pattern_generator_axis.sv \
	$(ROOT_DIR)/rtl/axis_to_vga.sv \
	$(ROOT_DIR)/rtl/video_pipeline_top.sv

TB_SOURCES := \
	$(ROOT_DIR)/tb/video_pipeline_verilator_tb.sv

SIM_SOURCES := \
	$(ROOT_DIR)/sim/main.cpp \
	$(ROOT_DIR)/sim/vga_monitor.cpp

VERILATOR ?= verilator
VERIBLE_FORMAT ?= verible-verilog-format
VERIBLE_LINT ?= verible-verilog-lint
VERIBLE_SYNTAX ?= verible-verilog-syntax
TOP_PARAMS ?=
TB_RUN_ARGS ?=

VERILATOR_BUILD_FLAGS := --sv --timing --cc --exe --build -j 0 --top-module $(TOP) $(TOP_PARAMS)
VERILATOR_LINT_FLAGS := --sv --timing --lint-only -Wall --top-module $(TOP) $(TOP_PARAMS)
VERILATOR_TB_FLAGS := --sv --timing --trace --binary -Wno-TIMESCALEMOD -j 0 --top-module $(TB_TOP) $(TOP_PARAMS)
VERIBLE_SYNTAX_FLAGS := --lang=sv
VERIBLE_LINT_FLAGS := --ruleset=default --rules=-module-filename,-parameter-name-style \
	--check_syntax=true --parse_fatal=true --lint_fatal=true
VERIBLE_FORMAT_FLAGS := --inplace --column_limit=100 --indentation_spaces=2 \
	--line_terminator=auto

SDL2_CFLAGS ?= $(shell (sdl2-config --cflags || pkg-config --cflags sdl2) 2>/dev/null)
SDL2_LIBS ?= $(shell (sdl2-config --libs || pkg-config --libs sdl2) 2>/dev/null)

SIM_CFLAGS := -std=c++17 -O2 -Wall -Wextra $(SDL2_CFLAGS)
SIM_LDFLAGS := $(SDL2_LIBS)
RUN_ARGS ?= --frames-per-step 15 --input-clk-hz 100000000

ifeq ($(strip $(SDL2_CFLAGS)),)
$(warning SDL2 flags not found. Install libsdl2-dev in WSL or export SDL2_CFLAGS/SDL2_LIBS.)
endif

.PHONY: all build run headless tb-build tb tb-trace lint lint-sv syntax-sv format clean help

all: build

build: $(BIN)

$(BIN): $(RTL_SOURCES) $(SIM_SOURCES)
	mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VERILATOR_BUILD_FLAGS) \
		--Mdir $(OBJ_DIR) \
		-CFLAGS "$(SIM_CFLAGS)" \
		-LDFLAGS "$(SIM_LDFLAGS)" \
		$(RTL_SOURCES) $(SIM_SOURCES)

tb-build: $(TB_BIN)

$(TB_BIN): $(RTL_SOURCES) $(TB_SOURCES)
	mkdir -p $(TB_OBJ_DIR)
	$(VERILATOR) $(VERILATOR_TB_FLAGS) \
		--Mdir $(TB_OBJ_DIR) \
		$(RTL_SOURCES) $(TB_SOURCES)

tb: tb-build
	$(TB_BIN) $(TB_RUN_ARGS)

sim: build
	$(BIN) $(RUN_ARGS)

headless: build
	$(BIN) --headless $(RUN_ARGS)

lint:
	$(VERILATOR) $(VERILATOR_LINT_FLAGS) $(RTL_SOURCES)

syntax:
	$(VERIBLE_SYNTAX) $(VERIBLE_SYNTAX_FLAGS) $(RTL_SOURCES)

format:
	$(VERIBLE_FORMAT) $(VERIBLE_FORMAT_FLAGS) $(RTL_SOURCES)

clean:
	rm -rf $(BUILD_DIR)
