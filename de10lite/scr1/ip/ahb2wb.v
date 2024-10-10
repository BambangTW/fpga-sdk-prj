
// Copyright (c) 2007 TooMuch Semiconductor Solutions Pvt Ltd.


//File name		:	ahb2wb.v
//Designer		: 	Manish Agarwal
//Date			: 	18 May, 2007
//Description	: 	AHB WISHBONE BRIDGE :- This design will connect AHB master interface with Wishbone slave.
//					This design will perform only single read-write operation.
//Revision		:	1.0


//******************************************************************************************************

// `timescale 1 ns/1 ns

// module ahb2wb(
// 	adr_o, dat_o, dat_i, ack_i, cyc_o,
// 	we_o, stb_o, hclk, hresetn, haddr, htrans, hwrite, hsize, hburst,
// 	hsel, hwdata, hrdata, hresp, hready, clk_i, rst_i
// 	);


// //parameter declaration
// 	parameter AWIDTH = 16;
// 	parameter DWIDTH = 32;


// //**************************************
// // input ports
// //**************************************

//  //wishbone ports		
// 	input [DWIDTH-1:0]dat_i;						// data input from wishbone slave
// 	input ack_i;									// acknowledment from wishbone slave
// 	input clk_i;
// 	input rst_i;
	
//  //AHB ports	
// 	input hclk; 									// clock
// 	input hresetn;									// active low reset
// 	input [DWIDTH-1:0]hwdata;						// data bus		
// 	input hwrite;									// write/read enable
// 	input [2:0]hburst;								// burst type
// 	input [2:0]hsize;								// data size
// 	input [1:0]htrans;								// type of transfer
// 	input hsel;										// slave select 
// 	input [AWIDTH-1:0]haddr;						// address bus	


// //**************************************
// // output ports
// //**************************************

//  //wishbone ports
// 	output [AWIDTH-1:0]adr_o;						// address to wishbone slave 
// 	output [DWIDTH-1:0]dat_o;						// data output for wishbone slave
// 	output cyc_o;									// signal to indicate valid bus cycle
// 	output we_o;									// write enable
// 	output stb_o;									// strobe to indicate valid data transfer cycle
		

//  // AHB ports
// 	output [DWIDTH-1:0]hrdata;						// data output for wishbone slave
// 	output [1:0]hresp;								// response signal from slave
// 	output hready;									// slave ready


// //**************************************
// // inout ports
// //**************************************


// //**********************************************************************************


// // datatype declaration
// 	reg [DWIDTH-1:0]hrdata;
// 	reg hready;
// 	reg [1:0]hresp;
// 	reg stb_o;
// 	wire we_o;
// 	reg cyc_o;
// 	wire [AWIDTH-1:0]adr_o;
// 	reg [DWIDTH-1:0]dat_o;
	
// // local memory registers
// 	reg [AWIDTH-1 : 0]addr_temp;
// 	reg hwrite_temp;								// to hold write enable signal temporarily

// //*******************************************************************
// // AHB WISHBONE BRIDGE logic
// //*******************************************************************
						
// 	assign #2 we_o = hwrite_temp;
// 	assign #2 adr_o = addr_temp;

// 	always @ (posedge hclk ) begin
// 		if (!hresetn) begin
// 			hresp  <= 2'b00;
// 			cyc_o <= 'b0;
// 			stb_o <= 'b0;
// 			addr_temp <= 'bx;
// 			hwrite_temp <= 'bx;
// 			dat_o <='bx;
// 		end
// 		else if(hready & hsel) begin
// 			case (hburst)
//  				// single transfer
// 				3'b000 	:	begin										
// 								case (htrans)
// 									// idle transfer type
// 									2'b00 :	begin
// 												cyc_o <= 'b0;
// 												hresp <= 2'b00;			// ok response
// 												stb_o <= 'b0;
											
// 											end

// 									// busy transfer type
// 									2'b01 :	begin						
// 												hresp <= 2'b00; 		// ok response
// 												stb_o <= 'b0;
// 												cyc_o <= 'b1;
// 											end
	
// 									// Non-Sequential
// 									2'b10 : begin
// 												cyc_o <= 'b1;
// 												stb_o <= 'b1;
// 												addr_temp <= haddr;
// 												hwrite_temp <= hwrite;			// control signal stored that was received in address phase
// 											end
// 								endcase
// 							end

// 				default	:	cyc_o <= 'b0;
// 			endcase
// 		end
// 		else if (!hsel & hready) begin
// 			cyc_o <= 'b0;					//invalid bus transfer
// 		end

// 	end


// // combinational logic - asynchronous read/write
// 	always@(hwrite_temp or hwdata or dat_i or ack_i or hresetn or stb_o ) begin
		
// 		if (!hresetn) begin
// 			hready <= 'b1;
// 		end
// 		else begin		
// 			if (stb_o) 
// 				hready = ack_i;

// 			if ( hwrite_temp ) 
// 				dat_o = hwdata;
// 			else if (!hwrite_temp) 
// 				hrdata = dat_i;
// 		end
						
// 	end	
		
// endmodule

module ahb2wb(
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
    parameter AWIDTH = 32;
    parameter DWIDTH = 32;

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