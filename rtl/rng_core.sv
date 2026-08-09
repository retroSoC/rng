// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

module rng_core #(
    parameter int FIFO_DEPTH = 8
) (
    // verilog_format: off
    input  logic        clk_i,
    input  logic        rst_n_i,
    input  logic        enable_i,
    input  logic        flush_i,
    input  logic        recover_i,
    input  logic        fatal_i,
    input  logic        data_pop_i,
    output logic [31:0] data_o,
    output logic [ 7:0] fifo_level_o,
    output logic        fifo_empty_o,
    output logic        fifo_full_o,
    output logic        startup_done_o,
    output logic        active_o,
    output logic        source_qualified_o,
    output logic [31:0] accepted_count_o,
    output logic [31:0] discard_count_o,
    output logic [31:0] health_fail_count_o,
    output logic        source_fault_event_o,
    output logic        duplicate_event_o,
    output logic        qualification_change_event_o,
    output logic        entropy_enable_o,
    output logic        entropy_ready_o,
    input  logic        entropy_valid_i,
    input  logic [31:0] entropy_data_i,
    input  logic        entropy_qualified_i,
    input  logic        entropy_fault_i
    // verilog_format: on
);

  localparam int FIFO_COUNT_WIDTH = $clog2(FIFO_DEPTH) + 1;

  logic                        s_accept;
  logic                        s_fifo_flush;
  logic                        s_fifo_push;
  logic [FIFO_COUNT_WIDTH-1:0] s_fifo_count;
  logic [31:0] s_previous_data_d, s_previous_data_q;
  logic s_previous_valid_d, s_previous_valid_q;
  logic s_source_qualified_d, s_source_qualified_q;
  logic s_startup_done_d, s_startup_done_q;
  logic [31:0] s_accepted_count_d, s_accepted_count_q;
  logic [31:0] s_discard_count_d, s_discard_count_q;
  logic [31:0] s_health_fail_count_d, s_health_fail_count_q;

  function automatic logic [31:0] saturating_increment(input logic [31:0] value);
    return (&value) ? value : value + 1'b1;
  endfunction

  initial begin
    if ((FIFO_DEPTH < 2) || (FIFO_DEPTH > 255) || ((FIFO_DEPTH & (FIFO_DEPTH - 1)) != 0)) begin
      $fatal(1, "rng_core: FIFO_DEPTH must be a power of two from 2 through 255");
    end
  end

  assign entropy_enable_o = enable_i && !fatal_i;
  assign source_fault_event_o = enable_i && !fatal_i && entropy_fault_i;
  assign qualification_change_event_o =
      enable_i && !fatal_i && s_previous_valid_q &&
      (entropy_qualified_i != s_source_qualified_q);
  assign entropy_ready_o = entropy_enable_o && !fifo_full_o && !entropy_fault_i &&
                           !qualification_change_event_o;
  assign s_accept = entropy_valid_i && entropy_ready_o;
  assign duplicate_event_o =
      s_accept && s_previous_valid_q && (entropy_data_i == s_previous_data_q);
  assign s_fifo_push = s_accept && s_previous_valid_q && !duplicate_event_o;
  assign s_fifo_flush = !enable_i || flush_i || recover_i || source_fault_event_o ||
                        duplicate_event_o || qualification_change_event_o;

  always_comb begin
    s_previous_data_d     = s_previous_data_q;
    s_previous_valid_d    = s_previous_valid_q;
    s_source_qualified_d  = s_source_qualified_q;
    s_startup_done_d      = s_startup_done_q;
    s_accepted_count_d    = s_accepted_count_q;
    s_discard_count_d     = s_discard_count_q;
    s_health_fail_count_d = s_health_fail_count_q;

    if (!enable_i) begin
      s_previous_data_d    = '0;
      s_previous_valid_d   = 1'b0;
      s_source_qualified_d = 1'b0;
      s_startup_done_d     = 1'b0;
    end

    if (recover_i) begin
      s_previous_data_d     = '0;
      s_previous_valid_d    = 1'b0;
      s_source_qualified_d  = 1'b0;
      s_startup_done_d      = 1'b0;
      s_accepted_count_d    = '0;
      s_discard_count_d     = '0;
      s_health_fail_count_d = '0;
    end else begin
      if (s_accept) begin
        s_accepted_count_d = saturating_increment(s_accepted_count_q);
        if (!s_previous_valid_q) begin
          s_previous_valid_d   = 1'b1;
          s_source_qualified_d = entropy_qualified_i;
          s_discard_count_d    = saturating_increment(s_discard_count_q);
        end
        if (!duplicate_event_o) begin
          s_previous_data_d = entropy_data_i;
        end
      end

      if (s_fifo_push) begin
        s_startup_done_d = 1'b1;
      end

      if (duplicate_event_o) begin
        s_discard_count_d = saturating_increment(s_discard_count_d);
      end

      if (source_fault_event_o || duplicate_event_o || qualification_change_event_o) begin
        s_startup_done_d      = 1'b0;
        s_health_fail_count_d = saturating_increment(s_health_fail_count_q);
      end
    end
  end

  fifo #(
      .DATA_WIDTH      (32),
      .BUFFER_DEPTH    (FIFO_DEPTH),
      .LOG_BUFFER_DEPTH($clog2(FIFO_DEPTH))
  ) u_entropy_fifo (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .flush_i(s_fifo_flush),
      .push_i (s_fifo_push),
      .full_o (fifo_full_o),
      .dat_i  (entropy_data_i),
      .pop_i  (data_pop_i),
      .empty_o(fifo_empty_o),
      .dat_o  (data_o),
      .cnt_o  (s_fifo_count)
  );

  dffer #(
      .DATA_WIDTH(32)
  ) u_previous_data_dffer (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .en_i   (1'b1),
      .dat_i  (s_previous_data_d),
      .dat_o  (s_previous_data_q)
  );

  dffer #(
      .DATA_WIDTH(1)
  ) u_previous_valid_dffer (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .en_i   (1'b1),
      .dat_i  (s_previous_valid_d),
      .dat_o  (s_previous_valid_q)
  );

  dffer #(
      .DATA_WIDTH(1)
  ) u_source_qualified_dffer (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .en_i   (1'b1),
      .dat_i  (s_source_qualified_d),
      .dat_o  (s_source_qualified_q)
  );

  dffer #(
      .DATA_WIDTH(1)
  ) u_startup_done_dffer (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .en_i   (1'b1),
      .dat_i  (s_startup_done_d),
      .dat_o  (s_startup_done_q)
  );

  dffer #(
      .DATA_WIDTH(32)
  ) u_accepted_count_dffer (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .en_i   (1'b1),
      .dat_i  (s_accepted_count_d),
      .dat_o  (s_accepted_count_q)
  );

  dffer #(
      .DATA_WIDTH(32)
  ) u_discard_count_dffer (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .en_i   (1'b1),
      .dat_i  (s_discard_count_d),
      .dat_o  (s_discard_count_q)
  );

  dffer #(
      .DATA_WIDTH(32)
  ) u_health_fail_count_dffer (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .en_i   (1'b1),
      .dat_i  (s_health_fail_count_d),
      .dat_o  (s_health_fail_count_q)
  );

  assign fifo_level_o        = 8'(s_fifo_count);
  assign startup_done_o      = s_startup_done_q;
  assign active_o            = enable_i && s_startup_done_q && !fatal_i;
  assign source_qualified_o  = s_source_qualified_q;
  assign accepted_count_o    = s_accepted_count_q;
  assign discard_count_o     = s_discard_count_q;
  assign health_fail_count_o = s_health_fail_count_q;

endmodule
