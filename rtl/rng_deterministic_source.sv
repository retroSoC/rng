// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

// Deterministic integration source for simulation and non-security bring-up.
// It must never be presented as a qualified entropy source.
module rng_deterministic_source #(
    parameter logic [31:0] RESET_SEED = 32'h5A17_4C3D
) (
    // verilog_format: off
    input  logic        clk_i,
    input  logic        rst_n_i,
    input  logic        enable_i,
    input  logic        ready_i,
    output logic        valid_o,
    output logic [31:0] data_o,
    output logic        qualified_o,
    output logic        fault_o
    // verilog_format: on
);

  logic s_hold;

  assign s_hold      = !(enable_i && ready_i);
  assign valid_o     = enable_i;
  assign qualified_o = 1'b0;
  assign fault_o     = 1'b0;

  lfsr_galois #(
      .DATA_WIDTH(32),
      .POLY      (32'hE000_0200),
      .RESET_SEED(RESET_SEED)
  ) u_lfsr_galois (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .wr_i   (s_hold),
      .dat_i  (data_o),
      .dat_o  (data_o)
  );

endmodule
