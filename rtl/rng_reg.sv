// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

`include "rng_define.svh"

module rng_reg #(
    parameter int FIFO_DEPTH = 8
) (
    // verilog_format: off
    input  logic        clk_i,
    input  logic        rst_n_i,
    input  logic [11:0] paddr_i,
    input  logic        psel_i,
    input  logic        penable_i,
    input  logic        pwrite_i,
    input  logic [31:0] pwdata_i,
    input  logic [ 3:0] pstrb_i,
    output logic        pready_o,
    output logic [31:0] prdata_o,
    output logic        pslverr_o,
    output logic        entropy_enable_o,
    output logic        entropy_ready_o,
    input  logic        entropy_valid_i,
    input  logic [31:0] entropy_data_i,
    input  logic        entropy_qualified_i,
    input  logic        entropy_fault_i,
    output logic        irq_o
    // verilog_format: on
);

  localparam logic [7:0] FIFO_DEPTH_VALUE = 8'(FIFO_DEPTH);
  localparam logic [31:0] CAPABILITY_VALUE = {
    `RNG_ABI_VERSION, 8'h00, FIFO_DEPTH_VALUE, `RNG_CAPABILITY_FEATURES
  };

  logic        s_transfer;
  logic        s_read;
  logic        s_write;
  logic        s_access_legal;
  logic [31:0] s_write_mask;
  logic [31:0] s_masked_wdata;
  logic [31:0] s_ctrl_merged;
  logic [31:0] s_config_merged;
  logic [31:0] s_intr_enable_merged;
  logic        s_flush_command;
  logic        s_recover_command;
  logic        s_data_pop;

  logic s_enable_d, s_enable_q;
  logic [7:0] s_watermark_d, s_watermark_q;
  logic s_config_lock_d, s_config_lock_q;
  logic [2:0] s_error_status_d, s_error_status_q;
  logic [2:0] s_intr_state_d, s_intr_state_q;
  logic [2:0] s_intr_enable_d, s_intr_enable_q;

  logic [31:0] s_data;
  logic [ 7:0] s_fifo_level;
  logic        s_fifo_empty;
  logic        s_fifo_full;
  logic        s_startup_done;
  logic        s_active;
  logic        s_source_qualified;
  logic [31:0] s_accepted_count;
  logic [31:0] s_discard_count;
  logic [31:0] s_health_fail_count;
  logic        s_source_fault_event;
  logic        s_duplicate_event;
  logic        s_qualification_change_event;
  logic        s_data_ready;
  logic        s_fatal;

  assign s_transfer = psel_i && penable_i;
  assign s_read = s_transfer && !pwrite_i;
  assign s_write = s_transfer && pwrite_i;
  assign s_write_mask = {{8{pstrb_i[3]}}, {8{pstrb_i[2]}}, {8{pstrb_i[1]}}, {8{pstrb_i[0]}}};
  assign s_masked_wdata = pwdata_i & s_write_mask;
  assign s_ctrl_merged = ({31'h0, s_enable_q} & ~s_write_mask) | s_masked_wdata;
  assign s_config_merged = ({24'h0, s_watermark_q} & ~s_write_mask) | s_masked_wdata;
  assign s_intr_enable_merged = ({29'h0, s_intr_enable_q} & ~s_write_mask) | s_masked_wdata;
  assign s_fatal = |s_error_status_q;
  assign s_data_ready = !s_fifo_empty && (s_fifo_level >= s_watermark_q);
  assign pready_o = 1'b1;

  always_comb begin
    prdata_o       = '0;
    s_access_legal = (paddr_i[1:0] == 2'b00);

    if (s_read && s_access_legal) begin
      unique case (paddr_i)
        `RNG_CTRL_OFFSET:              prdata_o = {31'h0, s_enable_q};
        `RNG_STATUS_OFFSET: begin
          prdata_o = {
            16'h0000,
            s_fifo_level,
            s_config_lock_q,
            s_fatal,
            s_source_qualified,
            s_fifo_full,
            s_data_ready,
            s_startup_done,
            s_active,
            s_enable_q
          };
        end
        `RNG_DATA_OFFSET: begin
          prdata_o       = s_data;
          s_access_legal = !s_fifo_empty;
        end
        `RNG_FIFO_STATUS_OFFSET: begin
          prdata_o = {8'h00, s_watermark_q, 6'h00, s_fifo_full, s_fifo_empty, s_fifo_level};
        end
        `RNG_ERROR_STATUS_OFFSET:      prdata_o = {29'h0, s_error_status_q};
        `RNG_INTR_STATE_OFFSET:        prdata_o = {29'h0, s_intr_state_q};
        `RNG_INTR_ENABLE_OFFSET:       prdata_o = {29'h0, s_intr_enable_q};
        `RNG_CONFIG_OFFSET:            prdata_o = {24'h0, s_watermark_q};
        `RNG_CONFIG_LOCK_OFFSET:       prdata_o = {31'h0, s_config_lock_q};
        `RNG_ACCEPTED_COUNT_OFFSET:    prdata_o = s_accepted_count;
        `RNG_DISCARD_COUNT_OFFSET:     prdata_o = s_discard_count;
        `RNG_HEALTH_FAIL_COUNT_OFFSET: prdata_o = s_health_fail_count;
        `RNG_SOURCE_STATUS_OFFSET: begin
          prdata_o = {
            26'h0,
            entropy_enable_o,
            s_source_qualified,
            entropy_qualified_i,
            entropy_fault_i,
            entropy_ready_o,
            entropy_valid_i
          };
        end
        `RNG_IP_ID_OFFSET:             prdata_o = `RNG_IP_ID_VALUE;
        `RNG_IP_VERSION_OFFSET:        prdata_o = `RNG_IP_VERSION_VALUE;
        `RNG_CAPABILITY_OFFSET:        prdata_o = CAPABILITY_VALUE;
        default: begin
          prdata_o       = '0;
          s_access_legal = 1'b0;
        end
      endcase
    end else if (s_write && s_access_legal) begin
      unique case (paddr_i)
        `RNG_CTRL_OFFSET: begin
          s_access_legal = ((s_masked_wdata & ~`RNG_CTRL_VALID_MASK) == '0) &&
                           !((s_ctrl_merged & `RNG_CTRL_ENABLE_MASK) != '0 &&
                             (s_masked_wdata & `RNG_CTRL_RECOVER_MASK) != '0) &&
                           !((s_ctrl_merged & `RNG_CTRL_ENABLE_MASK) != '0 && s_fatal) &&
                           !((s_masked_wdata & `RNG_CTRL_RECOVER_MASK) != '0 && s_enable_q);
        end
        `RNG_ERROR_STATUS_OFFSET: begin
          s_access_legal = !s_enable_q && ((s_masked_wdata & ~`RNG_ERROR_VALID_MASK) == '0);
        end
        `RNG_INTR_STATE_OFFSET: begin
          s_access_legal = (s_masked_wdata & ~`RNG_INTR_VALID_MASK) == '0;
        end
        `RNG_INTR_ENABLE_OFFSET: begin
          s_access_legal = (s_intr_enable_merged & ~`RNG_INTR_VALID_MASK) == '0;
        end
        `RNG_INTR_TEST_OFFSET: begin
          s_access_legal = (s_masked_wdata & ~`RNG_INTR_VALID_MASK) == '0;
        end
        `RNG_CONFIG_OFFSET: begin
          s_access_legal = !s_enable_q && !s_config_lock_q &&
                           ((s_config_merged & ~`RNG_CONFIG_WATERMARK_MASK) == '0) &&
                           (s_config_merged[7:0] >= 1) &&
                           (s_config_merged[7:0] <= FIFO_DEPTH_VALUE);
        end
        `RNG_CONFIG_LOCK_OFFSET: begin
          s_access_legal = !s_enable_q && ((s_masked_wdata & ~`RNG_CONFIG_LOCK_MASK) == '0);
        end
        default: s_access_legal = 1'b0;
      endcase
    end else if (s_transfer) begin
      s_access_legal = 1'b0;
    end
  end

  assign pslverr_o = s_transfer && !s_access_legal;
  assign s_data_pop = s_read && s_access_legal && (paddr_i == `RNG_DATA_OFFSET);
  assign s_flush_command =
      s_write && s_access_legal && (paddr_i == `RNG_CTRL_OFFSET) &&
      ((s_masked_wdata & `RNG_CTRL_FLUSH_MASK) != '0);
  assign s_recover_command =
      s_write && s_access_legal && (paddr_i == `RNG_CTRL_OFFSET) &&
      ((s_masked_wdata & `RNG_CTRL_RECOVER_MASK) != '0);

  always_comb begin
    s_enable_d       = s_enable_q;
    s_watermark_d    = s_watermark_q;
    s_config_lock_d  = s_config_lock_q;
    s_error_status_d = s_error_status_q;
    s_intr_state_d   = s_intr_state_q;
    s_intr_enable_d  = s_intr_enable_q;

    if (s_write && s_access_legal) begin
      unique case (paddr_i)
        `RNG_CTRL_OFFSET:         s_enable_d = s_ctrl_merged[0];
        `RNG_ERROR_STATUS_OFFSET: s_error_status_d = s_error_status_q & ~s_masked_wdata[2:0];
        `RNG_INTR_STATE_OFFSET:   s_intr_state_d = s_intr_state_q & ~s_masked_wdata[2:0];
        `RNG_INTR_ENABLE_OFFSET:  s_intr_enable_d = s_intr_enable_merged[2:0];
        `RNG_INTR_TEST_OFFSET:    s_intr_state_d = s_intr_state_q | s_masked_wdata[2:0];
        `RNG_CONFIG_OFFSET:       s_watermark_d = s_config_merged[7:0];
        `RNG_CONFIG_LOCK_OFFSET:  s_config_lock_d = s_config_lock_q | s_masked_wdata[0];
        default: begin
        end
      endcase
    end

    s_error_status_d = s_error_status_d |
                       {s_qualification_change_event, s_duplicate_event, s_source_fault_event};
    s_intr_state_d = s_intr_state_d |
                     {s_source_fault_event,
                      s_duplicate_event | s_qualification_change_event,
                      s_data_ready};

    if (s_recover_command) begin
      s_error_status_d = '0;
      s_intr_state_d   = '0;
    end
  end

  rng_core #(
      .FIFO_DEPTH(FIFO_DEPTH)
  ) u_rng_core (
      .clk_i                       (clk_i),
      .rst_n_i                     (rst_n_i),
      .enable_i                    (s_enable_q),
      .flush_i                     (s_flush_command),
      .recover_i                   (s_recover_command),
      .fatal_i                     (s_fatal),
      .data_pop_i                  (s_data_pop),
      .data_o                      (s_data),
      .fifo_level_o                (s_fifo_level),
      .fifo_empty_o                (s_fifo_empty),
      .fifo_full_o                 (s_fifo_full),
      .startup_done_o              (s_startup_done),
      .active_o                    (s_active),
      .source_qualified_o          (s_source_qualified),
      .accepted_count_o            (s_accepted_count),
      .discard_count_o             (s_discard_count),
      .health_fail_count_o         (s_health_fail_count),
      .source_fault_event_o        (s_source_fault_event),
      .duplicate_event_o           (s_duplicate_event),
      .qualification_change_event_o(s_qualification_change_event),
      .entropy_enable_o            (entropy_enable_o),
      .entropy_ready_o             (entropy_ready_o),
      .entropy_valid_i             (entropy_valid_i),
      .entropy_data_i              (entropy_data_i),
      .entropy_qualified_i         (entropy_qualified_i),
      .entropy_fault_i             (entropy_fault_i)
  );

  dffer #(
      .DATA_WIDTH(1)
  ) u_enable_dffer (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .en_i   (1'b1),
      .dat_i  (s_enable_d),
      .dat_o  (s_enable_q)
  );

  dfferc #(
      .DATA_WIDTH(8),
      .RESET_VAL (8'd1)
  ) u_watermark_dfferc (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .en_i   (1'b1),
      .dat_i  (s_watermark_d),
      .dat_o  (s_watermark_q)
  );

  dffer #(
      .DATA_WIDTH(1)
  ) u_config_lock_dffer (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .en_i   (1'b1),
      .dat_i  (s_config_lock_d),
      .dat_o  (s_config_lock_q)
  );

  dffer #(
      .DATA_WIDTH(3)
  ) u_error_status_dffer (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .en_i   (1'b1),
      .dat_i  (s_error_status_d),
      .dat_o  (s_error_status_q)
  );

  dffer #(
      .DATA_WIDTH(3)
  ) u_intr_state_dffer (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .en_i   (1'b1),
      .dat_i  (s_intr_state_d),
      .dat_o  (s_intr_state_q)
  );

  dffer #(
      .DATA_WIDTH(3)
  ) u_intr_enable_dffer (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .en_i   (1'b1),
      .dat_i  (s_intr_enable_d),
      .dat_o  (s_intr_enable_q)
  );

  assign irq_o = |(s_intr_state_q & s_intr_enable_q);

`ifdef FORMAL
  rng_formal_props #(
      .FIFO_DEPTH(FIFO_DEPTH)
  ) u_rng_formal_props (
      .clk_i                       (clk_i),
      .rst_n_i                     (rst_n_i),
      .fifo_level_i                (s_fifo_level),
      .fifo_empty_i                (s_fifo_empty),
      .fatal_i                     (s_fatal),
      .entropy_ready_i             (entropy_ready_o),
      .irq_i                       (irq_o),
      .intr_state_i                (s_intr_state_q),
      .intr_enable_i               (s_intr_enable_q),
      .config_lock_i               (s_config_lock_q),
      .data_pop_i                  (s_data_pop),
      .startup_done_i              (s_startup_done),
      .duplicate_event_i           (s_duplicate_event),
      .source_fault_event_i        (s_source_fault_event),
      .qualification_change_event_i(s_qualification_change_event),
      .pslverr_i                   (pslverr_o)
  );
`endif

endmodule
