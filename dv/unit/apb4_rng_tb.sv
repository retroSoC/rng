// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

`timescale 1ns / 1ps
`include "rng_define.svh"

module apb4_rng_tb;

  logic        clk;
  logic        rst_n;
  logic        entropy_enable;
  logic        entropy_ready;
  logic        entropy_valid;
  logic [31:0] entropy_data;
  logic        entropy_qualified;
  logic        entropy_fault;
  logic        irq;

  always #5 clk = ~clk;

  apb4_if u_apb4_if (
      .pclk   (clk),
      .presetn(rst_n)
  );

  rng_deterministic_source u_rng_deterministic_source (
      .clk_i      (clk),
      .rst_n_i    (rst_n),
      .enable_i   (entropy_enable),
      .ready_i    (entropy_ready),
      .valid_o    (entropy_valid),
      .data_o     (entropy_data),
      .qualified_o(entropy_qualified),
      .fault_o    (entropy_fault)
  );

  apb4_rng #(
      .FIFO_DEPTH(4)
  ) u_dut (
      .entropy_enable_o   (entropy_enable),
      .entropy_ready_o    (entropy_ready),
      .entropy_valid_i    (entropy_valid),
      .entropy_data_i     (entropy_data),
      .entropy_qualified_i(entropy_qualified),
      .entropy_fault_i    (entropy_fault),
      .irq_o              (irq),
      .apb4               (u_apb4_if)
  );

  task automatic apb_write(input logic [11:0] addr, input logic [31:0] data);
    @(negedge clk);
    u_apb4_if.paddr   = {20'h00000, addr};
    u_apb4_if.psel    = 1'b1;
    u_apb4_if.penable = 1'b0;
    u_apb4_if.pwrite  = 1'b1;
    u_apb4_if.pwdata  = data;
    u_apb4_if.pstrb   = 4'hF;
    @(negedge clk);
    u_apb4_if.penable = 1'b1;
    #1;
    if (!u_apb4_if.pready || u_apb4_if.pslverr) $fatal(1, "APB wrapper write failed");
    @(negedge clk);
    u_apb4_if.psel    = 1'b0;
    u_apb4_if.penable = 1'b0;
  endtask

  task automatic apb_read(input logic [11:0] addr, output logic [31:0] data);
    @(negedge clk);
    u_apb4_if.paddr   = {20'h00000, addr};
    u_apb4_if.psel    = 1'b1;
    u_apb4_if.penable = 1'b0;
    u_apb4_if.pwrite  = 1'b0;
    @(negedge clk);
    u_apb4_if.penable = 1'b1;
    #1;
    if (!u_apb4_if.pready || u_apb4_if.pslverr) $fatal(1, "APB wrapper read failed");
    data = u_apb4_if.prdata;
    @(negedge clk);
    u_apb4_if.psel    = 1'b0;
    u_apb4_if.penable = 1'b0;
  endtask

  logic [31:0] first_word;
  logic [31:0] second_word;
  logic [31:0] status;

  initial begin
    clk               = 1'b0;
    rst_n             = 1'b0;
    u_apb4_if.paddr   = '0;
    u_apb4_if.pprot   = '0;
    u_apb4_if.psel    = 1'b0;
    u_apb4_if.penable = 1'b0;
    u_apb4_if.pwrite  = 1'b0;
    u_apb4_if.pwdata  = '0;
    u_apb4_if.pstrb   = '0;

    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    apb_write(`RNG_INTR_ENABLE_OFFSET, `RNG_INTR_DATA_READY_MASK);
    apb_write(`RNG_CTRL_OFFSET, `RNG_CTRL_ENABLE_MASK);
    repeat (5) @(negedge clk);
    apb_read(`RNG_STATUS_OFFSET, status);
    if ((status & 32'h2C) != 32'h0C) $fatal(1, "deterministic source status mismatch");
    if (!irq) $fatal(1, "wrapper interrupt did not assert");
    apb_read(`RNG_DATA_OFFSET, first_word);
    repeat (2) @(negedge clk);
    apb_read(`RNG_DATA_OFFSET, second_word);
    if (first_word == second_word) $fatal(1, "deterministic source did not advance");

    $display("APB4_RNG_TEST_PASS");
    $finish;
  end

endmodule
