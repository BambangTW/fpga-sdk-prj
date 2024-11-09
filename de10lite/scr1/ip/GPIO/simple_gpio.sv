/////////////////////////////////////////////////////////////////////
////                                                             ////
////  OpenCores Simple General Purpose IO core                   ////
////                                                             ////
////  Author: Richard Herveille                                  ////
////          richard@asics.ws                                   ////
////          www.asics.ws                                       ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2002 Richard Herveille                        ////
////                    richard@asics.ws                         ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////

//  CVS Log
//
//  $Id: simple_gpio.v,v 1.2 2002-12-22 16:10:17 rherveille Exp $
//
//  $Date: 2002-12-22 16:10:17 $
//  $Revision: 1.2 $
//  $Author: rherveille $
//  $Locker:  $
//  $State: Exp $
//
// Change History:
//               $Log: not supported by cvs2svn $
//



//
// Very basic 8bit GPIO core
//
//
// Registers:
//
// 0x00: Control Register   <io[7:0]>
//       bits 7:0 R/W Input/Output    '1' = output mode
//                                    '0' = input mode
// 0x01: Line Register
//       bits 7:0 R   Status                Current GPIO pin level
//                W   Output                GPIO pin output level
//
//
// HOWTO:
//
// Use a pin as an input:
// Program the corresponding bit in the control register to 'input mode' ('0').
// The pin's state (input level) can be checked by reading the Line Register.
// Writing to the GPIO pin's Line Register bit while in input mode has no effect.
//
// Use a pin as an output:
// Program the corresponding bit in the control register to 'output mode' ('1').
// Program the GPIO pin's output level by writing to the corresponding bit in
// the Line Register.
// Reading the GPIO pin's Line Register bit while in output mode returns the
// current output level.
//
// Addapt the core for fewer GPIOs:
// If less than 8 GPIOs are required, than the 'io' parameter can be set to
// the amount of required interrupts. GPIOs are mapped starting at the LSBs.
// So only the 'io' LSBs per register are valid.
// All other bits (i.e. the 8-'io' MSBs) are set to zero '0'.
// Codesize is approximately linear to the amount of interrupts. I.e. using
// 4 instead of 8 GPIO sources reduces the size by approx. half.
//

module simple_gpio #(
    parameter io = 8   // number of GPIOs, with a max of 8
)(
    input  logic        clk_i,         // clock
    input  logic        rst_i,         // asynchronous active low reset
    input  logic        cyc_i,         // cycle signal
    input  logic        stb_i,         // strobe signal
    input  logic        adr_i,         // address bit (adr_i[1])
    input  logic        we_i,          // write enable
    input  logic [7:0]  dat_i,         // data input from WISHBONE
    output logic [7:0]  dat_o,         // data output to WISHBONE
    output logic        ack_o,         // acknowledge signal
    inout  tri   [io-1:0] gpio         // GPIO pins
);

    // Internal registers
    logic [io-1:0] ctrl;               // Control register to set GPIO direction
    logic [io-1:0] line;               // Data register for output values
    logic [io-1:0] lgpio, llgpio;      // Latched GPIO inputs for stability

    // WISHBONE interface signals
    wire wb_acc = cyc_i & stb_i;       // WISHBONE access signal
    wire wb_wr  = wb_acc & we_i;       // WISHBONE write access signal

    // Control and Line register write logic
    always_ff @(posedge clk_i or negedge rst_i) begin
        if (!rst_i) begin
            ctrl <= {io{1'b0}};        // Reset control register to input (0)
            line <= {io{1'b0}};        // Reset line register to 0
        end else if (wb_wr) begin
            if (adr_i)
                line <= dat_i[io-1:0]; // Write data to line register
            else
                ctrl <= dat_i[io-1:0]; // Write data to control register
        end
    end

    // Data output logic
    always_ff @(posedge clk_i) begin
        if (adr_i)
            dat_o <= { {(8-io){1'b0}}, llgpio }; // Output latched GPIO inputs
        else
            dat_o <= { {(8-io){1'b0}}, ctrl };    // Output control register
    end

    // Acknowledge signal generation
    always_ff @(posedge clk_i or negedge rst_i) begin
        if (!rst_i)
            ack_o <= 1'b0;
        else
            ack_o <= wb_acc & !ack_o; // Assert ACK for one cycle after a transaction
    end

    // Latching GPIO inputs for stability
    always_ff @(posedge clk_i) begin
        lgpio <= gpio;    // Latch GPIO inputs
        llgpio <= lgpio;  // Second latch to reduce metastability risk
    end

    // GPIO output driver logic
    logic [io-1:0] igpio; // Intermediate signal for GPIO output control
    integer n;
    always_comb begin
        for (n = 0; n < io; n = n + 1) begin
            igpio[n] = ctrl[n] ? line[n] : 1'bz; // Drive output or high-impedance based on control
        end
    end
    assign gpio = igpio;

endmodule
