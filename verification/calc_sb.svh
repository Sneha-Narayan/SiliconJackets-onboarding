class calc_sb #(int DataSize, int AddrSize);

  int mem_a [2**AddrSize];
  int mem_b [2**AddrSize];
  
  bit [DataSize:0] golden_lower_data;
  bit [DataSize:0] golden_upper_data;
  bit carry_lower;
  bit second_read;

  mailbox #(calc_seq_item #(DataSize, AddrSize)) sb_box;

  function new(mailbox #(calc_seq_item #(DataSize, AddrSize)) sb_box);
    this.sb_box = sb_box;
    golden_lower_data = 0;
    golden_upper_data = 0;
    carry_lower = 0;
    second_read = 0;
  endfunction

  task main();
    calc_seq_item #(DataSize, AddrSize) trans;
    forever begin
      sb_box.get(trans);
      // Implement the scoreboard's core functionality.
      // The scoreboard's task is to verify the DUT's behavior by comparing the
      // data received from the monitor against a golden reference model.
      // Use `$display` to log successful transactions and `$error` to report mismatches.
      // If a mismatch occurs, use `$finish` to terminate the simulation.
      //-----------
      // RESET
      //-----------
      if (trans.reset) begin
        // On reset transaction, clear scoreboard state
        golden_lower_data = 0;
        golden_upper_data = 0;
        carry_lower = 0;
        second_read = 0;
      //------------
      // INITIALIZE
      //------------
      // TODO: For initialization, update the scoreboard's local memory (`mem_a` and `mem_b`) to match the DUT's initial SRAM state.
      end else if (trans.initialize) begin

        if(!trans.loc_sel) begin //mem_a
          mem_a[trans.curr_wr_addr] = int'(trans.lower_data);
        end else begin
          mem_b[trans.curr_wr_addr] = int'(trans.upper_data);
        end
      
      //------------
      // WRITE
      //------------
      //TODO: For write operations, compare the DUT's output to the data calculated by the golden model in the scoreboard.
      end else if (trans.rdn_wr) begin
        if (trans.lower_data !== golden_lower_data[DataSize-1:0]) begin 
          $error("[SB] %0t: Lower data write mismatch at addr0x%0x. DUT=0x%0x, Expected=0x%0x",
                $time, trans.curr_wr_addr, trans.lower_data, golden_lower_data[DataSize-1:0]);
          $finish;
        end
        if (trans.upper_data !== golden_upper_data[DataSize-1:0]) begin 
          $error("[SB] %0t: Upper data write mismatch at addr0x%0x. DUT=0x%0x, Expected=0x%0x",
                $time, trans.curr_wr_addr, trans.upper_data, golden_upper_data[DataSize-1:0]);
          $finish;
        end

        //Update scoreboard memory to reflect new write
        mem_a[trans.curr_wr_addr] = int'(trans.lower_data);
        mem_b[trans.curr_wr_addr] = int'(trans.upper_data);

      //------------
      // READ
      //------------
      //TODO: For read operations, compare the data from the SRAM in the DUT to the data stored in the scoreboard's memory.
      //       Think about how to account for the two sequential reads in the DUT for the single write operation. The values
      //       from both read operations need to be used to compare against the calculated values in the DUT when they are written
      //       to SRAM. The second_read, carry_lower, golden_lower_data, and golden_upper_data signals can be used for this purpose.
      end else begin
        
        if (!second_read) begin
          golden_lower_data = {1'b0, trans.lower_data};
          golden_upper_data = {1'b0, trans.upper_data};

          if (trans.lower_data != mem_a[trans.curr_rd_addr]) begin
          $error("[SB] %0t: Read mismatch for 1st SRAM A addr=0x%x. DUT = 0x%x, Expected = 0x%0x",
                  $time, trans.curr_rd_addr, trans.lower_data, mem_a[trans.curr_rd_addr]);
          $finish;
          end
          if (trans.upper_data != mem_b[trans.curr_rd_addr]) begin
            $error("[SB] %0t: Read mismatch for 1st SRAM B addr=0x%x. DUT = 0x%x, Expected = 0x%0x",
                    $time, trans.curr_rd_addr, trans.lower_data, mem_b[trans.curr_rd_addr]);
            $finish;
          end
          second_read = 1;
        end else begin
          if (trans.lower_data != mem_a[trans.curr_rd_addr]) begin
          $error("[SB] %0t: Read mismatch for 2nd SRAM A addr=0x%x. DUT = 0x%x, Expected = 0x%0x",
                  $time, trans.curr_rd_addr, trans.lower_data, mem_a[trans.curr_rd_addr]);
          $finish;
          end
          if (trans.upper_data != mem_b[trans.curr_rd_addr]) begin
            $error("[SB] %0t: Read mismatch for 2nd SRAM B addr=0x%x. DUT = 0x%x, Expected = 0x%0x",
                    $time, trans.curr_rd_addr, trans.lower_data, mem_b[trans.curr_rd_addr]);
            $finish;
          end

          golden_lower_data = golden_lower_data + {1'b0, trans.lower_data};
          carry_lower = golden_lower_data[DataSize];
          golden_upper_data = golden_upper_data + {1'b0, trans.upper_data} + {{DataSize{1'b0}}, carry_lower};
          second_read = 0;
        end
      end
    end
  endtask

endclass : calc_sb
