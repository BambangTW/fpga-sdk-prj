module wb_interconnect3 (
    input logic            clk_i, 
    input logic            rst_n,

    // Master 0 Interface (I-MEM)
    input   logic  [31:0]  m0_wbd_dat_i,
    input   logic  [31:0]  m0_wbd_adr_i,
    input   logic  [3:0]   m0_wbd_sel_i,
    input   logic          m0_wbd_we_i,
    input   logic          m0_wbd_cyc_i,
    input   logic          m0_wbd_stb_i,
    output  logic  [31:0]  m0_wbd_dat_o,
    output  logic          m0_wbd_ack_o,
    output  logic          m0_wbd_err_o,

    // Master 1 Interface (D-MEM)
    input   logic  [31:0]  m1_wbd_dat_i,
    input   logic  [31:0]  m1_wbd_adr_i,
    input   logic  [3:0]   m1_wbd_sel_i,
    input   logic          m1_wbd_we_i,
    input   logic          m1_wbd_cyc_i,
    input   logic          m1_wbd_stb_i,
    output  logic  [31:0]  m1_wbd_dat_o,
    output  logic          m1_wbd_ack_o,
    output  logic          m1_wbd_err_o,

    // Slave 0 Interface (Bootloader RAM)
    input   logic  [31:0]  s0_wbd_dat_i,
    input   logic          s0_wbd_ack_i,
    output  logic  [31:0]  s0_wbd_dat_o,
    output  logic  [31:0]  s0_wbd_adr_o,
    output  logic  [3:0]   s0_wbd_sel_o,
    output  logic          s0_wbd_we_o,
    output  logic          s0_wbd_cyc_o,
    output  logic          s0_wbd_stb_o,

    // Slave 1 Interface (UART)
    input   logic  [31:0]  s1_wbd_dat_i,
    input   logic          s1_wbd_ack_i,
    output  logic  [31:0]  s1_wbd_dat_o,
    output  logic  [7:0]   s1_wbd_adr_o,  // UART needs only 8-bit address
    output  logic  [3:0]   s1_wbd_sel_o,
    output  logic          s1_wbd_we_o,
    output  logic          s1_wbd_cyc_o,
    output  logic          s1_wbd_stb_o
);

// Address map constants
parameter TARGET_BOOT_RAM = 4'b0000;
parameter TARGET_UART     = 4'b0001;

// Wishbone write interface
typedef struct packed { 
    logic  [31:0]  wbd_dat;
    logic  [31:0]  wbd_adr;
    logic  [3:0]   wbd_sel;
    logic          wbd_we;
    logic          wbd_cyc;
    logic          wbd_stb;
    logic  [3:0]   wbd_tid;
} type_wb_wr_intf;

// Wishbone read interface
typedef struct packed { 
    logic  [31:0]  wbd_dat;
    logic          wbd_ack;
    logic          wbd_err;
} type_wb_rd_intf;

// Master Write Interface
type_wb_wr_intf m0_wb_wr, m1_wb_wr;

// Master Read Interface
type_wb_rd_intf m0_wb_rd, m1_wb_rd;

// Slave Write Interface
type_wb_wr_intf s0_wb_wr, s1_wb_wr;

// Slave Read Interface
type_wb_rd_intf s0_wb_rd, s1_wb_rd;

type_wb_wr_intf  m_bus_wr;  // Multiplexed Master I/F
type_wb_rd_intf  m_bus_rd;  // Multiplexed Slave I/F

type_wb_wr_intf  s_bus_wr;  // Multiplexed Master I/F
type_wb_rd_intf  s_bus_rd;  // Multiplexed Slave I/F

// Address decoding for Master 0 (I-MEM -> Bootloader RAM only)
wire [3:0] m0_wbd_tid_i = (m0_wbd_adr_i[31:16] == 16'hFFFF) ? TARGET_BOOT_RAM : 4'b0000;

// Address decoding for Master 1 (D-MEM -> Bootloader RAM and UART)
wire [3:0] m1_wbd_tid_i = (m1_wbd_adr_i[31:16] == 16'hFFFF) ? TARGET_BOOT_RAM :
                          (m1_wbd_adr_i[31:16] == 16'hFF01) ? TARGET_UART : 4'b0000;

//----------------------------------------
// Master to slave mapping
//----------------------------------------
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
assign s1_wbd_adr_o = s1_wb_wr.wbd_adr[7:0]; // UART address is only 8 bits
assign s1_wbd_sel_o = s1_wb_wr.wbd_sel;
assign s1_wbd_we_o  = s1_wb_wr.wbd_we;
assign s1_wbd_cyc_o = s1_wb_wr.wbd_cyc;
assign s1_wbd_stb_o = s1_wb_wr.wbd_stb;

//----------------------------------------
// Master to Slave connections
//----------------------------------------
assign s0_wb_rd.wbd_dat = s0_wbd_dat_i;
assign s0_wb_rd.wbd_ack = s0_wbd_ack_i;
assign s0_wb_rd.wbd_err = 1'b0;

assign s1_wb_rd.wbd_dat = s1_wbd_dat_i;
assign s1_wb_rd.wbd_ack = s1_wbd_ack_i;
assign s1_wb_rd.wbd_err = 1'b0;

// Arbiter instantiation
logic [1:0] gnt;

// Arbiter only between m1_wb_wr to select between two slaves
wb_arb2 u_wb_arb (
    .clk(clk_i), 
    .rstn(rst_n),
    .req({(m1_wbd_tid_i == TARGET_UART) & m1_wbd_stb_i & !m1_wbd_ack_o, 
          (m1_wbd_tid_i == TARGET_BOOT_RAM) & m1_wbd_stb_i & !m1_wbd_ack_o}),
    .gnt(gnt)
);

// Generate multiplexed slave interface based on grant for Master 1 (D-MEM)
always_comb begin
    case(gnt)
        2'h0: s_bus_rd = s0_wb_rd; // Bootloader RAM
        2'h1: s_bus_rd = s1_wb_rd; // UART
        default: s_bus_rd = s0_wb_rd;
    endcase
end

// Stagging FF to break write and read timing path
wb_stagging u_m_wb_stage (
    .clk_i(clk_i), 
    .rst_n(rst_n),
    // WishBone Input master I/P
    .m_wbd_dat_i(m_bus_wr.wbd_dat),
    .m_wbd_adr_i(m_bus_wr.wbd_adr),
    .m_wbd_sel_i(m_bus_wr.wbd_sel),
    .m_wbd_we_i(m_bus_wr.wbd_we),
    .m_wbd_cyc_i(m_bus_wr.wbd_cyc),
    .m_wbd_stb_i(m_bus_wr.wbd_stb),
    .m_wbd_tid_i(m_bus_wr.wbd_tid),
    .m_wbd_dat_o(m_bus_rd.wbd_dat),
    .m_wbd_ack_o(m_bus_rd.wbd_ack),
    .m_wbd_err_o(m_bus_rd.wbd_err),

    // Slave Interface
    .s_wbd_dat_i(s_bus_rd.wbd_dat),
    .s_wbd_ack_i(s_bus_rd.wbd_ack),
    .s_wbd_err_i(s_bus_rd.wbd_err),
    .s_wbd_dat_o(s_bus_wr.wbd_dat),
    .s_wbd_adr_o(s_bus_wr.wbd_adr),
    .s_wbd_sel_o(s_bus_wr.wbd_sel),
    .s_wbd_we_o(s_bus_wr.wbd_we),
    .s_wbd_cyc_o(s_bus_wr.wbd_cyc),
    .s_wbd_stb_o(s_bus_wr.wbd_stb),
    .s_wbd_tid_o(s_bus_wr.wbd_tid)
);

endmodule