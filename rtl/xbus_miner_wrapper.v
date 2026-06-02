`timescale 1ns / 1ps

// ==============================================================================
// Module: xbus_inspector_wrapper
// Description: XBUS (Wishbone-compatible) slave wrapper for the packet
// inspector.
// ==============================================================================
module xbus_miner_wrapper (
    // Clock and Reset
    input  wire        clk_i,
    input  wire        rstn_i,    // Active-low reset from bus
    
    // XBUS (Wishbone) Slave Interface
    input  wire [31:0] xbus_adr_i,     // Address
    input  wire [31:0] xbus_dat_i,     // Write data
    input  wire [ 3:0] xbus_sel_i,     // Byte enable (ignored here, assuming 32-bit writes)
    input  wire        xbus_we_i,      // Write enable
    input  wire        xbus_cyc_i,     // Valid bus cycle
    input  wire        xbus_stb_i,     // Strobe signal
    
    output reg  [31:0] xbus_dat_o,     // Read data
    output reg         xbus_ack_o,     // Transfer acknowledge
    output wire        xbus_err_o      // Error (tied to 0)
);

    assign xbus_err_o = 1'b0;

    reg valid_in_pulse;
    reg [7:0] data_in_reg;

    wire        inspector_invalid;
    wire        inspector_drop;
    wire        inspector_accept;
    wire        inspector_done;
    
    reg [31:0] invalid_count;
    reg [31:0] drop_count;
    reg [31:0] accept_count;
    reg        done_already;
    reg        done_latched;
    reg [2:0]  evaluation_latched;

    wire        done_rising = inspector_done & ~done_already;

    // Instantiate the actual miner
    miner u_miner (
        .clk(clk_i),
        .reset(~rstn_i),          // Miner uses active-high reset
        .valid_in(valid_in_pulse),
        .data_in(data_in_reg),
        .invalid(inspector_invalid),
        .drop(inspector_drop),
        .accept(inspector_accept),
        .done(inspector_done)
    );

    // XBUS Logic & Acknowledge
    always @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
	    data_in_reg <= 8'b0;
	    valid_in_pulse <= 1'b0;
            xbus_ack_o  <= 1'b0;
            xbus_dat_o  <= 32'b0;

            invalid_count   <= 32'b0;
            drop_count   <= 32'b0;
            accept_count   <= 32'b0;
            done_already   <= 1'b0;
	    done_latched <= 1'b0;
	    evaluation_latched <= 3'b0;
        end else begin
            valid_in_pulse <= 1'b0;
            xbus_ack_o  <= 1'b0;
	    done_already <= inspector_done;
	    if (done_rising) begin
	        if (inspector_invalid) invalid_count <= invalid_count +1;
                if (inspector_drop) drop_count <= drop_count +1;
                if (inspector_accept) accept_count <= accept_count +1;
		done_latched <= 1'b1;
		evaluation_latched <= {inspector_accept, inspector_drop, inspector_invalid};
	end 
	if (xbus_cyc_i && xbus_stb_i && !xbus_ack_o) begin
	    xbus_ack_o <= 1'b1;
	
	    if (xbus_we_i) begin
	        case(xbus_adr_i[7:2])
		    6'h00: begin
			data_in_reg <= xbus_dat_i[7:0];
			valid_in_pulse <= 1'b1;
		    end 
		    6'h06: begin
			invalid_count <= 32'b0;
			drop_count <= 32'b0;
			accept_count <= 32'b0;
		    end
		    default: ;
		endcase
	    end else begin
		case (xbus_adr_i[7:2])
		    6'h01: xbus_dat_o <= {29'b0, evaluation_latched};
                    6'h02: xbus_dat_o <= {31'b0, done_latched};
                    6'h03: xbus_dat_o <= invalid_count;
                    6'h04: xbus_dat_o <= drop_count;
                    6'h05: xbus_dat_o <= accept_count;
		    default: xbus_dat_o <= 32'b0;
		endcase
		if (xbus_adr_i[7:2] == 6'h02) begin
		    done_latched <= 1'b0;
		end
		end
	    end            
        end
    end

endmodule
