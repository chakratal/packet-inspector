`timescale 1ns / 1ps

// ==============================================================================
// Module: axi_miner_wrapper
// Description: AXI4-Lite slave wrapper for the packet inspector / miner.
//              Functionally equivalent to xbus_miner_wrapper.v but exposes
//              an AXI4-Lite interface for connection to NEORV32's m_axi port
//              via Vivado's AXI SmartConnect.
//
// Register Map (byte addresses, word-aligned):
//   0x00 (offset 0): W  - data_in (write triggers valid_in pulse)
//   0x04 (offset 1): R  - {29'b0, accept, drop, invalid}
//   0x08 (offset 2): R  - {31'b0, done_latched}  (read clears done_latched)
//   0x0C (offset 3): R  - invalid_count
//   0x10 (offset 4): R  - drop_count
//   0x14 (offset 5): R  - accept_count
//   0x18 (offset 6): W  - reset counters (any write clears all counters)
// ==============================================================================
module axi_miner_wrapper #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 8
)(
    // AXI4-Lite Slave Interface
    input  wire                              s_axi_aclk,
    input  wire                              s_axi_aresetn,   // Active-low reset (AXI standard)

    // Write Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire [2:0]                        s_axi_awprot,
    input  wire                              s_axi_awvalid,
    output reg                               s_axi_awready,

    // Write Data Channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                              s_axi_wvalid,
    output reg                               s_axi_wready,

    // Write Response Channel
    output reg  [1:0]                        s_axi_bresp,
    output reg                               s_axi_bvalid,
    input  wire                              s_axi_bready,

    // Read Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire [2:0]                        s_axi_arprot,
    input  wire                              s_axi_arvalid,
    output reg                               s_axi_arready,

    // Read Data Channel
    output reg  [C_S_AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    output reg  [1:0]                        s_axi_rresp,
    output reg                               s_axi_rvalid,
    input  wire                              s_axi_rready
);

    // -----------------------------------------------------------------
    // Internal registers (preserved from xbus_miner_wrapper.v)
    // -----------------------------------------------------------------
    reg        valid_in_pulse;
    reg [7:0]  data_in_reg;

    wire       inspector_invalid;
    wire       inspector_drop;
    wire       inspector_accept;
    wire       inspector_done;

    reg [31:0] invalid_count;
    reg [31:0] drop_count;
    reg [31:0] accept_count;
    reg        done_already;
    reg        done_latched;
    reg [2:0]  evaluation_latched;

    wire       done_rising = inspector_done & ~done_already;

    // Pulse from read FSM to clear done_latched (avoids multi-driver on done_latched)
    reg        done_latched_clear;

    // Latched write address/data for two-channel handshake coordination
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr_latched;
    reg [C_S_AXI_DATA_WIDTH-1:0] axi_wdata_latched;

    // Write FSM
    localparam WR_IDLE  = 2'd0;
    localparam WR_DATA  = 2'd1;
    localparam WR_RESP  = 2'd2;
    reg [1:0] wr_state;

    // Read FSM
    localparam RD_IDLE  = 1'd0;
    localparam RD_DATA  = 1'd1;
    reg rd_state;

    // -----------------------------------------------------------------
    // Miner instantiation (unchanged from xbus_miner_wrapper.v)
    // -----------------------------------------------------------------
    miner u_miner (
        .clk      (s_axi_aclk),
        .reset    (~s_axi_aresetn),     // Miner uses active-high reset
        .valid_in (valid_in_pulse),
        .data_in  (data_in_reg),
        .invalid  (inspector_invalid),
        .drop     (inspector_drop),
        .accept   (inspector_accept),
        .done     (inspector_done)
    );

    // -----------------------------------------------------------------
    // Write channel FSM and register writes
    // -----------------------------------------------------------------
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            wr_state           <= WR_IDLE;
            s_axi_awready      <= 1'b0;
            s_axi_wready       <= 1'b0;
            s_axi_bvalid       <= 1'b0;
            s_axi_bresp        <= 2'b00;

            data_in_reg        <= 8'b0;
            valid_in_pulse     <= 1'b0;
            invalid_count      <= 32'b0;
            drop_count         <= 32'b0;
            accept_count       <= 32'b0;
            done_already       <= 1'b0;
            done_latched       <= 1'b0;
            evaluation_latched <= 3'b0;
            axi_awaddr_latched <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            axi_wdata_latched  <= {C_S_AXI_DATA_WIDTH{1'b0}};
        end else begin
            // Default deassertions (single-cycle pulses)
            valid_in_pulse <= 1'b0;

            // Miner done-edge detection logic (preserved from original)
            done_already <= inspector_done;
            if (done_rising) begin
                if (inspector_invalid) invalid_count <= invalid_count + 1;
                if (inspector_drop)    drop_count    <= drop_count + 1;
                if (inspector_accept)  accept_count  <= accept_count + 1;
                done_latched       <= 1'b1;
                evaluation_latched <= {inspector_accept, inspector_drop, inspector_invalid};
            end else if (done_latched_clear) begin
                done_latched <= 1'b0;
            end

            case (wr_state)
                WR_IDLE: begin
                    s_axi_awready <= 1'b1;
                    s_axi_wready  <= 1'b1;
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        // Both address and data arrived together
                        axi_awaddr_latched <= s_axi_awaddr;
                        axi_wdata_latched  <= s_axi_wdata;
                        s_axi_awready      <= 1'b0;
                        s_axi_wready       <= 1'b0;
                        // Perform the write immediately
                        case (s_axi_awaddr[7:2])
                            6'h00: begin
                                data_in_reg    <= s_axi_wdata[7:0];
                                valid_in_pulse <= 1'b1;
                            end
                            6'h06: begin
                                invalid_count <= 32'b0;
                                drop_count    <= 32'b0;
                                accept_count  <= 32'b0;
                            end
                            default: ;
                        endcase
                        // Drive response
                        s_axi_bvalid <= 1'b1;
                        s_axi_bresp  <= 2'b00; // OKAY
                        wr_state     <= WR_RESP;
                    end else if (s_axi_awvalid) begin
                        axi_awaddr_latched <= s_axi_awaddr;
                        s_axi_awready      <= 1'b0;
                        wr_state           <= WR_DATA;
                    end
                end
                WR_DATA: begin
                    s_axi_wready <= 1'b1;
                    if (s_axi_wvalid) begin
                        axi_wdata_latched <= s_axi_wdata;
                        s_axi_wready      <= 1'b0;
                        case (axi_awaddr_latched[7:2])
                            6'h00: begin
                                data_in_reg    <= s_axi_wdata[7:0];
                                valid_in_pulse <= 1'b1;
                            end
                            6'h06: begin
                                invalid_count <= 32'b0;
                                drop_count    <= 32'b0;
                                accept_count  <= 32'b0;
                            end
                            default: ;
                        endcase
                        s_axi_bvalid <= 1'b1;
                        s_axi_bresp  <= 2'b00;
                        wr_state     <= WR_RESP;
                    end
                end
                WR_RESP: begin
                    if (s_axi_bready && s_axi_bvalid) begin
                        s_axi_bvalid <= 1'b0;
                        wr_state     <= WR_IDLE;
                    end
                end
                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // -----------------------------------------------------------------
    // Read channel FSM and register reads
    // -----------------------------------------------------------------
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            rd_state           <= RD_IDLE;
            s_axi_arready      <= 1'b0;
            s_axi_rvalid       <= 1'b0;
            s_axi_rresp        <= 2'b00;
            s_axi_rdata        <= 32'b0;
            done_latched_clear <= 1'b0;
        end else begin
            done_latched_clear <= 1'b0;   // default: single-cycle pulse
            case (rd_state)
                RD_IDLE: begin
                    s_axi_arready <= 1'b1;
                    if (s_axi_arvalid) begin
                        s_axi_arready <= 1'b0;
                        // Decode address and provide data
                        case (s_axi_araddr[7:2])
                            6'h01: s_axi_rdata <= {29'b0, evaluation_latched};
                            6'h02: begin
                                s_axi_rdata        <= {31'b0, done_latched};
                                done_latched_clear <= 1'b1;   // request write-block to clear
                            end
                            6'h03: s_axi_rdata <= invalid_count;
                            6'h04: s_axi_rdata <= drop_count;
                            6'h05: s_axi_rdata <= accept_count;
                            default: s_axi_rdata <= 32'b0;
                        endcase
                        s_axi_rvalid <= 1'b1;
                        s_axi_rresp  <= 2'b00; // OKAY
                        rd_state     <= RD_DATA;
                    end
                end
                RD_DATA: begin
                    if (s_axi_rready && s_axi_rvalid) begin
                        s_axi_rvalid <= 1'b0;
                        rd_state     <= RD_IDLE;
                    end
                end
                default: rd_state <= RD_IDLE;
            endcase
        end
    end

endmodule
