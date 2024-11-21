//==============================================================================
// Project      : Wishbone Interconnect Design
// File Name    : wb_interconnect_2m2s.sv
// Author       : Bambang T. Wibowo
// Date         : 2024-11-18
// Description  : 2 Master - 2 Slave Wishbone Interconnect with Arbitration
//==============================================================================
// Revision History
//------------------------------------------------------------------------------
// Version  | Author      | Date       | Changes
//----------|-------------|------------|----------------------------------------
// 1.0      | Bambang T.W.| 2024-11-18 | Initial creation
//==============================================================================

module wb_interconnect_2m2s (
    input logic            clk_i, 
    input logic            rst_n,

    // Master 0 Interface
    input  logic [31:0]    m0_wbd_dat_i,
    input  logic [31:0]    m0_wbd_adr_i,
    input  logic [3:0]     m0_wbd_sel_i,
    input  logic           m0_wbd_we_i,
    input  logic           m0_wbd_cyc_i,
    input  logic           m0_wbd_stb_i,
    output logic [31:0]    m0_wbd_dat_o,
    output logic           m0_wbd_ack_o,
    output logic           m0_wbd_err_o,
    
    // Master 1 Interface
    input  logic [31:0]    m1_wbd_dat_i,
    input  logic [31:0]    m1_wbd_adr_i,
    input  logic [3:0]     m1_wbd_sel_i,
    input  logic           m1_wbd_we_i,
    input  logic           m1_wbd_cyc_i,
    input  logic           m1_wbd_stb_i,
    output logic [31:0]    m1_wbd_dat_o,
    output logic           m1_wbd_ack_o,
    output logic           m1_wbd_err_o,
    
    // Slave 0 Interface
    input  logic [31:0]    s0_wbd_dat_i,
    input  logic           s0_wbd_ack_i,
    output logic [31:0]    s0_wbd_dat_o,
    output logic [31:0]    s0_wbd_adr_o,
    output logic [3:0]     s0_wbd_sel_o,
    output logic           s0_wbd_we_o,
    output logic           s0_wbd_cyc_o,
    output logic           s0_wbd_stb_o,
    
    // Slave 1 Interface
    input  logic [31:0]    s1_wbd_dat_i,
    input  logic           s1_wbd_ack_i,
    output logic [31:0]    s1_wbd_dat_o,
    output logic [31:0]    s1_wbd_adr_o,
    output logic [3:0]     s1_wbd_sel_o,
    output logic           s1_wbd_we_o,
    output logic           s1_wbd_cyc_o,
    output logic           s1_wbd_stb_o
);

////////////////////////////////////////////////////////////////////
//
// Type Definitions
//
parameter TARGET_SLAVE0  = 4'b0000;
parameter TARGET_SLAVE1  = 4'b0001;

// Wishbone Write Interface
typedef struct packed { 
    logic [31:0] wbd_dat;
    logic [31:0] wbd_adr;
    logic [3:0]  wbd_sel;
    logic        wbd_we;
    logic        wbd_cyc;
    logic        wbd_stb;
    logic [3:0]  wbd_tid; // Target ID
} type_wb_wr_intf;

// Wishbone Read Interface
typedef struct packed { 
    logic [31:0] wbd_dat;
    logic        wbd_ack;
    logic        wbd_err;
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

// Multiplexed Interfaces
type_wb_wr_intf  m_bus_wr;  // Multiplexed Master Interface
type_wb_rd_intf  m_bus_rd;  // Multiplexed Slave Interface
type_wb_wr_intf  s_bus_wr;  // Multiplexed Slave Write Interface
type_wb_rd_intf  s_bus_rd;  // Multiplexed Slave Read Interface

//-------------------------------------------------------------------
// Address Decoding
//-------------------------------------------------------------------

// Master 0 Target ID based on address
wire [3:0] m0_wbd_tid_i = (m0_wbd_adr_i[31:16] == 16'hFF02) ? TARGET_SLAVE0 :
                          (m0_wbd_adr_i[31:16] == 16'hFFFF) ? TARGET_SLAVE1 : 4'b0000;

// Master 1 Target ID based on address
wire [3:0] m1_wbd_tid_i = (m1_wbd_adr_i[31:16] == 16'hFF02) ? TARGET_SLAVE0 :
                          (m1_wbd_adr_i[31:16] == 16'hFFFF) ? TARGET_SLAVE1 : 4'b0000;

//----------------------------------------
// Master Mapping
//----------------------------------------

assign m0_wb_wr.wbd_dat = m0_wbd_dat_i;
// assign m0_wb_wr.wbd_adr = {m0_wbd_adr_i[31:2], 2'b00}; // Word-aligned
assign m0_wb_wr.wbd_adr = m0_wbd_adr_i; // Word-aligned
assign m0_wb_wr.wbd_sel = m0_wbd_sel_i;
assign m0_wb_wr.wbd_we  = m0_wbd_we_i;
assign m0_wb_wr.wbd_cyc = m0_wbd_cyc_i;
assign m0_wb_wr.wbd_stb = m0_wbd_stb_i;
assign m0_wb_wr.wbd_tid = m0_wbd_tid_i;

assign m1_wb_wr.wbd_dat = m1_wbd_dat_i;
// assign m1_wb_wr.wbd_adr = {m1_wbd_adr_i[31:2], 2'b00}; // Word-aligned
assign m1_wb_wr.wbd_adr = m1_wbd_adr_i; // Word-aligned
assign m1_wb_wr.wbd_sel = m1_wbd_sel_i;
assign m1_wb_wr.wbd_we  = m1_wbd_we_i;
assign m1_wb_wr.wbd_cyc = m1_wbd_cyc_i;
assign m1_wb_wr.wbd_stb = m1_wbd_stb_i;
assign m1_wb_wr.wbd_tid = m1_wbd_tid_i;

assign m0_wbd_dat_o  = m0_wb_rd.wbd_dat;
assign m0_wbd_ack_o  = m0_wb_rd.wbd_ack;
assign m0_wbd_err_o  = m0_wb_rd.wbd_err;

assign m1_wbd_dat_o  = m1_wb_rd.wbd_dat;
assign m1_wbd_ack_o  = m1_wb_rd.wbd_ack;
assign m1_wbd_err_o  = m1_wb_rd.wbd_err;

//----------------------------------------
// Slave Mapping
//----------------------------------------

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

assign s0_wb_rd.wbd_dat  = s0_wbd_dat_i;
assign s0_wb_rd.wbd_ack  = s0_wbd_ack_i;
assign s0_wb_rd.wbd_err  = 1'b0; // Unused error signal

assign s1_wb_rd.wbd_dat  = s1_wbd_dat_i;
assign s1_wb_rd.wbd_ack  = s1_wbd_ack_i;
assign s1_wb_rd.wbd_err  = 1'b0; // Unused error signal

//----------------------------------------
// Arbitration Logic
//----------------------------------------

logic [0:0]  gnt; // Only 2 masters, so 1-bit grant signal

wb_arb_2m u_wb_arb (
    .clk(clk_i), 
    .rstn(rst_n),
    .req({m1_wbd_stb_i & !m1_wbd_ack_o, m0_wbd_stb_i & !m0_wbd_ack_o}),
    .gnt(gnt)
);

// Generate Multiplexed Master Interface based on grant
always_comb begin
    case (gnt)
        1'b0:    m_bus_wr = m0_wb_wr;
        1'b1:    m_bus_wr = m1_wb_wr;
        default: m_bus_wr = m0_wb_wr;
    endcase			
end

// Generate Multiplexed Slave Interface based on target ID
wire [3:0] s_wbd_tid = s_bus_wr.wbd_tid; // Target ID from bus write interface
always_comb begin
    case (s_wbd_tid)
        4'h0:    s_bus_rd = s0_wb_rd;
        4'h1:    s_bus_rd = s1_wb_rd;
        default: s_bus_rd = s0_wb_rd;
    endcase			
end

// Connect Master to Slave based on Target ID
assign s0_wb_wr = (s_wbd_tid == TARGET_SLAVE0) ? s_bus_wr : 'h0;
assign s1_wb_wr = (s_wbd_tid == TARGET_SLAVE1) ? s_bus_wr : 'h0;

// Connect Slave to Master based on grant
assign m0_wb_rd = (gnt == 1'b0) ? m_bus_rd : 'h0;
assign m1_wb_rd = (gnt == 1'b1) ? m_bus_rd : 'h0;

// Staging Flip-Flops to Break Timing Paths
wb_Stagging_2m u_m_wb_stage (
    .clk_i        (clk_i), 
    .rst_n        (rst_n),
    // Master Inputs
    .m_wbd_dat_i  (m_bus_wr.wbd_dat),
    .m_wbd_adr_i  (m_bus_wr.wbd_adr),
    .m_wbd_sel_i  (m_bus_wr.wbd_sel),
    .m_wbd_we_i   (m_bus_wr.wbd_we),
    .m_wbd_cyc_i  (m_bus_wr.wbd_cyc),
    .m_wbd_stb_i  (m_bus_wr.wbd_stb),
    .m_wbd_tid_i  (m_bus_wr.wbd_tid),
    // Master Outputs
    .m_wbd_dat_o  (m_bus_rd.wbd_dat),
    .m_wbd_ack_o  (m_bus_rd.wbd_ack),
    .m_wbd_err_o  (m_bus_rd.wbd_err),
    // Slave Inputs
    .s_wbd_dat_i  (s_bus_rd.wbd_dat),
    .s_wbd_ack_i  (s_bus_rd.wbd_ack),
    .s_wbd_err_i  (s_bus_rd.wbd_err),
    // Slave Outputs
    .s_wbd_dat_o  (s_bus_wr.wbd_dat),
    .s_wbd_adr_o  (s_bus_wr.wbd_adr),
    .s_wbd_sel_o  (s_bus_wr.wbd_sel),
    .s_wbd_we_o   (s_bus_wr.wbd_we),
    .s_wbd_cyc_o  (s_bus_wr.wbd_cyc),
    .s_wbd_stb_o  (s_bus_wr.wbd_stb),
    .s_wbd_tid_o  (s_bus_wr.wbd_tid)
);

endmodule
