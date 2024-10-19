`timescale 1ns / 1ps

module wb_interconnect_passthrough(
    `ifdef USE_POWER_PINS
        input logic vccd1,    // User area 1 1.8V supply
        input logic vssd1,    // User area 1 digital ground
    `endif
    // System Clock and Reset
    input logic clk_i, 
    input logic rst_n,

    // Master 0 Interface
    input   logic [31:0] m0_wbd_dat_i,
    input   logic [31:0] m0_wbd_adr_i,
    input   logic [3:0]  m0_wbd_sel_i,
    input   logic         m0_wbd_we_i,
    input   logic         m0_wbd_cyc_i,
    input   logic         m0_wbd_stb_i,
    output  logic [31:0] m0_wbd_dat_o,
    output  logic        m0_wbd_ack_o,
    output  logic        m0_wbd_err_o,
    
    // Master 1 Interface
    input   logic [31:0] m1_wbd_dat_i,
    input   logic [31:0] m1_wbd_adr_i,
    input   logic [3:0]  m1_wbd_sel_i,
    input   logic         m1_wbd_we_i,
    input   logic         m1_wbd_cyc_i,
    input   logic         m1_wbd_stb_i,
    output  logic [31:0] m1_wbd_dat_o,
    output  logic        m1_wbd_ack_o,
    output  logic        m1_wbd_err_o,
    
    // Slave 0 Interface (SDRAM and SRAM)
    input   logic [31:0] s0_wbd_dat_i,
    input   logic        s0_wbd_ack_i,
    output  logic [31:0] s0_wbd_dat_o,
    output  logic [31:0] s0_wbd_adr_o,
    output  logic [3:0]  s0_wbd_sel_o,
    output  logic        s0_wbd_we_o,
    output  logic        s0_wbd_cyc_o,
    output  logic        s0_wbd_stb_o,
    
    // Slave 1 Interface (Other Peripherals)
    input   logic [31:0] s1_wbd_dat_i,
    input   logic        s1_wbd_ack_i,
    output  logic [31:0] s1_wbd_dat_o,
    output  logic [31:0] s1_wbd_adr_o,
    output  logic [3:0]  s1_wbd_sel_o,
    output  logic        s1_wbd_we_o,
    output  logic        s1_wbd_cyc_o,
    output  logic        s1_wbd_stb_o
);

//-------------------------------------------------------------------
// Type Definitions
//-------------------------------------------------------------------

parameter TARGET_SLAVE0 = 4'b0000;
parameter TARGET_SLAVE1 = 4'b0001;

// WishBone Write Interface
typedef struct packed { 
    logic [31:0] wbd_dat;
    logic [31:0] wbd_adr;
    logic [3:0]  wbd_sel;
    logic        wbd_we;
    logic        wbd_cyc;
    logic        wbd_stb;
    logic [3:0]  wbd_tid; // target id
} type_wb_wr_intf;

// WishBone Read Interface
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
type_wb_wr_intf  m_bus_wr;  // Multiplexed Master I/F
type_wb_rd_intf  m_bus_rd;  // Multiplexed Slave I/F

type_wb_wr_intf  s_bus_wr;  // Multiplexed Master I/F
type_wb_rd_intf  s_bus_rd;  // Multiplexed Slave I/F

//-------------------------------------------------------------------
// Address Decoding for Masters
//-------------------------------------------------------------------

// Master 0 targeting Slave0 (SDRAM and SRAM) or Slave1 (Peripherals) based on address
// wire [3:0] m0_wbd_tid_i = ((m0_wbd_adr_i >= 32'h00000000 && m0_wbd_adr_i <= 32'h03FFFFFF) ||
//                            (m0_wbd_adr_i >= 32'hFFFF0000 && m0_wbd_adr_i <= 32'hFFFFFFFF)) ? TARGET_SLAVE0 :
//                           TARGET_SLAVE1;

// // Master 1 targeting Slave0 (SDRAM and SRAM) or Slave1 (Peripherals) based on address
// wire [3:0] m1_wbd_tid_i = ((m1_wbd_adr_i >= 32'h00000000 && m1_wbd_adr_i <= 32'h03FFFFFF) ||
//                            (m1_wbd_adr_i >= 32'hFFFF0000 && m1_wbd_adr_i <= 32'hFFFFFFFF)) ? TARGET_SLAVE0 :
//                           TARGET_SLAVE1;

wire [3:0] m0_wbd_tid_i = TARGET_SLAVE0;

// Master 1 targeting Slave0 (SDRAM and SRAM) or Slave1 (Peripherals) based on address
wire [3:0] m1_wbd_tid_i = TARGET_SLAVE1;

//-------------------------------------------------------------------
// Master Mapping
//-------------------------------------------------------------------
assign m0_wb_wr.wbd_dat = m0_wbd_dat_i;
assign m0_wb_wr.wbd_adr = m0_wbd_adr_i;
assign m0_wb_wr.wbd_sel = m0_wbd_sel_i;
assign m0_wb_wr.wbd_we  = m0_wbd_we_i;
assign m0_wb_wr.wbd_cyc = m0_wbd_cyc_i;
assign m0_wb_wr.wbd_stb = m0_wbd_stb_i;
assign m0_wb_wr.wbd_tid = m0_wbd_tid_i;

assign m1_wb_wr.wbd_dat = m1_wbd_dat_i;
assign m1_wb_wr.wbd_adr = m1_wbd_adr_i;
assign m1_wb_wr.wbd_sel = m1_wbd_sel_i;
assign m1_wb_wr.wbd_we  = m1_wbd_we_i;
assign m1_wb_wr.wbd_cyc = m1_wbd_cyc_i;
assign m1_wb_wr.wbd_stb = m1_wbd_stb_i;
assign m1_wb_wr.wbd_tid = m1_wbd_tid_i;

// Read Interface Assignments
assign m0_wbd_dat_o = m0_wb_rd.wbd_dat;
assign m0_wbd_ack_o = m0_wb_rd.wbd_ack;
assign m0_wbd_err_o = m0_wb_rd.wbd_err;

assign m1_wbd_dat_o = m1_wb_rd.wbd_dat;
assign m1_wbd_ack_o = m1_wb_rd.wbd_ack;
assign m1_wbd_err_o = m1_wb_rd.wbd_err;

//-------------------------------------------------------------------
// Slave Mapping
//-------------------------------------------------------------------

// Connect Slave Write Interfaces
assign s0_wbd_dat_o = (s_bus_wr.wbd_tid == TARGET_SLAVE0) ? s_bus_wr.wbd_dat : 32'h0;
assign s0_wbd_adr_o = (s_bus_wr.wbd_tid == TARGET_SLAVE0) ? s_bus_wr.wbd_adr : 32'h0;
assign s0_wbd_sel_o = (s_bus_wr.wbd_tid == TARGET_SLAVE0) ? s_bus_wr.wbd_sel : 4'h0;
assign s0_wbd_we_o  = (s_bus_wr.wbd_tid == TARGET_SLAVE0) ? s_bus_wr.wbd_we  : 1'b0;
assign s0_wbd_cyc_o = (s_bus_wr.wbd_tid == TARGET_SLAVE0) ? s_bus_wr.wbd_cyc : 1'b0;
assign s0_wbd_stb_o = (s_bus_wr.wbd_tid == TARGET_SLAVE0) ? s_bus_wr.wbd_stb : 1'b0;

assign s1_wbd_dat_o = (s_bus_wr.wbd_tid == TARGET_SLAVE1) ? s_bus_wr.wbd_dat : 32'h0;
assign s1_wbd_adr_o = (s_bus_wr.wbd_tid == TARGET_SLAVE1) ? s_bus_wr.wbd_adr : 32'h0;
assign s1_wbd_sel_o = (s_bus_wr.wbd_tid == TARGET_SLAVE1) ? s_bus_wr.wbd_sel : 4'h0;
assign s1_wbd_we_o  = (s_bus_wr.wbd_tid == TARGET_SLAVE1) ? s_bus_wr.wbd_we  : 1'b0;
assign s1_wbd_cyc_o = (s_bus_wr.wbd_tid == TARGET_SLAVE1) ? s_bus_wr.wbd_cyc : 1'b0;
assign s1_wbd_stb_o = (s_bus_wr.wbd_tid == TARGET_SLAVE1) ? s_bus_wr.wbd_stb : 1'b0;

// Connect Slave Read Interfaces
assign s0_wb_rd.wbd_dat  = s0_wbd_dat_i;
assign s0_wb_rd.wbd_ack  = s0_wbd_ack_i;
assign s0_wb_rd.wbd_err  = 1'b0;

assign s1_wb_rd.wbd_dat  = s1_wbd_dat_i;
assign s1_wb_rd.wbd_ack  = s1_wbd_ack_i;
assign s1_wb_rd.wbd_err  = 1'b0;

//-------------------------------------------------------------------
// Arbiter Instantiation
//-------------------------------------------------------------------
logic [1:0] gnt;

wb_arb u_wb_arb (
    .clk(clk_i), 
    .rstn(rst_n),
    .req({ m1_wbd_stb_i & !m1_wbd_ack_o,
           m0_wbd_stb_i & !m0_wbd_ack_o }),
    .gnt(gnt)
);

//-------------------------------------------------------------------
// Generate Multiplexed Master Interface based on grant
//-------------------------------------------------------------------
always_comb begin
    case(gnt)
        2'b00:    m_bus_wr = m0_wb_wr;
        2'b01:    m_bus_wr = m1_wb_wr;
        default:  m_bus_wr = m0_wb_wr;
    endcase			
end

//-------------------------------------------------------------------
// Generate Multiplexed Slave Interface based on target Id
//-------------------------------------------------------------------
wire [3:0] s_wbd_tid = s_bus_wr.wbd_tid; 

always_comb begin
    case(s_wbd_tid)
        TARGET_SLAVE0: s_bus_rd = s0_wb_rd;
        TARGET_SLAVE1: s_bus_rd = s1_wb_rd;
        default:       s_bus_rd = s0_wb_rd;
    endcase			
end

//-------------------------------------------------------------------
// Connect Master => Slave
//-------------------------------------------------------------------
assign s0_wb_wr = (s_wbd_tid == TARGET_SLAVE0) ? s_bus_wr : 'h0;
assign s1_wb_wr = (s_wbd_tid == TARGET_SLAVE1) ? s_bus_wr : 'h0;

//-------------------------------------------------------------------
// Connect Slave to Master
//-------------------------------------------------------------------
assign m0_wb_rd = (gnt == 2'b00) ? m_bus_rd : 'h0;
assign m1_wb_rd = (gnt == 2'b01) ? m_bus_rd : 'h0;

//-------------------------------------------------------------------
// Staging Module Instantiation
//-------------------------------------------------------------------
wb_stagging u_wb_stage (
    .clk_i       (clk_i), 
    .rst_n       (rst_n),
    .m_wbd_dat_i (m_bus_wr.wbd_dat),
    .m_wbd_adr_i (m_bus_wr.wbd_adr),
    .m_wbd_sel_i (m_bus_wr.wbd_sel),
    .m_wbd_we_i  (m_bus_wr.wbd_we),
    .m_wbd_cyc_i (m_bus_wr.wbd_cyc),
    .m_wbd_stb_i (m_bus_wr.wbd_stb),
    .m_wbd_tid_i (m_bus_wr.wbd_tid),
    .m_wbd_dat_o (m_bus_rd.wbd_dat),
    .m_wbd_ack_o (m_bus_rd.wbd_ack),
    .m_wbd_err_o (m_bus_rd.wbd_err),
    .s_wbd_dat_i (s_bus_rd.wbd_dat),
    .s_wbd_ack_i (s_bus_rd.wbd_ack),
    .s_wbd_err_i (s_bus_rd.wbd_err),
    .s_wbd_dat_o (s_bus_wr.wbd_dat),
    .s_wbd_adr_o (s_bus_wr.wbd_adr),
    .s_wbd_sel_o (s_bus_wr.wbd_sel),
    .s_wbd_we_o  (s_bus_wr.wbd_we),
    .s_wbd_cyc_o (s_bus_wr.wbd_cyc),
    .s_wbd_stb_o (s_bus_wr.wbd_stb),
    .s_wbd_tid_o (s_bus_wr.wbd_tid)
);

endmodule
