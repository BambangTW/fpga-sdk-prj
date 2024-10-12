// Copyright (c) 2024 NeuroEdge


//File name		:	ahb2wb.v
//Designer		: 	Bambang T. W.
//Date			: 	10 Oct 2024
//Description	: 	AHB WISHBONE BRIDGE
//Revision		:	1.0

// ahb2wb.v

`timescale 1ns / 1ps

module ahb2wb #(
    parameter AWIDTH = 32,
    parameter DWIDTH = 32
)(
    // Wishbone signals
    output reg  [AWIDTH-1:0] adr_o,   // Address output
    output reg  [DWIDTH-1:0] dat_o,   // Data output
    input       [DWIDTH-1:0] dat_i,   // Data input
    input                   ack_i,    // Acknowledge input
    output reg              cyc_o,    // Cycle output
    output reg              we_o,     // Write enable output
    output reg              stb_o,    // Strobe output
    // AHB signals
    input                   hclk,     // Clock input
    input                   hresetn,  // Reset (active low)
    input       [AWIDTH-1:0] haddr,    // AHB address bus
    input       [1:0]       htrans,   // AHB transfer type
    input                   hwrite,   // AHB write signal
    input       [2:0]       hsize,    // AHB transfer size
    input       [2:0]       hburst,   // AHB burst type
    input                   hsel,     // AHB slave select
    input       [DWIDTH-1:0] hwdata,   // AHB write data
    output reg  [DWIDTH-1:0] hrdata,   // AHB read data output
    output reg  [1:0]       hresp,    // AHB response
    output reg              hready,   // AHB ready signal
    input                   clk_i,    // Wishbone clock input
    input                   rst_i     // Wishbone reset input (active high)
);

    // Internal signals
    reg [AWIDTH-1:0] addr_reg;
    reg              hwrite_reg;
    reg              transaction_active;

    // AHB to Wishbone conversion logic
    always @(posedge hclk or negedge hresetn) begin
        if (!hresetn) begin
            adr_o           <= 0;
            dat_o           <= 0;
            cyc_o           <= 0;
            we_o            <= 0;
            stb_o           <= 0;
            hready          <= 1;
            hrdata          <= 0;
            hresp           <= 2'b00; // OKAY response
            addr_reg        <= 0;
            hwrite_reg      <= 0;
            transaction_active <= 0;
        end else begin
            if (hsel && hready && htrans[1]) begin
                // Start of a new transaction
                adr_o      <= haddr;
                addr_reg   <= haddr;
                we_o       <= hwrite;
                hwrite_reg <= hwrite;
                cyc_o      <= 1;
                stb_o      <= 1;
                hready     <= 0;
                transaction_active <= 1;

                if (hwrite) begin
                    dat_o <= hwdata;
                end
            end else if (transaction_active && ack_i) begin
                // Transaction completed
                cyc_o      <= 0;
                stb_o      <= 0;
                hready     <= 1;
                transaction_active <= 0;

                if (!hwrite_reg) begin
                    hrdata <= dat_i;
                end
            end else if (!transaction_active) begin
                hready <= 1;
            end
        end
    end

endmodule