// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

`ifndef RNG_DEFINE_SVH
`define RNG_DEFINE_SVH

// verilog_format: off
`define RNG_CTRL_OFFSET              12'h000
`define RNG_STATUS_OFFSET            12'h004
`define RNG_DATA_OFFSET              12'h008
`define RNG_FIFO_STATUS_OFFSET       12'h00C
`define RNG_ERROR_STATUS_OFFSET      12'h010
`define RNG_INTR_STATE_OFFSET        12'h014
`define RNG_INTR_ENABLE_OFFSET       12'h018
`define RNG_INTR_TEST_OFFSET         12'h01C
`define RNG_CONFIG_OFFSET            12'h020
`define RNG_CONFIG_LOCK_OFFSET       12'h024
`define RNG_ACCEPTED_COUNT_OFFSET    12'h028
`define RNG_DISCARD_COUNT_OFFSET     12'h02C
`define RNG_HEALTH_FAIL_COUNT_OFFSET 12'h030
`define RNG_SOURCE_STATUS_OFFSET     12'h034
`define RNG_IP_ID_OFFSET             12'h0F4
`define RNG_IP_VERSION_OFFSET        12'h0F8
`define RNG_CAPABILITY_OFFSET        12'h0FC

`define RNG_CTRL_ENABLE_MASK         32'h0000_0001
`define RNG_CTRL_FLUSH_MASK          32'h0000_0002
`define RNG_CTRL_RECOVER_MASK        32'h0000_0004
`define RNG_CTRL_VALID_MASK          32'h0000_0007

`define RNG_ERROR_SOURCE_FAULT_MASK  32'h0000_0001
`define RNG_ERROR_DUPLICATE_MASK     32'h0000_0002
`define RNG_ERROR_QUAL_CHANGE_MASK   32'h0000_0004
`define RNG_ERROR_VALID_MASK         32'h0000_0007

`define RNG_INTR_DATA_READY_MASK     32'h0000_0001
`define RNG_INTR_HEALTH_FAIL_MASK    32'h0000_0002
`define RNG_INTR_SOURCE_FAULT_MASK   32'h0000_0004
`define RNG_INTR_VALID_MASK          32'h0000_0007

`define RNG_CONFIG_WATERMARK_MASK    32'h0000_00FF
`define RNG_CONFIG_LOCK_MASK         32'h0000_0001

`define RNG_IP_ID_VALUE              32'h524E_4732
`define RNG_IP_VERSION_VALUE         32'h0002_0000
`define RNG_CAPABILITY_FEATURES      8'h7F
`define RNG_ABI_VERSION              8'h02
// verilog_format: on

`endif
