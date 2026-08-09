// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

module apb4_rng #(
    parameter int FIFO_DEPTH = 8
) (
    // verilog_format: off
    output logic        entropy_enable_o,
    output logic        entropy_ready_o,
    input  logic        entropy_valid_i,
    input  logic [31:0] entropy_data_i,
    input  logic        entropy_qualified_i,
    input  logic        entropy_fault_i,
    output logic        irq_o,
    apb4_if.slave       apb4
    // verilog_format: on
);

  rng_reg #(
      .FIFO_DEPTH(FIFO_DEPTH)
  ) u_rng_reg (
      .clk_i              (apb4.pclk),
      .rst_n_i            (apb4.presetn),
      .paddr_i            (apb4.paddr[11:0]),
      .psel_i             (apb4.psel),
      .penable_i          (apb4.penable),
      .pwrite_i           (apb4.pwrite),
      .pwdata_i           (apb4.pwdata),
      .pstrb_i            (apb4.pstrb),
      .pready_o           (apb4.pready),
      .prdata_o           (apb4.prdata),
      .pslverr_o          (apb4.pslverr),
      .entropy_enable_o   (entropy_enable_o),
      .entropy_ready_o    (entropy_ready_o),
      .entropy_valid_i    (entropy_valid_i),
      .entropy_data_i     (entropy_data_i),
      .entropy_qualified_i(entropy_qualified_i),
      .entropy_fault_i    (entropy_fault_i),
      .irq_o              (irq_o)
  );

`ifndef SV_ASSRT_DISABLE
  xchecker #(
      .DATA_WIDTH(35)
  ) u_entropy_xchecker (
      .clk_i(apb4.pclk),
      .dat_i({
        entropy_valid_i,
        entropy_qualified_i,
        entropy_fault_i,
        entropy_valid_i ? entropy_data_i : 32'h0000_0000
      })
  );
`endif

endmodule
