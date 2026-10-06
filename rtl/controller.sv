/* 
 *	Controller module for DD onboarding.
 *	Manages reading from memory, performing additions, and writing results back to memory.
 *
 *	This module can and should be modified but do not change the interface.
*/
module controller import calculator_pkg::*;(
	// DO NOT MODIFY THESE PORTS
  	input  logic              clk_i,
    input  logic              rst_i,
  
  	// Memory Access
    input  logic [ADDR_W-1:0] read_start_addr,
    input  logic [ADDR_W-1:0] read_end_addr,
    input  logic [ADDR_W-1:0] write_start_addr,
    input  logic [ADDR_W-1:0] write_end_addr,
  
  	// Memory Controls
    output logic 						write,
	output logic 						read,
    output logic [ADDR_W-1:0]			w_addr,
    output logic [MEM_WORD_SIZE-1:0]	w_data,
    output logic [ADDR_W-1:0]			r_addr,
    input  logic [MEM_WORD_SIZE-1:0]	r_data,

  	// Buffer Control (1 = upper, 0, = lower)
    output logic buffer_control,
  
  	// These go into adder
  	output logic [DATA_W-1:0] op_a,
    output logic [DATA_W-1:0] op_b,

	// Carry input for adder
	output logic carry_in,	// Carry input to adder
	input  logic carry_out, // Carry output from adder
	
	// What is being stored in the buffer
    input  logic [MEM_WORD_SIZE-1:0] buff_result
  
); 

	// DO NOT MODIFY THIS BLOCK: Count how many cycles the controller has been active
	logic [31:0] cycle_count;
	always_ff @(posedge clk_i) begin
		if (rst_i)
			cycle_count <= 32'd0;
		else
			cycle_count <= cycle_count + 1'b1;
	end
	//=========================================================================
	// You can change anything below this line. There is a skeleton but feel
	// free to modify as much as you want.
	//=========================================================================

	// Declare state machine states
    state_t state, next;
	buffer_loc_t buffer_loc;

	// Registers to hold read data for current and next reads
	logic [ADDR_W-1:0] r_ptr, w_ptr;

	logic[DATA_W-1:0] a_low, a_high, b_low, b_high;
	logic carry_reg;
  	

	//State register
	always_ff @(posedge clk_i) begin
		if (rst_i)
			state <= S_IDLE;
		else
			state <= next;
	end
	
	
	//Next state logic
	always_comb begin
		case (state)
			S_IDLE:      next = S_READ;   
			S_READ:      next = S_READ2; 
			S_READ2:	 next = S_ADD;
			S_ADD: 	     next = S_ADD2;
			S_ADD2:		 next = S_WRITE;
			S_WRITE: begin
				if(w_ptr >= write_end_addr)
					next = S_END;
				else
					next = S_READ;
			end
			S_END:       next = S_END;
			default:     next = S_IDLE;
		endcase
	end

	// Sequential part of state machine implementation, move points around
	always_ff @(posedge clk_i) begin
		if (rst_i) begin
			r_ptr <= read_start_addr;
			w_ptr <= write_start_addr;
			buffer_loc <= LOWER;
			a_low <= '0;
			a_high <= '0;
			b_low <= '0;
			b_high <= '0;
			carry_reg <= 1'b0;
		end
		else begin
			case (state)
				S_IDLE: begin
					buffer_loc <= buffer_loc;
				end
				S_READ: begin
					r_ptr <= r_ptr + 1'b1;
					w_ptr <= w_ptr;
					buffer_loc <= buffer_loc;
				end
				S_READ2: begin
					a_low <= r_data[31:0];
					a_high <= r_data[63:32];
					r_ptr <= r_ptr + 1'b1;
				end
				S_ADD: begin
					b_low <= r_data[31:0];
					b_high <= r_data[63:32];
					buffer_loc <= UPPER;
					carry_reg <= carry_out;
				end
				S_ADD2: begin
					buffer_loc <= LOWER;
				end
				S_WRITE: begin
					w_ptr <= w_ptr + 1'b1;
					buffer_loc <= buffer_loc;
				end
				S_END: begin
					r_ptr <= r_ptr;
					w_ptr <= w_ptr;
					buffer_loc <= buffer_loc;
				end
			endcase
		end
	end


	// Combinational output logic
	always_comb begin
        // Default values
        write = 1'b0;
        read = 1'b0;

		r_addr = r_ptr;
		w_addr = w_ptr;
		w_data = buff_result;
		carry_in = '0;

		op_a = '0;
		op_b = '0;
		buffer_control = '0;


        case (state)  
            S_IDLE: begin
                // Do nothing
            end
            S_READ: begin
                read = 1'b1;
				r_addr = r_ptr;				
            end
			S_READ2: begin
				read = 1'b1;
				r_addr = r_ptr;
			end
			S_ADD: begin
				op_a = a_low;
				op_b = r_data[31:0];
				carry_in = 1'b0;
				buffer_control = buffer_loc;
			end
			S_ADD2: begin
				op_a = a_high;
				op_b = b_high;
				carry_in = carry_reg;
				buffer_control = buffer_loc;
			end
			S_WRITE: begin
				write = 1'b1;
				w_addr = w_ptr;
				w_data = buff_result;
			end
            S_END: begin
                // Defaults
            end
        endcase
    end

	
  endmodule
