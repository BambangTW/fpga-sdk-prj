///////////////////////////////////////////////////////////////////////////////
// Vitor Finotti
//
// <project-url>
///////////////////////////////////////////////////////////////////////////////
//
// unit name:     Wishbone to AHB3-Lite bridge
//
// description: Bridge for conversion from a Wishbone master to a AHB3-Lite slave.
//   Inspired on the code of
//   https://www.valpont.com/ahb-to-wishbone-and-wishbone-to-ahb-bridges-in-verilog/pst/
//
// Updated by:    Bambang T. Wibowo
// Update date:   23/10/2024
// Description:   Updated to SystemVerilog and improved the readability.
//
///////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019 Vitor Finotti
// Copyright (c) 2024 Bambang T. Wibowo
///////////////////////////////////////////////////////////////////////////////
// MIT
///////////////////////////////////////////////////////////////////////////////
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is furnished to do
// so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
///////////////////////////////////////////////////////////////////////////////

module wb_to_ahb3lite (
    input  logic        clk_i,
    input  logic        rst_n_i,

    // Wishbone Interface
    input  logic [31:0] from_m_wb_adr_o,
    input  logic [3:0]  from_m_wb_sel_o,
    input  logic        from_m_wb_we_o,
    input  logic [31:0] from_m_wb_dat_o,
    input  logic        from_m_wb_cyc_o,
    input  logic        from_m_wb_stb_o,
    output logic        to_m_wb_ack_i,
    output logic        to_m_wb_err_i,
    output logic [31:0] to_m_wb_dat_i,

    input  logic [2:0]  from_m_wb_cti_o,
    input  logic [1:0]  from_m_wb_bte_o,

    // AHB3-Lite Interface
    input  logic [31:0] mHRDATA,
    input  logic        mHRESP,
    input  logic        mHREADY,
    output logic        mHSEL,
    output logic [2:0]  mHSIZE,
    output logic        mHWRITE,
    output logic [2:0]  mHBURST,
    output logic [31:0] mHADDR,
    output logic [1:0]  mHTRANS,
    output logic [31:0] mHWDATA,
    output logic        mHREADYOUT,
    output logic [3:0]  mHPROT
);

    // Parameters for AHB transfer types
    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        BUSY   = 2'b01,
        NONSEQ = 2'b10,
        SEQ    = 2'b11
    } ahb_trans_t;

    // Internal signals
    logic         ackmask;
    logic         ctrlstart;
    logic         mHREADY_d1;
    logic         isburst;

    // Burst detection
    assign isburst = (from_m_wb_cti_o != 3'b000);

    // Wishbone to AHB data mapping
    assign to_m_wb_dat_i = mHRDATA;
    assign to_m_wb_ack_i = ackmask & mHREADY & from_m_wb_stb_o;

    // AHB Addressing Logic
    assign mHADDR = (~isburst || (ctrlstart && !ackmask) || !ctrlstart)
                    ? from_m_wb_adr_o
                    : from_m_wb_adr_o + 3'b100;

    // AHB Write Data
    assign mHWDATA = from_m_wb_dat_o;

    // AHB Transfer Size (32-bit word)
    assign mHSIZE = 3'b010;

    // AHB Burst Type Logic
    assign mHBURST = (ctrlstart && (from_m_wb_cti_o == 3'b010)) ? 3'b011 : 3'b000;

    // AHB Write Signal
    assign mHWRITE = from_m_wb_we_o;

    // AHB Transaction Control
    assign mHTRANS = (ctrlstart && !ackmask && mHREADY)
                     ? NONSEQ
                     : ((ctrlstart && !to_m_wb_ack_i)
                     ? NONSEQ
                     : ( (from_m_wb_cti_o == 3'b010 && ctrlstart) ? SEQ : IDLE ));

    // Error handling
    assign to_m_wb_err_i = mHRESP;

    // AHB Select Signal
    assign mHSEL = from_m_wb_cyc_o;

    // AHB Ready Output (Always ready)
    assign mHREADYOUT = 1'b1;

    // Sequential logic for mHREADY delayed signal
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i)
            mHREADY_d1 <= 1'b0;
        else
            mHREADY_d1 <= mHREADY;
    end

    // Control start logic
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i)
            ctrlstart <= 1'b0;
        else if (mHREADY && !ctrlstart)
            ctrlstart <= 1'b1;
        else
            ctrlstart <= ctrlstart;
    end

    // Acknowledge mask logic
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i)
            ackmask <= 1'b0;
        else if (!from_m_wb_stb_o)
            ackmask <= 1'b0;
        else if (!ctrlstart && !ackmask)
            ackmask <= 1'b0;
        else if (ctrlstart && !to_m_wb_ack_i && mHREADY)
            ackmask <= 1'b1;
        else if (ctrlstart && !to_m_wb_ack_i && !mHREADY_d1 && mHREADY)
            ackmask <= 1'b1;
        else if (to_m_wb_ack_i && !isburst)
            ackmask <= 1'b0;
        else if (from_m_wb_cti_o == 3'b111 && mHREADY)
            ackmask <= 1'b0;
        else
            ackmask <= 1'b0;
    end

endmodule
