`include "scr1_arch_types.svh"
`include "scr1_arch_description.svh"
`include "scr1_memif.svh"
`include "scr1_ipic.svh"

// User-defined board-specific parameters accessible as memory-mapped GPIO
parameter bit [31:0] FPGA_DE10_SOC_ID           = `SCR1_PTFM_SOC_ID;
parameter bit [31:0] FPGA_DE10_BLD_ID           = `SCR1_PTFM_BLD_ID;
parameter bit [31:0] FPGA_DE10_CORE_CLK_FREQ    = `SCR1_PTFM_CORE_CLK_FREQ;

module de10lite_scr1 (
    // === CLOCK ===========================================
    input  logic                    MAX10_CLK2_50,
    // === RESET ===========================================
    input  logic          [1:0]     KEY,
    // === SDRAM ===========================================
    output logic                    DRAM_CLK,
    output logic                    DRAM_CKE,
    output logic                    DRAM_CS_N,
    output logic                    DRAM_WE_N,
    output logic                    DRAM_RAS_N,
    output logic                    DRAM_CAS_N,
    output logic          [1:0]     DRAM_BA,    
    output logic         [12:0]     DRAM_ADDR,
    output logic                    DRAM_LDQM,
    output logic                    DRAM_UDQM,
    inout  logic         [15:0]     DRAM_DQ,
    // === LEDs ============================================
    output logic          [9:0]     LEDR,
    output logic          [7:0]     HEX0,
    output logic          [7:0]     HEX1,
    output logic          [7:0]     HEX2,
    output logic          [7:0]     HEX3,
    output logic          [7:0]     HEX4,
    output logic          [7:0]     HEX5,
    // === Switches ========================================
    input  logic          [9:0]     SW,
    // === UART ============================================
    output logic                    UART_TXD,
    input  logic                    UART_RXD
);

//=======================================================
// Signals / Variables declarations
//=======================================================
logic                               pwrup_rst_n;
logic                               cpu_clk;
logic                               extn_rst_in_n;
logic                               extn_rst_n;
logic [1:0]                         extn_rst_n_sync;
logic                               hard_rst_n;
logic [3:0]                         hard_rst_n_count;
logic                               soc_rst_n;
logic                               cpu_rst_n;

logic [3:0]                         ahb_imem_hprot;
logic [2:0]                         ahb_imem_hburst;
logic [2:0]                         ahb_imem_hsize;
logic [1:0]                         ahb_imem_htrans;
logic [31:0]                        ahb_imem_haddr;
logic                               ahb_imem_hready;
logic [31:0]                        ahb_imem_hrdata;
logic                               ahb_imem_hresp;

logic [3:0]                         ahb_dmem_hprot;
logic [2:0]                         ahb_dmem_hburst;
logic [2:0]                         ahb_dmem_hsize;
logic [1:0]                         ahb_dmem_htrans;
logic [31:0]                        ahb_dmem_haddr;
logic                               ahb_dmem_hwrite;
logic [31:0]                        ahb_dmem_hwdata;
logic                               ahb_dmem_hready;
logic [31:0]                        ahb_dmem_hrdata;
logic                               ahb_dmem_hresp;

// Wishbone Signals for Instruction and Data Memory
logic [31:0]                        wb_imem_adr_o;
logic                               wb_imem_we_o;
logic                               wb_imem_cyc_o;
logic                               wb_imem_stb_o;
logic [3:0]                         wb_imem_byteenable;
logic [31:0]                        wb_imem_dat_o;
logic                               wb_imem_ack_i;
logic [31:0]                        wb_imem_dat_i;

logic [31:0]                        wb_dmem_adr_o;
logic                               wb_dmem_we_o;
logic                               wb_dmem_cyc_o;
logic                               wb_dmem_stb_o;
logic [3:0]                         wb_dmem_byteenable;
logic [31:0]                        wb_dmem_dat_o;
logic                               wb_dmem_ack_i;
logic [31:0]                        wb_dmem_dat_i;

//=======================================================
// Resets
//=======================================================
assign extn_rst_in_n = KEY[0];

always_ff @(posedge cpu_clk, negedge pwrup_rst_n) begin
    if (~pwrup_rst_n) begin
        extn_rst_n_sync <= '0;
    end else begin
        extn_rst_n_sync[0] <= extn_rst_in_n;
        extn_rst_n_sync[1] <= extn_rst_n_sync[0];
    end
end
assign extn_rst_n = extn_rst_n_sync[1];

always_ff @(posedge cpu_clk, negedge pwrup_rst_n) begin
    if (~pwrup_rst_n) begin
        hard_rst_n          <= 1'b0;
        hard_rst_n_count    <= '0;
    end else begin
        if (hard_rst_n) begin
            hard_rst_n          <= extn_rst_n;
            hard_rst_n_count    <= '0;
        end else begin
            if (extn_rst_n) begin
                if (hard_rst_n_count == '1) begin
                    hard_rst_n <= 1'b1;
                end else begin
                    hard_rst_n_count <= hard_rst_n_count + 1'b1;
                end
            end else begin
                hard_rst_n_count <= '0;
            end
        end
    end
end

assign soc_rst_n = hard_rst_n;

//=======================================================
// SCR1 Core's Processor Cluster
//=======================================================
scr1_top_ahb i_scr1 (
    // Common
    .pwrup_rst_n (pwrup_rst_n),
    .rst_n       (hard_rst_n),
    .cpu_rst_n   (cpu_rst_n),
    .clk         (cpu_clk),
    // Instruction Memory Interface
    .imem_hprot  (ahb_imem_hprot),
    .imem_hburst (ahb_imem_hburst),
    .imem_hsize  (ahb_imem_hsize),
    .imem_htrans (ahb_imem_htrans),
    .imem_haddr  (ahb_imem_haddr),
    .imem_hready (ahb_imem_hready),
    .imem_hrdata (ahb_imem_hrdata),
    .imem_hresp  (ahb_imem_hresp),
    // Data Memory Interface
    .dmem_hprot  (ahb_dmem_hprot),
    .dmem_hburst (ahb_dmem_hburst),
    .dmem_hsize  (ahb_dmem_hsize),
    .dmem_htrans (ahb_dmem_htrans),
    .dmem_haddr  (ahb_dmem_haddr),
    .dmem_hwrite (ahb_dmem_hwrite),
    .dmem_hwdata (ahb_dmem_hwdata),
    .dmem_hready (ahb_dmem_hready),
    .dmem_hrdata (ahb_dmem_hrdata),
    .dmem_hresp  (ahb_dmem_hresp)
);

//==========================================================
// AHB-Wishbone Bridge for Instruction Memory
//==========================================================
ahb_wishbone_bridge i_ahb_imem (
    .clk           (cpu_clk),
    .reset_n       (soc_rst_n),
    .adr_o         (wb_imem_adr_o),
    .we_o          (wb_imem_we_o),
    .cyc_o         (wb_imem_cyc_o),
    .stb_o         (wb_imem_stb_o),
    .byteenable    (wb_imem_byteenable),
    .dat_o         (wb_imem_dat_o),
    .ack_i         (wb_imem_ack_i),
    .dat_i         (wb_imem_dat_i),
    .HRDATA        (ahb_imem_hrdata),
    .HRESP         (ahb_imem_hresp),
    .HSIZE         (ahb_imem_hsize),
    .HTRANS        (ahb_imem_htrans),
    .HADDR         (ahb_imem_haddr),
    .HWDATA        ('0),
    .HWRITE        ('0),
    .HREADY        (ahb_imem_hready)
);

//==========================================================
// AHB-Wishbone Bridge for Data Memory
//==========================================================
ahb_wishbone_bridge i_ahb_dmem (
    .clk           (cpu_clk),
    .reset_n       (soc_rst_n),
    .adr_o         (wb_dmem_adr_o),
    .we_o          (wb_dmem_we_o),
    .cyc_o         (wb_dmem_cyc_o),
    .stb_o         (wb_dmem_stb_o),
    .byteenable    (wb_dmem_byteenable),
    .dat_o         (wb_dmem_dat_o),
    .ack_i         (wb_dmem_ack_i),
    .dat_i         (wb_dmem_dat_i),
    .HRDATA        (ahb_dmem_hrdata),
    .HRESP         (ahb_dmem_hresp),
    .HSIZE         (ahb_dmem_hsize),
    .HTRANS        (ahb_dmem_htrans),
    .HADDR         (ahb_dmem_haddr),
    .HWDATA        (ahb_dmem_hwdata),
    .HWRITE        (ahb_dmem_hwrite),
    .HREADY        (ahb_dmem_hready)
);

//==========================================================
// SDRAM and UART
//==========================================================
de10lite_sopc i_soc (
    .osc_50_clk            (MAX10_CLK2_50),
    .cpu_clk_out_clk       (cpu_clk),
    .sdram_clk_out_clk     (DRAM_CLK),
    .pll_reset             (1'b0),
    .pwrup_rst_n_out_export(pwrup_rst_n),
    .soc_reset_n           (soc_rst_n),
    .cpu_rst_out_reset_n   (cpu_rst_n),
    .sdram_addr            (DRAM_ADDR),
    .sdram_ba              (DRAM_BA),
    .sdram_cas_n           (DRAM_CAS_N),
    .sdram_cke             (DRAM_CKE),
    .sdram_cs_n            (DRAM_CS_N),
    .sdram_dq              (DRAM_DQ),
    .sdram_dqm             ({DRAM_UDQM, DRAM_LDQM}),
    .sdram_ras_n           (DRAM_RAS_N),
    .sdram_we_n            (DRAM_WE_N),
    .avl_imem_write        (wb_imem_we_o),
    .avl_imem_read         (wb_imem_stb_o),
    .avl_imem_waitrequest  (wb_imem_ack_i),
    .avl_imem_address      (wb_imem_adr_o),
    .avl_imem_writedata    (wb_imem_dat_o),
    .avl_imem_readdata     (wb_imem_dat_i),
    .avl_dmem_write        (wb_dmem_we_o),
    .avl_dmem_read         (wb_dmem_stb_o),
    .avl_dmem_waitrequest  (wb_dmem_ack_i),
    .avl_dmem_address      (wb_dmem_adr_o),
    .avl_dmem_writedata    (wb_dmem_dat_o),
    .avl_dmem_readdata     (wb_dmem_dat_i),
    .uart_tx               (UART_TXD),
    .uart_rx               (UART_RXD),
    .soc_id_export         (FPGA_DE10_SOC_ID),
    .bld_id_export         (FPGA_DE10_BLD_ID),
    .core_clk_freq_export  (FPGA_DE10_CORE_CLK_FREQ)
);

//==========================================================
// LEDs and Switches
//==========================================================
assign LEDR[7:0]  = pio_led;
assign LEDR[8]    = ~hard_rst_n;
assign LEDR[9]    = heartbeat;
assign {HEX1,HEX0} = pio_hex_1_0;
assign {HEX3,HEX2} = pio_hex_3_2;
assign {HEX5,HEX4} = pio_hex_5_4;
assign pio_sw      = SW;

endmodule : de10lite_scr1