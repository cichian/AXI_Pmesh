
TOPLEVEL_LANG ?= verilog

ifneq ($(TOPLEVEL_LANG),verilog)
all:
	@echo "Skipping; this example does not support VHDL at the top-level"
clean::

else

PWD=$(shell pwd)
TOPDIR=$(PWD)/..
PYTHONPATH := ./model:$(PYTHONPATH)

export PYTHONPATH

SIM ?= icarus

#not sure if only icarus include is by -I ...
ifeq ($(SIM),icarus)
COMPILE_ARGS+=-I$(TOPDIR)/hdl/ -DPITON_SIM_MEMORY
else
COMPILE_ARGS+=+incdir+$(TOPDIR)/hdl/ -DPITON_SIM_MEMORY -Wno-fatal -Wno-BLKANDNBLK -Wno-TIMESCALEMOD --unroll-count 256
endif

#DUT
VERILOG_SOURCES = $(TOPDIR)/hdl/axilite_noc_bridge.v
VERILOG_SOURCES += $(TOPDIR)/hdl/noc_response_axilite.v
VERILOG_SOURCES += $(TOPDIR)/hdl/sync_fifo.v
VERILOG_SOURCES += $(TOPDIR)/hdl/fake_mem_ctrl.v
VERILOG_SOURCES += $(TOPDIR)/hdl/l2_decoder.v
VERILOG_SOURCES += $(TOPDIR)/hdl/l2_encoder.v
VERILOG_SOURCES += $(TOPDIR)/hdl/strb2mask.v

#Test Bench
VERILOG_SOURCES += $(TOPDIR)/hdl/tb_axi_responder.v

TOPLEVEL = tb_axi_responder

GPI_IMPL := vpi

export TOPLEVEL_LANG
MODULE=test_axi_responder

include $(shell cocotb-config --makefiles)/Makefile.sim

endif

wave:
	gtkwave *.vcd &
