`timescale 1ns / 1ps 

// ==============================================================================
// Module: top_arty
// Description: Wrapper to connect Arty A7-100 board to NEORV32 soft processor and packet inspector XBUS slave wrapper.
// ==============================================================================

module top_arty (
    input  wire CLK100MHZ,    // oscillator
    input  wire ck_rst,    // Active-low reset
    input  wire uart_txd_in,   // From host's TX (FPGA's RX)
    input  wire uart_rxd_out,  // To host's RX (FPGA's TX)
    output wire led0          // Status LED
);

    // XBUS connector between Slave Interface and NEORV32
    wire [31:0] xbus_adr;     // Address
    wire [31:0] xbus_dat_m2s;     // Write data
    wire [31:0] xbus_dat_s2m;      
    wire [3:0]  xbus_sel;
    wire        xbus_we;      // Write enable
    wire        xbus_cyc;     // Valid bus cycle
    wire        xbus_stb;     // Strobe signal

    wire        xbus_ack;     // Transfer acknowledge
    wire        xbus_err;      // Error (tied to 0)


    neorv32_verilog_wrapper neorv32_inst (
        .clk_i(CLK100MHZ),
        .rstn_i(ck_rst),          
        .uart0_rxd_i(uart_txd_in),
        .uart0_txd_o(uart_rxd_out),
        .xbus_dat_i(xbus_dat_s2m),
	.xbus_ack_i(xbus_ack),
        .xbus_err_i(xbus_err),
        .xbus_adr_o(xbus_adr),
        .xbus_dat_o(xbus_dat_m2s),
	.xbus_we_o(xbus_we),
	.xbus_sel_o(xbus_sel),
	.xbus_stb_o(xbus_stb),
	.xbus_cyc_o(xbus_cyc)
    );

    xbus_miner_wrapper inspector_inst (
        .clk_i(CLK100MHZ),
        .rstn_i(ck_rst),
	.xbus_adr_i(xbus_adr),
        .xbus_dat_i(xbus_dat_m2s),
        .xbus_sel_i(xbus_sel),
	.xbus_we_i(xbus_we),
	.xbus_cyc_i(xbus_cyc),
	.xbus_stb_i(xbus_stb),
	.xbus_dat_o(xbus_dat_s2m),
	.xbus_ack_o(xbus_ack),
	.xbus_err_o(xbus_err)
    );

    assign led0 = 1'b1;

endmodule
