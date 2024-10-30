//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2009 Authors and OPENCORES.ORG                 ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`timescale 1ns/10ps

module wb_size_bridge(
                        input         wb_hi_clk_i,
                        input         wb_hi_rst_i,
                        output [63:0] wb_hi_dat_o,
                        input  [63:0] wb_hi_dat_i,
                        input  [31:0] wb_hi_adr_i,
                        input         wb_hi_cyc_i,
                        input         wb_hi_stb_i,
                        input         wb_hi_we_i,
                        input  [7:0]  wb_hi_sel_i,
                        output        wb_hi_ack_o,
                        output        wb_hi_err_o,
                        output        wb_hi_rty_o,

                        output        wb_lo_clk_o,
                        output        wb_lo_rst_o,
                        input  [31:0] wb_lo_dat_i,
                        output [31:0] wb_lo_dat_o,
                        output [31:0] wb_lo_adr_o,
                        output        wb_lo_cyc_o,
                        output        wb_lo_stb_o,
                        output        wb_lo_we_o,
                        output [3:0]  wb_lo_sel_o,
                        input         wb_lo_ack_i,
                        input         wb_lo_err_i,
                        input         wb_lo_rty_i,
                        
                        input         lo_byte_if_i
                      );

  // --------------------------------------------------------------------
  //  state machine encoder
  reg [2:0] state_enc;
  
  wire state_enc_2_more_chunks  = state_enc[2];
  wire state_enc_1_more_chunks  = state_enc[1];
  wire state_enc_error          = state_enc[0];
  
  always @(*)
    case( { lo_byte_if_i, wb_hi_sel_i[7:0] } )
      9'b1_00000001:  state_enc = { 1'b0, 1'b0, 1'b0 };
      9'b1_00000010:  state_enc = { 1'b0, 1'b0, 1'b0 };
      9'b1_00000100:  state_enc = { 1'b0, 1'b0, 1'b0 };
      9'b1_00001000:  state_enc = { 1'b0, 1'b0, 1'b0 };
      9'b1_00001111:  state_enc = { 1'b0, 1'b1, 1'b0 };
      9'b1_11110000:  state_enc = { 1'b0, 1'b1, 1'b0 };
      9'b1_11111111:  state_enc = { 1'b1, 1'b0, 1'b0 };
      9'b0_00000001:  state_enc = { 1'b0, 1'b0, 1'b0 };
      9'b0_00000010:  state_enc = { 1'b0, 1'b0, 1'b0 };
      9'b0_00000100:  state_enc = { 1'b0, 1'b0, 1'b0 };
      9'b0_00001000:  state_enc = { 1'b0, 1'b0, 1'b0 };
      9'b0_00001111:  state_enc = { 1'b0, 1'b0, 1'b0 };
      9'b0_11110000:  state_enc = { 1'b0, 1'b0, 1'b0 };
      9'b0_11111111:  state_enc = { 1'b0, 1'b1, 1'b0 };
      default:        state_enc = { 1'b0, 1'b0, 1'b1 };
    endcase

  // --------------------------------------------------------------------
  //  state machine

  localparam   STATE_DONT_CARE     = 4'b????;
  localparam   STATE_PASS_THROUGH  = 4'b0001;
  localparam   STATE_1_MORE_CHUNK  = 4'b0010;
  localparam   STATE_2_MORE_CHUNK  = 4'b0100;

  reg [3:0] state;
  reg [3:0] next_state;

  always @(posedge wb_hi_clk_i or posedge wb_hi_rst_i)
    if(wb_hi_rst_i)
      state <= STATE_PASS_THROUGH;
    else
      state <= next_state;

  always @(*)
    case( state )
      STATE_PASS_THROUGH: if( state_enc_1_more_chunks & wb_lo_ack_i & wb_hi_stb_i & wb_hi_cyc_i )
                            next_state = STATE_1_MORE_CHUNK;
                          else if( state_enc_2_more_chunks & wb_lo_ack_i & wb_hi_stb_i & wb_hi_cyc_i )
                            next_state = STATE_2_MORE_CHUNK;
                          else
                            next_state = STATE_PASS_THROUGH;

      STATE_2_MORE_CHUNK: if( wb_lo_ack_i )
                            next_state = STATE_1_MORE_CHUNK;
                          else
                            next_state = STATE_2_MORE_CHUNK;

      STATE_1_MORE_CHUNK: if( wb_lo_ack_i )
                            next_state = STATE_PASS_THROUGH;
                          else
                            next_state = STATE_1_MORE_CHUNK;
                        
      default:            next_state = STATE_PASS_THROUGH;
    endcase

  // --------------------------------------------------------------------
  //  byte enable & select
  reg [7:0] byte_enable;
  localparam   BYTE_N_ENABLED  = 8'b00000000;
  localparam   BYTE_0_ENABLED  = 8'b00000001;
  localparam   BYTE_1_ENABLED  = 8'b00000010;
  localparam   BYTE_2_ENABLED  = 8'b00000100;
  localparam   BYTE_3_ENABLED  = 8'b00001000;
  localparam   BYTE_4_ENABLED  = 8'b00010000;
  localparam   BYTE_5_ENABLED  = 8'b00100000;
  localparam   BYTE_6_ENABLED  = 8'b01000000;
  localparam   BYTE_7_ENABLED  = 8'b10000000;

  reg [2:0] byte_select;
  localparam   BYTE_0_SELECTED  = 3'b000;
  localparam   BYTE_1_SELECTED  = 3'b001;
  localparam   BYTE_2_SELECTED  = 3'b010;
  localparam   BYTE_3_SELECTED  = 3'b011;
  localparam   BYTE_4_SELECTED  = 3'b100;
  localparam   BYTE_5_SELECTED  = 3'b101;
  localparam   BYTE_6_SELECTED  = 3'b110;
  localparam   BYTE_7_SELECTED  = 3'b111;
  localparam   BYTE_X_SELECTED  = 3'bxxx;

  always @(*)
    casez( { lo_byte_if_i, wb_hi_sel_i, state } )
      { 1'b1, 8'b00000001, STATE_PASS_THROUGH }:  byte_enable = BYTE_0_ENABLED;
      { 1'b1, 8'b00000010, STATE_PASS_THROUGH }:  byte_enable = BYTE_1_ENABLED;
      ...
      default:                                    byte_enable = BYTE_N_ENABLED;
    endcase

  always @(*)
    case( byte_enable )
      BYTE_0_ENABLED:  byte_select = BYTE_0_SELECTED;
      BYTE_1_ENABLED:  byte_select = BYTE_1_SELECTED;
      ...
      default:  byte_select = 3'bxxx;
    endcase

  // Continue updating remaining logic as per the 64-to-32-bit conversion.
