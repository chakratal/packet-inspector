// ================================================================================ //
// NEORV32 - Verilog testbench                                                      //
// -------------------------------------------------------------------------------- //
// Simple testbench for the auto-generated all-Verilog version of NEORV32.          //
// Checks for the initial UART output of the bootloader ("NEORV32").                //
// -------------------------------------------------------------------------------- //
// The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32              //
// Copyright (c) NEORV32 contributors.                                              //
// Copyright (c) 2020 - 2026 Stephan Nolting. All rights reserved.                  //
// Licensed under the BSD-3-Clause license, see LICENSE for details.                //
// SPDX-License-Identifier: BSD-3-Clause                                            //
// ================================================================================ //

`timescale 1 ns/100 ps // time-unit = 1 ns, precision = 100 ps

module neorv32_verilog_tb(
  input  wire clk,
  input  wire nrst,
  input  wire uart_rxd,
  output wire uart_txd
);

  // XBUS (Wishbone) signals
  wire [31:0] xbus_adr;
  wire [31:0] xbus_dat_o;
  wire [31:0] xbus_dat_i;
  wire        xbus_we;
  wire [3:0]  xbus_sel;
  wire        xbus_stb;
  wire        xbus_cyc;
  wire        xbus_ack;
  wire        xbus_err;

  // unit under test
  // note that there are NO parameters available - the configuration has to be done
  // in the NEORV32 VHDL wrapper *before* synthesizing the generated Verilog code
  neorv32_verilog_wrapper neorv32_verilog_inst (
    .clk_i       (clk),
    .rstn_i      (nrst),
    .uart0_rxd_i (uart_rxd),
    .uart0_txd_o (uart_txd),
    // XBUS (Wishbone)
    .xbus_adr_o  (xbus_adr),
    .xbus_dat_o  (xbus_dat_o),
    .xbus_dat_i  (xbus_dat_i),
    .xbus_we_o   (xbus_we),
    .xbus_sel_o  (xbus_sel),
    .xbus_stb_o  (xbus_stb),
    .xbus_cyc_o  (xbus_cyc),
    .xbus_ack_i  (xbus_ack),
    .xbus_err_i  (xbus_err)
  );

  // Hardware Miner Accelerator Wrapper
  xbus_miner_wrapper miner_inst (
    .clk_i      (clk),
    .rstn_i     (nrst),
    .xbus_adr_i (xbus_adr),
    .xbus_dat_i (xbus_dat_o),
    .xbus_dat_o (xbus_dat_i),
    .xbus_we_i  (xbus_we),
    .xbus_sel_i (xbus_sel),
    .xbus_stb_i (xbus_stb),
    .xbus_cyc_i (xbus_cyc),
    .xbus_ack_o (xbus_ack),
    .xbus_err_o (xbus_err)
  );

endmodule