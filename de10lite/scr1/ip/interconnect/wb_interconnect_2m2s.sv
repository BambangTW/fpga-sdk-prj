`timescale 1ns / 1ps

module wb_interconnect_2m2s (
    input logic        clk_i, 
    input logic        rst_n,

    // Master 0 Interface
    input   logic	[31:0]	m0_wbd_dat_i,
    input   logic   [31:0]	m0_wbd_adr_i,
    input   logic   [3:0]	m0_wbd_sel_i,
    input   logic  	        m0_wbd_we_i,
    input   logic  	        m0_wbd_cyc_i,
    input   logic  	        m0_wbd_stb_i,
    output  logic	[31:0]	m0_wbd_dat_o,
    output  logic		    m0_wbd_ack_o,
    output  logic		    m0_wbd_err_o,
    
    // Master 1 Interface
    input	logic [31:0]	m1_wbd_dat_i,
    input	logic [31:0]	m1_wbd_adr_i,
    input	logic [3:0]	    m1_wbd_sel_i,
    input	logic 	        m1_wbd_we_i,
    input	logic 	        m1_wbd_cyc_i,
    input	logic 	        m1_wbd_stb_i,
    output	logic [31:0]	m1_wbd_dat_o,
    output	logic 	        m1_wbd_ack_o,
    output	logic 	        m1_wbd_err_o,
    
    // Slave 0 Interface (UART)
    input	logic [31:0]	s0_wbd_dat_i,
    input	logic 	        s0_wbd_ack_i,
    output	logic [31:0]	s0_wbd_dat_o,
    output	logic [31:0]	s0_wbd_adr_o,
    output	logic [3:0]	    s0_wbd_sel_o,
    output	logic 	        s0_wbd_we_o,
    output	logic 	        s0_wbd_cyc_o,
    output	logic 	        s0_wbd_stb_o,
    
    // Slave 1 Interface (SRAM)
    input	logic [31:0]	s1_wbd_dat_i,
    input	logic 	        s1_wbd_ack_i,
    output	logic [31:0]	s1_wbd_dat_o,
    output	logic [31:0]	s1_wbd_adr_o,
    output	logic [3:0]	    s1_wbd_sel_o,
    output	logic 	        s1_wbd_we_o,
    output	logic 	        s1_wbd_cyc_o,
    output	logic 	        s1_wbd_stb_o
);

// Type Definitions
parameter TARGET_UART = 4'b0000;
parameter TARGET_SRAM = 4'b0001;

// Wishbone Write Interface
typedef struct packed { 
  logic	[31:0]	wbd_dat;
  logic  [31:0]	wbd_adr;
  logic  [3:0]	wbd_sel;
  logic  	    wbd_we;
  logic  	    wbd_cyc;
  logic  	    wbd_stb;
  logic [3:0] 	wbd_tid; // Target ID
} type_wb_wr_intf;

// Wishbone Read Interface
typedef struct packed { 
  logic	[31:0]	wbd_dat;
  logic  	    wbd_ack;
  logic  	    wbd_err;
} type_wb_rd_intf;

// Master Write Interfaces
type_wb_wr_intf  m0_wb_wr;
type_wb_wr_intf  m1_wb_wr;

// Master Read Interfaces
type_wb_rd_intf  m0_wb_rd;
type_wb_rd_intf  m1_wb_rd;

// Slave Write Interfaces
type_wb_wr_intf  s0_wb_wr;
type_wb_wr_intf  s1_wb_wr;

// Slave Read Interfaces
type_wb_rd_intf  s0_wb_rd;
type_wb_rd_intf  s1_wb_rd;

// Multiplexed Master and Slave Interfaces
type_wb_wr_intf  m_bus_wr;  // Multiplexed Master Interface
type_wb_rd_intf  m_bus_rd;  // Multiplexed Slave Interface

////////////////////////////////////////////////////////////////////
//
// Master 0 and Master 1 Address Decoding
//

// Slave 0 (UART) Address Range: 0xFF010000 to 0xFF010FFF (4 kB)
// Slave 1 (SRAM) Address Range: 0xFFFF0000 to 0xFFFFFFFF (64 kB)

// Address Decoding
always_comb begin
   if (m0_wbd_adr_i[31:16] == 16'hFF01)
       m0_wb_wr.wbd_tid = TARGET_UART; // Slave 0
   else if (m0_wbd_adr_i[31:16] == 16'hFFFF)
       m0_wb_wr.wbd_tid = TARGET_SRAM; // Slave 1
	//  if (m0_wbd_adr_i[31:16] == 16'hFFFF)
    //     m0_wb_wr.wbd_tid = TARGET_SRAM; // Slave 1
    else
        m0_wb_wr.wbd_tid = 4'b1111; // Invalid Target
end

always_comb begin
    if (m1_wbd_adr_i[31:16] == 16'hFF01)
        m1_wb_wr.wbd_tid = TARGET_UART; // Slave 0
    else if (m1_wbd_adr_i[31:16] == 16'hFFFF)
        m1_wb_wr.wbd_tid = TARGET_SRAM; // Slave 1
    else
        m1_wb_wr.wbd_tid = 4'b1111; // Invalid Target
end

// Master Mappings
assign m0_wb_wr.wbd_dat = m0_wbd_dat_i;
assign m0_wb_wr.wbd_adr = m0_wbd_adr_i;
assign m0_wb_wr.wbd_sel = m0_wbd_sel_i;
assign m0_wb_wr.wbd_we  = m0_wbd_we_i;
assign m0_wb_wr.wbd_cyc = m0_wbd_cyc_i;
assign m0_wb_wr.wbd_stb = m0_wbd_stb_i;

assign m1_wb_wr.wbd_dat = m1_wbd_dat_i;
assign m1_wb_wr.wbd_adr = m1_wbd_adr_i;
assign m1_wb_wr.wbd_sel = m1_wbd_sel_i;
assign m1_wb_wr.wbd_we  = m1_wbd_we_i;
assign m1_wb_wr.wbd_cyc = m1_wbd_cyc_i;
assign m1_wb_wr.wbd_stb = m1_wbd_stb_i;

assign m0_wbd_dat_o  = m0_wb_rd.wbd_dat;
assign m0_wbd_ack_o  = m0_wb_rd.wbd_ack;
assign m0_wbd_err_o  = m0_wb_rd.wbd_err;

assign m1_wbd_dat_o  = m1_wb_rd.wbd_dat;
assign m1_wbd_ack_o  = m1_wb_rd.wbd_ack;
assign m1_wbd_err_o  = m1_wb_rd.wbd_err;

// Slave Mappings
assign s0_wbd_dat_o = s0_wb_wr.wbd_dat;
assign s0_wbd_adr_o = s0_wb_wr.wbd_adr;
assign s0_wbd_sel_o = s0_wb_wr.wbd_sel;
assign s0_wbd_we_o  = s0_wb_wr.wbd_we;
assign s0_wbd_cyc_o = s0_wb_wr.wbd_cyc;
assign s0_wbd_stb_o = s0_wb_wr.wbd_stb;

assign s1_wbd_dat_o = s1_wb_wr.wbd_dat;
assign s1_wbd_adr_o = s1_wb_wr.wbd_adr;
assign s1_wbd_sel_o = s1_wb_wr.wbd_sel;
assign s1_wbd_we_o  = s1_wb_wr.wbd_we;
assign s1_wbd_cyc_o = s1_wb_wr.wbd_cyc;
assign s1_wbd_stb_o = s1_wb_wr.wbd_stb;

assign s0_wb_rd.wbd_dat = s0_wbd_dat_i;
assign s0_wb_rd.wbd_ack = s0_wbd_ack_i;
assign s0_wb_rd.wbd_err = 1'b0; // No error handling

assign s1_wb_rd.wbd_dat = s1_wbd_dat_i;
assign s1_wb_rd.wbd_ack = s1_wbd_ack_i;
assign s1_wb_rd.wbd_err = 1'b0; // No error handling

// Arbiter for Two Masters
logic gnt;

wb_arb_2m u_wb_arb (
    .clk(clk_i), 
    .rstn(rst_n),
    .req({m1_wbd_cyc_i & !m1_wbd_ack_o, m0_wbd_cyc_i & !m0_wbd_ack_o}),
    .gnt(gnt)
);

// Generate Multiplexed Master Interface based on grant
always_comb begin
     case(gnt)
        1'b0:	   m_bus_wr = m0_wb_wr;
        1'b1:	   m_bus_wr = m1_wb_wr;
        default:   m_bus_wr = m0_wb_wr;
     endcase			
end

// Generate Multiplexed Slave Interface based on target ID
always_comb begin
     case(m_bus_wr.wbd_tid)
        TARGET_UART:   m_bus_rd = s0_wb_rd;
        TARGET_SRAM:   m_bus_rd = s1_wb_rd;
        default:       m_bus_rd = '{wbd_dat:32'hDEADBEEF, wbd_ack:1'b1, wbd_err:1'b1}; // Invalid target response
     endcase			
end

// Connect Master => Slave
assign s0_wb_wr = (m_bus_wr.wbd_tid == TARGET_UART) ? m_bus_wr : '{default:'0};
assign s1_wb_wr = (m_bus_wr.wbd_tid == TARGET_SRAM) ? m_bus_wr : '{default:'0};

// Connect Slave to Master
always_comb begin
    case(gnt)
        1'b0:   m0_wb_rd = m_bus_rd;
        1'b1:   m1_wb_rd = m_bus_rd;
        default: begin
            m0_wb_rd = '{default:'0};
            m1_wb_rd = '{default:'0};
        end
    endcase
end

endmodule

////////////////////////////////////////////////////////////////////
// instantiation example for the wb_interconnect_2m2s
////////////////////////////////////////////////////////////////////

// // Master 0 Signals
//     logic [31:0] m0_wbd_dat_i;
//     logic [31:0] m0_wbd_adr_i;
//     logic [3:0]  m0_wbd_sel_i;
//     logic        m0_wbd_we_i;
//     logic        m0_wbd_cyc_i;
//     logic        m0_wbd_stb_i;
//     logic [31:0] m0_wbd_dat_o;
//     logic        m0_wbd_ack_o;
//     logic        m0_wbd_err_o;

//     // Master 1 Signals
//     logic [31:0] m1_wbd_dat_i;
//     logic [31:0] m1_wbd_adr_i;
//     logic [3:0]  m1_wbd_sel_i;
//     logic        m1_wbd_we_i;
//     logic        m1_wbd_cyc_i;
//     logic        m1_wbd_stb_i;
//     logic [31:0] m1_wbd_dat_o;
//     logic        m1_wbd_ack_o;
//     logic        m1_wbd_err_o;

//     // Slave 0 Signals (UART)
//     logic [31:0] s0_wbd_dat_i;
//     logic        s0_wbd_ack_i;
//     logic [31:0] s0_wbd_dat_o;
//     logic [31:0] s0_wbd_adr_o;
//     logic [3:0]  s0_wbd_sel_o;
//     logic        s0_wbd_we_o;
//     logic        s0_wbd_cyc_o;
//     logic        s0_wbd_stb_o;

//     // Slave 1 Signals (SRAM)
//     logic [31:0] s1_wbd_dat_i;
//     logic        s1_wbd_ack_i;
//     logic [31:0] s1_wbd_dat_o;
//     logic [31:0] s1_wbd_adr_o;
//     logic [3:0]  s1_wbd_sel_o;
//     logic        s1_wbd_we_o;
//     logic        s1_wbd_cyc_o;
//     logic        s1_wbd_stb_o;

//     // Instantiate the Wishbone Interconnect module
//  wb_interconnect_2m2s u_wb_interconnect_2m2s (
//         .clk_i(clk_i),
//         .rst_n(rst_n),
//         // Master 0 Interface
//         .m0_wbd_dat_i(m0_wbd_dat_i),
//         .m0_wbd_adr_i(m0_wbd_adr_i),
//         .m0_wbd_sel_i(m0_wbd_sel_i),
//         .m0_wbd_we_i(m0_wbd_we_i),
//         .m0_wbd_cyc_i(m0_wbd_cyc_i),
//         .m0_wbd_stb_i(m0_wbd_stb_i),
//         .m0_wbd_dat_o(m0_wbd_dat_o),
//         .m0_wbd_ack_o(m0_wbd_ack_o),
//         .m0_wbd_err_o(m0_wbd_err_o),
//         // Master 1 Interface
//         .m1_wbd_dat_i(m1_wbd_dat_i),
//         .m1_wbd_adr_i(m1_wbd_adr_i),
//         .m1_wbd_sel_i(m1_wbd_sel_i),
//         .m1_wbd_we_i(m1_wbd_we_i),
//         .m1_wbd_cyc_i(m1_wbd_cyc_i),
//         .m1_wbd_stb_i(m1_wbd_stb_i),
//         .m1_wbd_dat_o(m1_wbd_dat_o),
//         .m1_wbd_ack_o(m1_wbd_ack_o),
//         .m1_wbd_err_o(m1_wbd_err_o),
//         // Slave 0 Interface (UART)
//         .s0_wbd_dat_i(s0_wbd_dat_i),
//         .s0_wbd_ack_i(s0_wbd_ack_i),
//         .s0_wbd_dat_o(s0_wbd_dat_o),
//         .s0_wbd_adr_o(s0_wbd_adr_o),
//         .s0_wbd_sel_o(s0_wbd_sel_o),
//         .s0_wbd_we_o(s0_wbd_we_o),
//         .s0_wbd_cyc_o(s0_wbd_cyc_o),
//         .s0_wbd_stb_o(s0_wbd_stb_o),
//         // Slave 1 Interface (SRAM)
//         .s1_wbd_dat_i(s1_wbd_dat_i),
//         .s1_wbd_ack_i(s1_wbd_ack_i),
//         .s1_wbd_dat_o(s1_wbd_dat_o),
//         .s1_wbd_adr_o(s1_wbd_adr_o),
//         .s1_wbd_sel_o(s1_wbd_sel_o),
//         .s1_wbd_we_o(s1_wbd_we_o),
//         .s1_wbd_cyc_o(s1_wbd_cyc_o),
//         .s1_wbd_stb_o(s1_wbd_stb_o)
//     );