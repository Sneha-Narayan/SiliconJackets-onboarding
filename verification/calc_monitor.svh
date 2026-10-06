class calc_monitor #(int DataSize, int AddrSize);
  logic written = 0;

  logic pending_read;
  logic [AddrSize-1:0] pending_rd_addr;
  calc_seq_item #(DataSize, AddrSize) initialization_trans;

  virtual interface calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calcVif;
  mailbox #(calc_seq_item #(DataSize, AddrSize)) mon_box;

  function new(virtual interface calc_if #(DataSize, AddrSize) calcVif);
    this.calcVif = calcVif;
    this.mon_box = new();
  endfunction

  task main();
    forever begin
      @(calcVif.cb);

      // Monitor the reset signal. If reset is asserted, we want to send a transaction to the scoreboard 
      // to indicate that reset has happened so that the scoreboard can reset its internal state as well.
      if (calcVif.cb.reset) begin
        calc_seq_item #(DataSize, AddrSize) trans = new();
        written = 0;
        pending_read = 0;
        trans.reset = 1'b1;
        mon_box.put(trans);
      end

      if (calcVif.cb.rd_en && calcVif.cb.wr_en) begin
        $error($stime, " Mon: Error rd_en and wr_en both asserted at the same time\n");
      end
 
      if (pending_read) begin
        calc_seq_item #(DataSize, AddrSize) trans = new();
        // TODO: If there is a pending read, we will now form the transaction for that read operation using the pending_rd_addr and the data on the clocking block. 
        // We can then send this transaction to the scoreboard for checking.
        
        //fill in trans with the pending read info
        trans.rdn_wr = 0; //read
        trans.curr_rd_addr = pending_rd_addr; //address waiting to read
        trans.lower_data = calcVif.cb.rd_data_lower; //SRAM A data
        trans.upper_data = calcVif.cb.rd_data_upper; //SRAM B data

        $display($stime, " Mon: Read from Addr: 0x%0x, Data from SRAM A: 0x%0x, Data from SRAM B: 0x%0x\n",
          trans.curr_rd_addr, trans.lower_data, trans.upper_data);
        mon_box.put(trans);
        pending_read = 0;
      end

      // Sample the transaction and send to scoreboard
      if (calcVif.cb.wr_en || calcVif.cb.rd_en) begin
        calc_seq_item #(DataSize, AddrSize) trans = new();
        // TODO: Assign all values in the "trans" sequence item object with relevant signals from the clocking block

        trans.rdn_wr = calcVif.cb.wr_en;
        trans.curr_wr_addr = calcVif.cb.curr_wr_addr;
        trans.curr_rd_addr = calcVif.cb.curr_rd_addr;
        trans.loc_sel = calcVif.cb.loc_sel;

        if (trans.rdn_wr) // Write
        begin
          // TODO: Assign the data for the transaction from the clocking block correctly
          trans.lower_data = calcVif.cb.wr_data_lower; //write to SRAM A
          trans.upper_data = calcVif.cb.wr_data_upper; //write to SRAM B
          
          if (!written) begin
            written = 1;
            $display($stime, " Mon: Write to Addr: 0x%0x, Data to SRAM A (lower 32 bits): 0x%0x, Data to SRAM B (upper 32 bits): 0x%0x\n",
                trans.curr_wr_addr, trans.lower_data, trans.upper_data);
            mon_box.put(trans);
          end
        end else begin // Read
          written = 0;
          // TODO: For read operations, we need to wait until the data is available on the clocking block before sending the transaction to the scoreboard
          // Due to SRAM delay, we need to keep track of when we get a read and which address the read is for and get the actual data later (HINT use pending_read and pending_rd_addr).
          
          pending_read = 1; //waiting for data
          pending_rd_addr = calcVif.cb.curr_rd_addr;
        end
      end

      if (calcVif.cb.initialize) begin
        initialization_trans = new();
        // TODO: Assign the right fields for the transaction from the clocking block signals that are
        // relevant to initializing SRAM
        // HINT: How do you differentiate which data belongs to which SRAM block?

        initialization_trans.initialize = 1'b1;
        initialization_trans.curr_wr_addr = calcVif.cb.initialize_addr;
        initialization_trans.loc_sel = calcVif.cb.initialize_loc_sel;
       
        //Select SRAM block based on loc_sel
        if (!calcVif.cb.initialize_loc_sel) begin
        // Select SRAM A
        initialization_trans.lower_data = calcVif.cb.initialize_data;
        initialization_trans.upper_data = '0;
        end else begin
            // Select SRAM B
            initialization_trans.lower_data = '0;
            initialization_trans.upper_data = calcVif.cb.initialize_data;
        end

        $display($stime, " Mon: Initialize SRAM; Write to SRAM %s, Addr: 0x%0x, Data: 0x%0x\n", !calcVif.cb.initialize_loc_sel ? "A" : "B", calcVif.cb.initialize_addr, calcVif.cb.initialize_data);
        mon_box.put(initialization_trans);
      end
    end
  endtask : main

endclass : calc_monitor
