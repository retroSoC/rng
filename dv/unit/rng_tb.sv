// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

`timescale 1ns / 1ps
`include "rng_define.svh"

module rng_tb;

  logic        clk;
  logic        rst_n;
  logic [11:0] paddr;
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [31:0] pwdata;
  logic [ 3:0] pstrb;
  logic        pready;
  logic [31:0] prdata;
  logic        pslverr;
  logic        entropy_enable;
  logic        entropy_ready;
  logic        entropy_valid;
  logic [31:0] entropy_data;
  logic        entropy_qualified;
  logic        entropy_fault;
  logic        irq;

  always #5 clk = ~clk;

  rng_reg #(
      .FIFO_DEPTH(4)
  ) u_dut (
      .clk_i              (clk),
      .rst_n_i            (rst_n),
      .paddr_i            (paddr),
      .psel_i             (psel),
      .penable_i          (penable),
      .pwrite_i           (pwrite),
      .pwdata_i           (pwdata),
      .pstrb_i            (pstrb),
      .pready_o           (pready),
      .prdata_o           (prdata),
      .pslverr_o          (pslverr),
      .entropy_enable_o   (entropy_enable),
      .entropy_ready_o    (entropy_ready),
      .entropy_valid_i    (entropy_valid),
      .entropy_data_i     (entropy_data),
      .entropy_qualified_i(entropy_qualified),
      .entropy_fault_i    (entropy_fault),
      .irq_o              (irq)
  );

  task automatic apb_write(input logic [11:0] addr, input logic [31:0] data, input logic [3:0] strb,
                           input logic expected_error);
    @(negedge clk);
    paddr   = addr;
    psel    = 1'b1;
    penable = 1'b0;
    pwrite  = 1'b1;
    pwdata  = data;
    pstrb   = strb;
    @(negedge clk);
    penable = 1'b1;
    #1;
    if (!pready || (pslverr != expected_error)) begin
      $fatal(1, "APB write mismatch addr=%h error=%b expected=%b", addr, pslverr, expected_error);
    end
    @(negedge clk);
    psel    = 1'b0;
    penable = 1'b0;
    pwrite  = 1'b0;
    pwdata  = '0;
    pstrb   = '0;
  endtask

  task automatic apb_read(input logic [11:0] addr, output logic [31:0] data,
                          input logic expected_error);
    @(negedge clk);
    paddr   = addr;
    psel    = 1'b1;
    penable = 1'b0;
    pwrite  = 1'b0;
    pstrb   = '0;
    @(negedge clk);
    penable = 1'b1;
    #1;
    data = prdata;
    if (!pready || (pslverr != expected_error)) begin
      $fatal(1, "APB read mismatch addr=%h error=%b expected=%b", addr, pslverr, expected_error);
    end
    @(negedge clk);
    psel    = 1'b0;
    penable = 1'b0;
  endtask

  task automatic push_word(input logic [31:0] data);
    while (!entropy_ready) @(negedge clk);
    entropy_data  = data;
    entropy_valid = 1'b1;
    @(negedge clk);
    entropy_valid = 1'b0;
    entropy_data  = '0;
  endtask

  task automatic expect_mask(input logic [31:0] value, input logic [31:0] mask,
                             input logic [31:0] expected, input string label);
    if ((value & mask) != expected) begin
      $fatal(1, "%s value=%h mask=%h expected=%h", label, value, mask, expected);
    end
  endtask

  logic [31:0] value;

  initial begin
    clk               = 1'b0;
    rst_n             = 1'b0;
    paddr             = '0;
    psel              = 1'b0;
    penable           = 1'b0;
    pwrite            = 1'b0;
    pwdata            = '0;
    pstrb             = '0;
    entropy_valid     = 1'b0;
    entropy_data      = '0;
    entropy_qualified = 1'b1;
    entropy_fault     = 1'b0;

    repeat (3) @(negedge clk);
    rst_n = 1'b1;

    apb_read(`RNG_IP_ID_OFFSET, value, 1'b0);
    if (value != `RNG_IP_ID_VALUE) $fatal(1, "IP ID mismatch");
    apb_read(`RNG_IP_VERSION_OFFSET, value, 1'b0);
    if (value != `RNG_IP_VERSION_VALUE) $fatal(1, "IP version mismatch");
    apb_read(`RNG_DATA_OFFSET, value, 1'b1);
    apb_read(12'h003, value, 1'b1);
    apb_read(12'h080, value, 1'b1);
    apb_write(`RNG_STATUS_OFFSET, 32'h1, 4'hF, 1'b1);
    apb_read(`RNG_INTR_TEST_OFFSET, value, 1'b1);

    apb_write(`RNG_CONFIG_OFFSET, 32'd2, 4'hF, 1'b0);
    apb_write(`RNG_CONFIG_LOCK_OFFSET, 32'd1, 4'h1, 1'b0);
    apb_write(`RNG_CONFIG_OFFSET, 32'd1, 4'hF, 1'b1);
    apb_write(`RNG_INTR_ENABLE_OFFSET, `RNG_INTR_VALID_MASK, 4'hF, 1'b0);
    apb_write(`RNG_CTRL_OFFSET, `RNG_CTRL_ENABLE_MASK, 4'h1, 1'b0);
    if (!entropy_enable) $fatal(1, "entropy source was not enabled");

    push_word(32'h0123_4567);
    apb_read(`RNG_STATUS_OFFSET, value, 1'b0);
    expect_mask(value, 32'h0000_0004, 32'h0000_0000, "startup before second word");
    push_word(32'h89AB_CDEF);
    push_word(32'hCAFE_BABE);
    @(negedge clk);
    if (!irq) $fatal(1, "data-ready interrupt not asserted");
    apb_read(`RNG_STATUS_OFFSET, value, 1'b0);
    expect_mask(value, 32'h0000_006C, 32'h0000_002C, "qualified active status");
    apb_read(`RNG_DATA_OFFSET, value, 1'b0);
    if (value != 32'h89AB_CDEF) $fatal(1, "first FIFO word mismatch");
    apb_read(`RNG_DATA_OFFSET, value, 1'b0);
    if (value != 32'hCAFE_BABE) $fatal(1, "second FIFO word mismatch");
    apb_write(`RNG_INTR_STATE_OFFSET, `RNG_INTR_DATA_READY_MASK, 4'h1, 1'b0);

    push_word(32'hCAFE_BABE);
    repeat (2) @(negedge clk);
    apb_read(`RNG_ERROR_STATUS_OFFSET, value, 1'b0);
    expect_mask(value, `RNG_ERROR_DUPLICATE_MASK, `RNG_ERROR_DUPLICATE_MASK, "duplicate error");
    apb_read(`RNG_DATA_OFFSET, value, 1'b1);
    if (!irq || entropy_ready) $fatal(1, "fail-closed behavior missing");
    apb_write(`RNG_CTRL_OFFSET, 32'h0, 4'h1, 1'b0);
    apb_write(`RNG_CTRL_OFFSET, `RNG_CTRL_RECOVER_MASK, 4'h1, 1'b0);
    apb_read(`RNG_ERROR_STATUS_OFFSET, value, 1'b0);
    if (value != 32'h0) $fatal(1, "recover did not clear errors");

    entropy_qualified = 1'b0;
    apb_write(`RNG_CTRL_OFFSET, `RNG_CTRL_ENABLE_MASK, 4'h1, 1'b0);
    push_word(32'h1111_1111);
    push_word(32'h2222_2222);
    apb_read(`RNG_STATUS_OFFSET, value, 1'b0);
    expect_mask(value, 32'h0000_0020, 32'h0000_0000, "unqualified status");
    apb_read(`RNG_DATA_OFFSET, value, 1'b0);
    if (value != 32'h2222_2222) $fatal(1, "unqualified diagnostic data mismatch");

    push_word(32'h3333_3333);
    apb_write(`RNG_CTRL_OFFSET, `RNG_CTRL_ENABLE_MASK | `RNG_CTRL_FLUSH_MASK, 4'h1, 1'b0);
    apb_read(`RNG_DATA_OFFSET, value, 1'b1);

    entropy_qualified = 1'b1;
    @(negedge clk);
    entropy_qualified = 1'b0;
    repeat (2) @(negedge clk);
    apb_read(`RNG_ERROR_STATUS_OFFSET, value, 1'b0);
    expect_mask(value, `RNG_ERROR_QUAL_CHANGE_MASK, `RNG_ERROR_QUAL_CHANGE_MASK,
                "qualification change");
    apb_write(`RNG_CTRL_OFFSET, 32'h0, 4'h1, 1'b0);
    apb_write(`RNG_CTRL_OFFSET, `RNG_CTRL_RECOVER_MASK, 4'h1, 1'b0);
    apb_write(`RNG_CTRL_OFFSET, `RNG_CTRL_ENABLE_MASK, 4'h1, 1'b0);
    push_word(32'h4444_4444);
    push_word(32'h5555_5555);

    entropy_fault = 1'b1;
    @(negedge clk);
    entropy_fault = 1'b0;
    repeat (2) @(negedge clk);
    apb_read(`RNG_ERROR_STATUS_OFFSET, value, 1'b0);
    expect_mask(value, `RNG_ERROR_SOURCE_FAULT_MASK, `RNG_ERROR_SOURCE_FAULT_MASK, "source fault");
    apb_read(`RNG_ACCEPTED_COUNT_OFFSET, value, 1'b0);
    if (value != 32'd2) $fatal(1, "accepted counter mismatch");
    apb_read(`RNG_HEALTH_FAIL_COUNT_OFFSET, value, 1'b0);
    if (value != 32'd1) $fatal(1, "health failure counter mismatch");

    $display("RNG_TEST_PASS");
    $finish;
  end

endmodule
