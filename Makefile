# Makefile for Packet Inspector NEORV32 Software-Hardware Co-Design Project

# Tools
PYTHON = python3.14

# Files
SRC = src/main.c
RTL_SRC = rtl/miner.v rtl/xbus_miner_wrapper.v
TEST_SCRIPT = test/miner_test.py
SETUP_SCRIPT = test/setup_tb.py

.PHONY: all setup compile test clean

all: compile

setup:
	$(PYTHON) $(SETUP_SCRIPT)

compile: setup $(SRC) $(RTL_SRC)
	$(MAKE) -C src image install
	$(MAKE) -C tb convert compile-sim

sim: compile
	$(MAKE) -C tb sim

test: compile $(TEST_SCRIPT)
	$(PYTHON) $(TEST_SCRIPT)

clean:
	rm -f $(OUT) *.vcd
	$(MAKE) -C src clean_all
	$(MAKE) -C tb clean
