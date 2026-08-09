// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

module rng_formal_props #(
    parameter int FIFO_DEPTH = 4
) (
    // verilog_format: off
    input logic       clk_i,
    input logic       rst_n_i,
    input logic [7:0] fifo_level_i,
    input logic       fifo_empty_i,
    input logic       fatal_i,
    input logic       entropy_ready_i,
    input logic       irq_i,
    input logic [2:0] intr_state_i,
    input logic [2:0] intr_enable_i,
    input logic       config_lock_i,
    input logic       data_pop_i,
    input logic       startup_done_i,
    input logic       duplicate_event_i,
    input logic       source_fault_event_i,
    input logic       qualification_change_event_i,
    input logic       pslverr_i
    // verilog_format: on
);

  logic f_past_valid;

  initial f_past_valid = 1'b0;

  always @(posedge clk_i) begin
    f_past_valid <= 1'b1;

    assert (fifo_level_i <= FIFO_DEPTH);
    assert (irq_i == |(intr_state_i & intr_enable_i));
    if (rst_n_i && fatal_i) begin
      assert (!entropy_ready_i);
      assert (fifo_empty_i);
    end
    if (f_past_valid && rst_n_i && $past(rst_n_i && config_lock_i)) begin
      assert (config_lock_i);
    end
    if (data_pop_i) assert (!fifo_empty_i);

    cover (rst_n_i && startup_done_i);
    cover (rst_n_i && duplicate_event_i);
    cover (rst_n_i && source_fault_event_i);
    cover (rst_n_i && qualification_change_event_i);
    cover (rst_n_i && pslverr_i);
  end

endmodule

module rng_formal;

  (* gclk *)logic        clk;
  (* anyseq *)logic        rst_n;
  (* anyseq *)logic [11:0] paddr;
  (* anyseq *)logic        psel;
  (* anyseq *)logic        penable;
  (* anyseq *)logic        pwrite;
  (* anyseq *)logic [31:0] pwdata;
  (* anyseq *)logic [ 3:0] pstrb;
  (* anyseq *)logic        entropy_valid;
  (* anyseq *)logic [31:0] entropy_data;
  (* anyseq *)logic        entropy_qualified;
  (* anyseq *)logic        entropy_fault;

  logic        pready;
  logic [31:0] prdata;
  logic        pslverr;
  logic        entropy_enable;
  logic        entropy_ready;
  logic        irq;
  logic        f_past_valid;

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

  initial begin
    f_past_valid = 1'b0;
    assume (!rst_n);
  end

  always @(posedge clk) begin
    f_past_valid <= 1'b1;

    if (f_past_valid && $past(entropy_valid && !entropy_ready)) begin
      assume (entropy_valid);
      assume (entropy_data == $past(entropy_data));
      assume (entropy_qualified == $past(entropy_qualified));
      assume (entropy_fault == $past(entropy_fault));
    end

    assert (pready);
    assert (!pslverr || (psel && penable));
    assert (!entropy_ready || entropy_enable);
    cover (rst_n && entropy_enable);
    cover (rst_n && entropy_ready);
    cover (rst_n && irq);
    cover (rst_n && pslverr);
  end

endmodule
