// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// rng is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`ifndef INC_RNG_DEF_SVH
`define INC_RNG_DEF_SVH

/* register mapping
 * RNG_CTRL:
 * BITS:   | 31:1 | 0  |
 * FIELDS: | RES  | EN |
 * PERMS:  | RW   | RW |
 * ---------------------
 * RNG_SEED:
 * BITS:   | 31:0 |
 * FIELDS: | SEED |
 * PERMS:  | WO   |
 * ---------------------
 * RNG_VAL:
 * BITS:   | 31:0 |
 * FIELDS: | VAL  |
 * PERMS:  | RO   |
 * ---------------------
*/

// verilog_format: off
`define RNG_CTRL 4'b0000 // BASEADDR + 0x00
`define RNG_SEED 4'b0001 // BASEADDR + 0x04
`define RNG_VAL  4'b0010 // BASEADDR + 0x08

`define RNG_CTRL_ADDR {26'b0, `RNG_CTRL, 2'b00}
`define RNG_SEED_ADDR {26'b0, `RNG_SEED, 2'b00}
`define RNG_VAL_ADDR  {26'b0, `RNG_VAL , 2'b00}

`define RNG_CTRL_WIDTH 1
`define RNG_SEED_WIDTH 32
`define RNG_VAL_WIDTH  32
// verilog_format: on

`endif