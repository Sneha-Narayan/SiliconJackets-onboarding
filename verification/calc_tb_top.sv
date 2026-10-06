module calc_tb_top;

  import calc_tb_pkg::*;
  import calculator_pkg::*;

  parameter int DataSize = DATA_W;
  parameter int AddrSize = ADDR_W;
  logic clk = 0;
  logic rst;
  state_t state;

  calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_if(.clk(clk));
  top_lvl my_calc(
    .clk(clk),
    .rst(calc_if.reset),
    .read_start_addr(calc_if.calc.read_start_addr),
    .read_end_addr(calc_if.calc.read_end_addr),
    .write_start_addr(calc_if.calc.write_start_addr),
    .write_end_addr(calc_if.calc.write_end_addr)
  );

  assign rst = calc_if.reset;
  assign state = my_calc.u_ctrl.state;
  assign calc_if.calc.wr_en = my_calc.write;
  assign calc_if.calc.rd_en = my_calc.read;
  assign calc_if.calc.wr_data_lower = my_calc.w_data_lower;
  assign calc_if.calc.wr_data_upper = my_calc.w_data_upper;
  assign calc_if.calc.rd_data_lower = my_calc.r_data_lower;
  assign calc_if.calc.rd_data_upper = my_calc.r_data_upper;
  assign calc_if.calc.ready = my_calc.u_ctrl.state == S_END;
  assign calc_if.calc.curr_rd_addr = my_calc.r_addr;
  assign calc_if.calc.curr_wr_addr = my_calc.w_addr;
  assign calc_if.calc.loc_sel = my_calc.loc_sel;


  calc_tb_pkg::calc_driver #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_driver_h;
  calc_tb_pkg::calc_sequencer #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_sequencer_h;
  calc_tb_pkg::calc_monitor #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_monitor_h;
  calc_tb_pkg::calc_sb #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_sb_h;

  always #5 clk = ~clk;

  task write_sram(input [AddrSize-1:0] addr, input [DataSize-1:0] data, input logic block_sel);
    @(posedge clk);
    if (!block_sel) begin
      my_calc.sram_A.memory_mode_inst.memory[addr] = data;
    end
    else begin
      my_calc.sram_B.memory_mode_inst.memory[addr] = data;
    end
    calc_driver_h.initialize_sram(addr, data, block_sel);
  endtask

  initial begin
    $shm_open("waves.shm");
    $shm_probe("AC");

    calc_monitor_h = new(calc_if);
    calc_sb_h = new(calc_monitor_h.mon_box);
    calc_sequencer_h = new();
    calc_driver_h = new(calc_if, calc_sequencer_h.calc_box);
    fork
      calc_monitor_h.main();
      calc_sb_h.main();
    join_none
    calc_if.reset <= 1;
    for (int i = 0; i < 2 ** AddrSize; i++) begin
      write_sram(i, $random, 0);
      write_sram(i, $random, 1);
    end

    repeat (100) @(posedge clk);

    // TODO: Add test cases according to your test plan. If you write additional test cases to reach
    // 98% coverage, make sure to add them to your test plan
    
    //0 + 0
    write_sram(0, 32'h0000_0000, 0); //lower half of A
    write_sram(0, 32'h0000_0000, 1); //upper half of A

    write_sram(1, 32'h0000_0000, 0); //lower half of B
    write_sram(1, 32'h0000_0000, 1); //upper half of B

    calc_driver_h.start_calc(0, 1, 2, 2); //Add address 0 for A + address 1 for B --> store in address 2
    @(calc_if.cb iff calc_if.cb.ready);

    //6 + 136
    write_sram(0, 32'h0000_0006, 0); //lower half of A
    write_sram(0, 32'h0000_0000, 1); //upper half of A

    write_sram(1, 32'h0000_0088, 0); //lower half of B
    write_sram(1, 32'h0000_0000, 1); //upper half of B

    calc_driver_h.start_calc(0, 1, 2, 2); //Add address 0 for A + address 1 for B --> store in address 2
    @(calc_if.cb iff calc_if.cb.ready);
    
    //0 + 3
    write_sram(0, 32'h0000_0000, 0); //lower half of A
    write_sram(0, 32'h0000_0000, 1); //upper half of A

    write_sram(1, 32'h0000_0003, 0); //lower half of B
    write_sram(1, 32'h0000_0000, 1); //upper half of B

    calc_driver_h.start_calc(0, 1, 2, 2); //Add address 0 for A + address 1 for B --> store in address 2
    @(calc_if.cb iff calc_if.cb.ready);

    //Lower buffer overflow
    write_sram(0, 32'hFFFF_FFFF, 0); //lower half of A
    write_sram(0, 32'h0000_0000, 1); //upper half of A

    write_sram(1, 32'hFFFF_FFFF, 0); //lower half of B
    write_sram(1, 32'h0000_0000, 1); //upper half of B

    calc_driver_h.start_calc(0, 1, 2, 2); //Add address 0 for A + address 1 for B --> store in address 2
    @(calc_if.cb iff calc_if.cb.ready);

    //Upper buffer overflow
    write_sram(0, 32'hFFFF_FFFF, 0); //lower half of A
    write_sram(0, 32'hFFFF_FFFF, 1); //upper half of A

    write_sram(1, 32'hFFFF_FFFF, 0); //lower half of B
    write_sram(1, 32'hFFFF_FFFF, 1); //upper half of B

    calc_driver_h.start_calc(0, 1, 2, 2); //Add address 0 for A + address 1 for B --> store in address 2
    @(calc_if.cb iff calc_if.cb.ready);

    //Lower buffer overflow
    write_sram(0, 32'hFFFF_FFFF, 0); //lower half of A
    write_sram(0, 32'h0000_0000, 1); //upper half of A

    write_sram(1, 32'h0000_0001, 0); //lower half of B
    write_sram(1, 32'h0000_0000, 1); //upper half of B

    calc_driver_h.start_calc(0, 1, 2, 2); //Add address 0 for A + address 1 for B --> store in address 2
    @(calc_if.cb iff calc_if.cb.ready);
    

    // TODO: Finish randomized testing
    // HINT: The sequencer is responsible for generating random input sequences. How can the
    // sequencer and driver be combined to generate multiple randomized test cases?
    
    calc_sequencer_h.gen(25);
    calc_driver_h.drive();

    repeat (100) @(posedge clk);

    $display("TEST PASSED");
    $finish;
  end

  /********************
        ASSERTIONS
  *********************/

  // TODO: Add Assertions

  //Assertion 1: Check IDLE after RESET
  property idle_after_reset;
    @(posedge clk)
    (rst) |=> (state == S_IDLE);
  endproperty
  assert_idle_after_reset: assert property(idle_after_reset)
    else $error("[ASSERTION] %0t: Did not reach IDLE state after reset", $time);


  //Assertion 2: Check that ADD happens before ADD2
  property add_before_add2;
    @(posedge clk) disable iff (rst)
    (state == S_ADD) |=> (state == S_ADD2);
  endproperty
  assert_add_before_add2: assert property(add_before_add2)
    else $error("[ASSERTION] %0t: S_ADD did not precede S_ADD2", $time);


  //Assertion 3: After ADD (during the second add) the buffer location will be set to 1 (the upper buffer)
  property high_during_add2;
    @(posedge clk) disable iff (rst)
    (state == S_ADD) |=> (calc_if.calc.loc_sel == 1); //after the state S_ADD, the buffer location will be 1
  endproperty
  assert_high_during_add2: assert property (high_during_add2)
    else $error("[ASSERTION] %0t: The buffer location is not high during the second add state", $time);
  
  //Assertion 4: After ADD2 the buffer location will be set to 0 (the lower buffer)
  property low_after_add2;
    @(posedge clk) disable iff (rst)
    (state == S_ADD2) |=> (calc_if.calc.loc_sel == 0); //after the state S_ADD2, the buffer location will be 0
  endproperty
  assert_low_after_add2:
  assert property (low_after_add2)
    else $error("[ASSERTION] %0t: The buffer location is not low after the second add state", $time);

  //Assertion 5: Check that READ happens before READ2
  property read_before_read2;
    @(posedge clk) disable iff (rst)
    (state == S_READ) |=> (state == S_READ2);
  endproperty
  assert_read_before_read2: assert property(read_before_read2)
    else $error("[ASSERTION] %0t: S_READ did not precede S_READ2", $time);

endmodule