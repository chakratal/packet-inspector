// Description: Hardware accelerator for packet inspection.
// ==============================================================================
module miner(
    input  wire        clk,
    input  wire        reset,
    input wire valid_in,
    input wire [7:0] data_in,
    output reg drop,
    output reg accept,
    output reg invalid,
    output reg done
);

    // FSM State Encodings

    localparam STATE_IDLE    = 4'b0000;
    localparam STATE_SRC = 4'b0001;
    localparam STATE_DST = 4'b0010;
    localparam STATE_TYPE = 4'b0011;
    localparam STATE_LEN = 4'b0100;
    localparam STATE_PAYLOAD = 4'b0101;
    localparam STATE_CHK = 4'b0110;
    localparam STATE_DONE = 4'b0111;

    reg [3:0] state;
    reg [7:0] src_reg;
    reg [7:0] dst_reg;
    reg [7:0] type_reg;
    reg [7:0] len_reg;
    reg [7:0] checksum;
    reg [7:0] payload_count;
    reg [31:0] payload_sequence;
    reg invalid_flag;
    reg drop_flag;

    always @(posedge clk) begin
        if (reset) begin
            state <= STATE_IDLE;
	    invalid <= 1'b0;
	    drop <= 1'b0;
	    accept <= 1'b0;
	    done <= 1'b0;  
	    invalid_flag <= 1'b0;
	    drop_flag <= 1'b0;
	    checksum <= 8'h00;
	    payload_count <= 8'h00;
	    payload_sequence <= 32'h00000000;
	    src_reg <= 8'h00;
	    dst_reg <= 8'h00;
	    type_reg <= 8'h00;
	    len_reg <= 8'h00;
        end else begin
	    case (state)
	        STATE_IDLE: begin
	            invalid <= 1'b0;
            	    drop <= 1'b0;
            	    accept <= 1'b0;
            	    done <= 1'b0;
		    if (valid_in) begin
		        checksum <= 8'h00;
			payload_count <= 8'h00;
			payload_sequence <= 32'h00000000;
			invalid_flag <= 1'b0;
			drop_flag <= 1'b0;
			if (data_in != 8'hAA) begin
			    invalid_flag <= 1'b1;
			end
		        state <= STATE_SRC;	    
		    end
                end
	        STATE_SRC: begin
		    if (valid_in) begin
			src_reg <= data_in;
			checksum <= checksum + data_in;
			if (data_in == 8'hF0 || data_in == 8'hF1) begin
			    drop_flag <= 1'b1;
			end
		        state <= STATE_DST;
	            end
	        end
	        STATE_DST: begin
		    if (valid_in) begin
		        dst_reg <= data_in;
		        checksum <= checksum + data_in;
			if (data_in != 8'h01 && data_in != 8'h02 && data_in != 8'h03) begin
		            drop_flag <=1'b1; 
			end
		        state <= STATE_TYPE;
		    end
		end
	        STATE_TYPE: begin
		    if (valid_in) begin
			type_reg <= data_in;
			checksum <= checksum + data_in;
		        if (data_in != 8'h01 && data_in != 8'h02 && data_in != 8'h03) begin
			    invalid_flag <= 1'b1;
		        end
			state <= STATE_LEN;
		    end
		end
	        STATE_LEN: begin
                    if (valid_in) begin
			len_reg <= data_in;
			checksum <= checksum + data_in;
                        if (data_in > 8'h08) begin 
			   invalid_flag <= 1'b1;	   
                        end if (data_in == 8'h00) begin
			    state <= STATE_CHK;
                        end else begin
			    state <= STATE_PAYLOAD;
		 	end
		    end
	        end
	        STATE_PAYLOAD: begin
		    if (valid_in) begin
			checksum <= checksum + data_in;
			payload_count <= payload_count +1;
			payload_sequence <= {payload_sequence[23:0], data_in};
			if ({payload_sequence[23:0], data_in} == 32'hDEADBEEF) begin
			    drop_flag <= 1'b1;
		        end if (payload_count == len_reg -1) begin
			    state <= STATE_CHK;
			end
		    end
	        end
	        STATE_CHK: begin
		    if (valid_in) begin
		        if (data_in != checksum)
		            invalid_flag <= 1'b1;
    		        state <= STATE_DONE;	       
		    end
	        end
	        STATE_DONE: begin
		    done <= 1'b1;
                    if (invalid_flag) begin
                        invalid <= 1'b1;
		        drop <= 1'b0;
		        accept <= 1'b0;
                    end else if (drop_flag) begin
		        invalid <= 1'b0;
                        drop <= 1'b1;
		        accept <= 1'b0;
                    end else begin
		        invalid <= 1'b0;
		        drop <= 1'b0;
                        accept <= 1'b1;
		    end
		    state <= STATE_IDLE;
	        end
		default: state <= STATE_IDLE;
	    endcase
        end
    end

endmodule
