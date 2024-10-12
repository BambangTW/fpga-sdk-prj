//////////////////////////////////////////////////////////////////////
////                                                              ////
////  WISHBONE GPIO Definitions                                   ////
////                                                              ////
////  This file is part of the GPIO project                       ////
////  http://www.opencores.org/cores/gpio/                        ////
////                                                              ////
////  Description                                                 ////
////  GPIO IP Definitions.                                        ////
////                                                              ////
////  To Do:                                                      ////
////   Nothing                                                    ////
////                                                              ////
////  Author(s):                                                  ////
////      - Damjan Lampret, lampret@opencores.org                 ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2000 Authors and OPENCORES.ORG                 ////
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
//
// CVS Revision History
//
// $Log: not supported by cvs2svn $
// Revision 1.8  2003/12/17 13:00:52  gorand
// added ECLK and NEC registers, all tests passed.
//
// Revision 1.7  2003/12/01 17:10:44  simons
// ifndef directive is not supported by all tools.
//
// Revision 1.6  2003/11/06 13:59:07  gorand
// added support for 8-bit access to registers.
//
// Revision 1.2  2003/10/02 18:54:35  simons
// GPIO signals muxed with other peripherals, higland_board fixed.
//
// Revision 1.1.1.1  2003/06/24 09:09:23  simons
// This files were moved here from toplevel folder.
//
// Revision 1.1.1.1  2003/06/11 18:51:13  simons
// Initial import.
//
// Revision 1.5  2002/11/11 21:36:28  lampret
// Added ifdef to remove mux from clk_pad_i if mux is not allowed. This also removes RGPIO_CTRL[NEC].
//
// Revision 1.4  2002/05/06 18:25:31  lampret
// negedge flops are enabled by default.
//
// Revision 1.3  2001/12/25 17:12:35  lampret
// Added RGPIO_INTS.
//
// Revision 1.2  2001/11/15 02:24:37  lampret
// Added GPIO_REGISTERED_WB_OUTPUTS, GPIO_REGISTERED_IO_OUTPUTS and GPIO_NO_NEGEDGE_FLOPS.
//
// Revision 1.1  2001/09/18 18:49:07  lampret
// Changed top level ptc into gpio_top. Changed defines.v into gpio_defines.v.
//
// Revision 1.1  2001/08/21 21:39:28  lampret
// Changed directory structure, port names and drfines.
//
// Revision 1.3  2001/07/15 00:21:10  lampret
// Registers can be omitted and will have certain default values
//
// Revision 1.2  2001/07/14 20:39:26  lampret
// Better configurability.
//
// Revision 1.1  2001/06/05 07:45:26  lampret
// Added initial RTL and test benches. There are still some issues with these files.
//
//

//
// Number of GPIO I/O signals
//
// This is the most important parameter of the GPIO IP core. It defines how many
// I/O signals core has. Range is from 1 to 32. If more than 32 I/O signals are
// required, use several instances of GPIO IP core.
//
// Default is 16.
//
`define GPIO_IOS 8

// Comment out other GPIO_LINES definitions and define GPIO_LINES8
`define GPIO_LINES8

// Define other required macros
`define GPIO_IMPLEMENTED
`define GPIO_REGISTERED_WB_OUTPUTS
`define GPIO_REGISTERED_IO_OUTPUTS
`define GPIO_AUX_IMPLEMENT
// `define GPIO_CLKPAD // Not needed unless you have external clock for GPIO
`define GPIO_READREGS
`define GPIO_FULL_DECODE
// `define GPIO_STRICT_32BIT_ACCESS // We will allow 8-bit access
// Since we are not using strict 32-bit access, define GPIO_WB_BYTES1
`define GPIO_WB_BYTES1

// Define address bits for full decoding
`define GPIO_ADDRHH 7
`define GPIO_ADDRHL 0
`define GPIO_ADDRLH 0
`define GPIO_ADDRLL 0

// Define offset bits for partial decoding
`define GPIO_OFS_BITS 3:0

// Define addresses of GPIO registers
`define GPIO_RGPIO_IN    4'h0
`define GPIO_RGPIO_OUT   4'h1
`define GPIO_RGPIO_OE    4'h2
`define GPIO_RGPIO_INTE  4'h3
`define GPIO_RGPIO_PTRIG 4'h4
`define GPIO_RGPIO_AUX   4'h5
`define GPIO_RGPIO_CTRL  4'h6
`define GPIO_RGPIO_INTS  4'h7

// Default values for unimplemented registers
`define GPIO_DEF_RGPIO_IN    8'h00
`define GPIO_DEF_RGPIO_OUT   8'h00
`define GPIO_DEF_RGPIO_OE    8'h00
`define GPIO_DEF_RGPIO_INTE  8'h00
`define GPIO_DEF_RGPIO_PTRIG 8'h00
`define GPIO_DEF_RGPIO_AUX   8'h00
`define GPIO_DEF_RGPIO_CTRL  8'h00
`define GPIO_DEF_RGPIO_ECLK `GPIO_IOS'h0
`define GPIO_DEF_RGPIO_NEC `GPIO_IOS'h0

// RGPIO_CTRL bits
`define GPIO_RGPIO_CTRL_INTE 0
`define GPIO_RGPIO_CTRL_INTS 1
