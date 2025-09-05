// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// rng is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "apb4_if.svh"
`include "rng_define.svh"

module apb4_rng (
`ifdef __VERILOG__
    `apb4_slave_if(apb4)
`else
    apb4_if.slave apb4
`endif
);

`ifndef __VERILOG__
  `apb4_slave_if2wire(apb4, apb4);
`endif

  logic [3:0] s_apb4_addr;
  logic s_apb4_wr_hdshk, s_apb4_rd_hdshk;
  logic [`RNG_VAL_WIDTH-1:0] s_rng_val;
  logic [`RNG_CTRL_WIDTH-1:0] s_rng_ctrl_d, s_rng_ctrl_q;
  logic s_rng_ctrl_en;

  assign s_apb4_addr     = apb4_paddr[5:2];
  assign s_apb4_wr_hdshk = apb4_psel && apb4_penable && apb4_pwrite;
  assign s_apb4_rd_hdshk = apb4_psel && apb4_penable && (~apb4_pwrite);
  assign apb4_pready     = 1'b1;
  assign apb4_pslverr    = 1'b0;

  assign s_rng_ctrl_en   = s_apb4_wr_hdshk && s_apb4_addr == `RNG_CTRL;
  assign s_rng_ctrl_d    = apb4_pwdata[`RNG_CTRL_WIDTH-1:0];
  dffer #(`RNG_CTRL_WIDTH) u_rng_ctrl_dffer (
      apb4_pclk,
      apb4_presetn,
      s_rng_ctrl_en,
      s_rng_ctrl_d,
      s_rng_ctrl_q
  );

  // 32bits m-sequence
  lfsr_galois #(`RNG_VAL_WIDTH, 32'hE000_0200) u_lfsr_galois (
      .clk_i  (apb4_pclk),
      .rst_n_i(apb4_presetn),
      .wr_i   (s_apb4_wr_hdshk && s_apb4_addr == `RNG_SEED && s_rng_ctrl_q[0]),
      .dat_i  (apb4_pwdata[`RNG_VAL_WIDTH-1:0]),
      .dat_o  (s_rng_val)
  );

  always_comb begin
    apb4_prdata = '0;
    if (s_apb4_rd_hdshk) begin
      unique case (s_apb4_addr)
        `RNG_CTRL: apb4_prdata[`RNG_CTRL_WIDTH-1:0] = s_rng_ctrl_q;
        `RNG_VAL:  apb4_prdata[`RNG_VAL_WIDTH-1:0] = s_rng_val;
        default:   apb4_prdata = '0;
      endcase
    end
  end

endmodule
