/// Copyright by Syntacore LLC © 2016, 2017, 2021. See LICENSE for details
/// @file       <de10lite_scr1.sv>
/// @brief      Top-level entity with SCR1 for DE10-lite board
///

`include "scr1_arch_types.svh"
`include "scr1_arch_description.svh"
`include "scr1_memif.svh"
`include "scr1_ipic.svh"

//User-defined board-specific parameters accessible as memory-mapped GPIO
parameter bit [31:0] FPGA_DE10_SOC_ID           = `SCR1_PTFM_SOC_ID;
parameter bit [31:0] FPGA_DE10_BLD_ID           = `SCR1_PTFM_BLD_ID;
parameter bit [31:0] FPGA_DE10_CORE_CLK_FREQ    = `SCR1_PTFM_CORE_CLK_FREQ;

module de10lite_scr1 (
    // === CLOCK ===========================================
    input  logic                    MAX10_CLK2_50,
    // === RESET ===========================================
    //  KEY[0] is used as manual reset for SCR1 (see below).
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
    output logic          [6:0]     HEX2,
    output logic          [6:0]     HEX3,
    output logic          [6:0]     HEX4,
    output logic          [6:0]     HEX5,
    // === Buttons =========================================
    input  logic          [1:0]     KEY,
    // === Switches ========================================
    input  logic          [9:0]     SW,
    // === JTAG ============================================
    `ifdef SCR1_DBG_EN
    input  logic                    JTAG_SRST_N,
    input  logic                    JTAG_TRST_N,
    input  logic                    JTAG_TCK,
    input  logic                    JTAG_TMS,
    input  logic                    JTAG_TDI,
    output logic                    JTAG_TDO,
    `endif//SCR1_DBG_EN
    // === UART ============================================
    output logic                    UART_TXD,    // <- UART
    input  logic                    UART_RXD     // -> UART
);




//=======================================================
//  Signals / Variables declarations
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
`ifdef SCR1_DBG_EN
logic                               sys_rst_n;
`endif // SCR1_DBG_EN

// --- SCR1 ---------------------------------------------
logic [3:0]                         ahb_imem_hprot;
logic [2:0]                         ahb_imem_hburst;
logic [2:0]                         ahb_imem_hsize;
logic [1:0]                         ahb_imem_htrans;
logic [SCR1_AHB_WIDTH-1:0]          ahb_imem_haddr;
logic                               ahb_imem_hready;
logic [SCR1_AHB_WIDTH-1:0]          ahb_imem_hrdata;
logic                               ahb_imem_hresp;
//
logic [3:0]                         ahb_dmem_hprot;
logic [2:0]                         ahb_dmem_hburst;
logic [2:0]                         ahb_dmem_hsize;
logic [1:0]                         ahb_dmem_htrans;
logic [SCR1_AHB_WIDTH-1:0]          ahb_dmem_haddr;
logic                               ahb_dmem_hwrite;
logic [SCR1_AHB_WIDTH-1:0]          ahb_dmem_hwdata;
logic                               ahb_dmem_hready;
logic [SCR1_AHB_WIDTH-1:0]          ahb_dmem_hrdata;
logic                               ahb_dmem_hresp;
`ifdef SCR1_IPIC_EN
logic [31:0]                        scr1_irq;
`else
logic                               scr1_irq;
`endif // SCR1_IPIC_EN

// --- JTAG ---------------------------------------------
`ifdef SCR1_DBG_EN
logic                               scr1_jtag_trst_n;
logic                               scr1_jtag_tck;
logic                               scr1_jtag_tms;
logic                               scr1_jtag_tdi;
logic                               scr1_jtag_tdo_en;
logic                               scr1_jtag_tdo_int;
`endif // SCR1_DBG_EN

// --- AHB-Avalon Bridge --------------------------------
logic                               avl_imem_write;
logic                               avl_imem_read;
logic                               avl_imem_waitrequest;
logic [SCR1_AHB_WIDTH-1:0]          avl_imem_address;
logic [3:0]                         avl_imem_byteenable;
logic [SCR1_AHB_WIDTH-1:0]          avl_imem_writedata;
logic                               avl_imem_readdatavalid;
logic [SCR1_AHB_WIDTH-1:0]          avl_imem_readdata;
logic [1:0]                         avl_imem_response;
//
logic                               avl_dmem_write;
logic                               avl_dmem_read;
logic                               avl_dmem_waitrequest;
logic [SCR1_AHB_WIDTH-1:0]          avl_dmem_address;
logic [3:0]                         avl_dmem_byteenable;
logic [SCR1_AHB_WIDTH-1:0]          avl_dmem_writedata;
logic                               avl_dmem_readdatavalid;
logic [SCR1_AHB_WIDTH-1:0]          avl_dmem_readdata;
logic [1:0]                         avl_dmem_response;

// --- UART ---------------------------------------------
//logic                             uart_rxd;   // -> UART
//logic                             uart_txd;   // <- UART
logic                               uart_rts_n; // <- UART
logic                               uart_dtr_n; // <- UART
logic                               uart_irq;

logic [31:0]                        uart_readdata;
logic                               uart_readdatavalid;
logic [31:0]                        uart_writedata;
logic  [4:0]                        uart_address;
logic                               uart_write;
logic                               uart_read;
logic                               uart_waitrequest;

logic                               uart_wb_ack;
logic  [7:0]                        uart_wb_dat;
logic                               uart_read_vd;

// --- PIO ----------------------------------------------
logic [ 7:0]                        pio_led;
logic [15:0]                        pio_hex_1_0;
logic [15:0]                        pio_hex_3_2;
logic [15:0]                        pio_hex_5_4;
logic [ 9:0]                        pio_sw;

// --- Heartbeat ----------------------------------------
logic [31:0]                        rtc_counter;
logic                               tick_2Hz;
logic                               heartbeat;

//=======================================================
//  Resets
//=======================================================
assign extn_rst_in_n    = KEY[0]
`ifdef SCR1_DBG_EN
                        & JTAG_SRST_N
`endif // SCR1_DBG_EN
;

always_ff @(posedge cpu_clk, negedge pwrup_rst_n)
begin
    if (~pwrup_rst_n) begin
        extn_rst_n_sync     <= '0;
    end else begin
        extn_rst_n_sync[0]  <= extn_rst_in_n;
        extn_rst_n_sync[1]  <= extn_rst_n_sync[0];
    end
end
assign extn_rst_n = extn_rst_n_sync[1];

always_ff @(posedge cpu_clk, negedge pwrup_rst_n)
begin
    if (~pwrup_rst_n) begin
        hard_rst_n          <= 1'b0;
        hard_rst_n_count    <= '0;
    end else begin
        if (hard_rst_n) begin
            // hard_rst_n == 1 - de-asserted
            hard_rst_n          <= extn_rst_n;
            hard_rst_n_count    <= '0;
        end else begin
            // hard_rst_n == 0 - asserted
            if (extn_rst_n) begin
                if (hard_rst_n_count == '1) begin
                    // If extn_rst_n = 1 at least 16 clocks,
                    // de-assert hard_rst_n
                    hard_rst_n          <= 1'b1;
                end else begin
                    hard_rst_n_count    <= hard_rst_n_count + 1'b1;
                end
            end else begin
                // If extn_rst_n is asserted within 16-cycles window -> start
                // counting from the beginning
                hard_rst_n_count    <= '0;
            end
        end
    end
end

`ifdef SCR1_DBG_EN
assign soc_rst_n = sys_rst_n;
`else
assign soc_rst_n = hard_rst_n;
`endif // SCR1_DBG_EN

//=======================================================
//  Heartbeat
//=======================================================
always_ff @(posedge cpu_clk, negedge hard_rst_n)
begin
    if (~hard_rst_n) begin
        rtc_counter     <= '0;
        tick_2Hz        <= 1'b0;
    end
    else begin
        if (rtc_counter == '0) begin
            rtc_counter <= (FPGA_DE10_CORE_CLK_FREQ/2);
            tick_2Hz    <= 1'b1;
        end
        else begin
            rtc_counter <= rtc_counter - 1'b1;
            tick_2Hz    <= 1'b0;
        end
    end
end

always_ff @(posedge cpu_clk, negedge hard_rst_n)
begin
    if (~hard_rst_n) begin
        heartbeat       <= 1'b0;
    end
    else begin
        if (tick_2Hz) begin
            heartbeat   <= ~heartbeat;
        end
    end
end

//=======================================================
//  SCR1 Core's Processor Cluster
//=======================================================

scr1_top_wb u_scr1_top_wb (
        // Common
        .pwrup_rst_n                (pwrup_rst_n            ),
        .rst_n                      (hard_rst_n             ),
        .cpu_rst_n                  (cpu_rst_n              ),
        .test_mode                  (1'b0                   ),
        .test_rst_n                 (1'b1                   ),
        .clk                        (cpu_clk                ),
        .rtc_clk                    (1'b0                   ),
`ifdef SCR1_DBG_EN
        .sys_rst_n_o                (sys_rst_n              ),
        .sys_rdc_qlfy_o             (                       ),
`endif // SCR1_DBG_EN

        // Fuses
        .fuse_mhartid               ('0                     ),
`ifdef SCR1_DBG_EN
        .fuse_idcode                (`SCR1_TAP_IDCODE       ),
`endif // SCR1_DBG_EN

        // IRQ
`ifdef SCR1_IPIC_EN
        .irq_lines                  (scr1_irq               ),
`else
        .ext_irq                    (scr1_irq             ),
`endif//SCR1_IPIC_EN
        .soft_irq                   ('0                     ),

`ifdef SCR1_DBG_EN
        // Debug Interface - JTAG I/F
        .trst_n                     (scr1_jtag_trst_n       ),
        .tck                        (scr1_jtag_tck          ),
        .tms                        (scr1_jtag_tms          ),
        .tdi                        (scr1_jtag_tdi          ),
        .tdo                        (scr1_jtag_tdo_int      ),
        .tdo_en                     (scr1_jtag_tdo_en       ),
`endif//SCR1_DBG_EN

    // Instruction Memory Interface
    .wbd_imem_stb_o      (wb_imem_stb_i),        // strobe/request
    .wbd_imem_adr_o      (wb_imem_adr_i),        // address
    .wbd_imem_we_o       (wb_imem_we_i),        // write
    .wbd_imem_dat_o      (wb_imem_dat_i),        // data output
    .wbd_imem_sel_o      (wb_imem_sel_i),        // byte enable
    .wbd_imem_dat_i      (wb_imem_dat_o),        // data input
    .wbd_imem_ack_i      (wb_imem_ack_o),        // acknowledgment
    .wbd_imem_err_i      (wb_imem_err_o),        // error

    // Data Memory Interface
    .wbd_dmem_stb_o      (wb_dmem_stb_i),        // strobe/request
    .wbd_dmem_adr_o      (wb_dmem_adr_i),        // address
    .wbd_dmem_we_o       (wb_dmem_we_i),        // write
    .wbd_dmem_dat_o      (wb_dmem_dat_i),        // data output
    .wbd_dmem_sel_o      (wb_dmem_sel_i),        // byte enable
    .wbd_dmem_dat_i      (wb_dmem_dat_o),        // data input
    .wbd_dmem_ack_i      (wb_dmem_ack_o),        // acknowledgment
    .wbd_dmem_err_i      (wb_dmem_err_o)         // error
);

// scr1_top_ahb
// i_scr1 (
//         // Common
//         .pwrup_rst_n                (pwrup_rst_n            ),
//         .rst_n                      (hard_rst_n             ),
//         .cpu_rst_n                  (cpu_rst_n              ),
//         .test_mode                  (1'b0                   ),
//         .test_rst_n                 (1'b1                   ),
//         .clk                        (cpu_clk                ),
//         .rtc_clk                    (1'b0                   ),
// `ifdef SCR1_DBG_EN
//         .sys_rst_n_o                (sys_rst_n              ),
//         .sys_rdc_qlfy_o             (                       ),
// `endif // SCR1_DBG_EN

//         // Fuses
//         .fuse_mhartid               ('0                     ),
// `ifdef SCR1_DBG_EN
//         .fuse_idcode                (`SCR1_TAP_IDCODE       ),
// `endif // SCR1_DBG_EN

//         // IRQ
// `ifdef SCR1_IPIC_EN
//         .irq_lines                  (scr1_irq               ),
// `else
//         .ext_irq                    (scr1_irq             ),
// `endif//SCR1_IPIC_EN
//         .soft_irq                   ('0                     ),

// `ifdef SCR1_DBG_EN
//         // Debug Interface - JTAG I/F
//         .trst_n                     (scr1_jtag_trst_n       ),
//         .tck                        (scr1_jtag_tck          ),
//         .tms                        (scr1_jtag_tms          ),
//         .tdi                        (scr1_jtag_tdi          ),
//         .tdo                        (scr1_jtag_tdo_int      ),
//         .tdo_en                     (scr1_jtag_tdo_en       ),
// `endif//SCR1_DBG_EN

//         // Instruction Memory Interface
//         .imem_hprot                 (ahb_imem_hprot         ),
//         .imem_hburst                (ahb_imem_hburst        ),
//         .imem_hsize                 (ahb_imem_hsize         ),
//         .imem_htrans                (ahb_imem_htrans        ),
//         .imem_hmastlock             (                       ),
//         .imem_haddr                 (ahb_imem_haddr         ),
//         .imem_hready                (ahb_imem_hready        ),
//         .imem_hrdata                (ahb_imem_hrdata        ),
//         .imem_hresp                 (ahb_imem_hresp         ),
//         // Data Memory Interface
//         .dmem_hprot                 (ahb_dmem_hprot         ),
//         .dmem_hburst                (ahb_dmem_hburst        ),
//         .dmem_hsize                 (ahb_dmem_hsize         ),
//         .dmem_htrans                (ahb_dmem_htrans        ),
//         .dmem_hmastlock             (                       ),
//         .dmem_haddr                 (ahb_dmem_haddr         ),
//         .dmem_hwrite                (ahb_dmem_hwrite        ),
//         .dmem_hwdata                (ahb_dmem_hwdata        ),
//         .dmem_hready                (ahb_dmem_hready        ),
//         .dmem_hrdata                (ahb_dmem_hrdata        ),
//         .dmem_hresp                 (ahb_dmem_hresp         )
// );

`ifdef SCR1_IPIC_EN
assign scr1_irq = {31'd0, uart_irq};
`else
assign scr1_irq = uart_irq;
`endif // SCR1_IPIC_EN

//==========================================================
// UART 16550 IP
//==========================================================
always_ff @(posedge cpu_clk, negedge soc_rst_n)
if (~soc_rst_n)             uart_read_vd <= '0;
    else if (uart_wb_ack)   uart_read_vd <= '0;
    else if (uart_read)     uart_read_vd <= '1;

always_ff @(posedge cpu_clk) begin
    uart_readdatavalid  <= uart_wb_ack & uart_read_vd;
    uart_readdata       <= {24'd0,uart_wb_dat};
end

assign uart_waitrequest = ~uart_wb_ack;

// Slave 0 Signals (UART)
logic [31:0] uart_wbd_dat_i;
logic        uart_wbd_ack_i;
logic [31:0] uart_wbd_dat_o;
logic [31:0] uart_wbd_adr_o;
logic [3:0]  uart_wbd_sel_o;
logic        uart_wbd_we_o;
logic        uart_wbd_cyc_o;
logic        uart_wbd_stb_o;

uart_top
i_uart(
    .wb_clk_i       (cpu_clk                ),
    // Wishbone signals
    .wb_rst_i       (~soc_rst_n             ),
    .wb_adr_i       (uart_wbd_adr_o[4:2]         ),
    .wb_dat_i       (uart_wbd_dat_o[7:0]         ),
    .wb_dat_o       (uart_wbd_dat_i         ),
    .wb_we_i        (uart_wbd_we_o          ),
    .wb_stb_i       (uart_wbd_stb_o         ),
    .wb_cyc_i       (uart_wbd_cyc_o         ),
    .wb_ack_o       (uart_wbd_ack_i         ),
    .wb_sel_i       (4'd1                   ),
    .int_o          (uart_irq               ),

    .stx_pad_o      (UART_TXD               ),
    .srx_pad_i      (UART_RXD               ),

    .rts_pad_o      (uart_rts_n             ),
    .cts_pad_i      (uart_rts_n             ),
    .dtr_pad_o      (uart_dtr_n             ),
    .dsr_pad_i      (uart_dtr_n             ),
    .ri_pad_i       ('1                     ),
    .dcd_pad_i      ('1                     )
);

// Wishbone interface signals for IMEM
logic [31:0] wb_imem_dat_i, wb_imem_adr_i;
logic [3:0]  wb_imem_sel_i;
logic        wb_imem_we_i, wb_imem_cyc_i, wb_imem_stb_i;
logic [31:0] wb_imem_dat_o;
logic        wb_imem_ack_o, wb_imem_err_o;

// Wishbone interface signals for DMEM
logic [31:0] wb_dmem_dat_i, wb_dmem_adr_i;
logic [3:0]  wb_dmem_sel_i;
logic        wb_dmem_we_i, wb_dmem_cyc_i, wb_dmem_stb_i;
logic [31:0] wb_dmem_dat_o;
logic        wb_dmem_ack_o, wb_dmem_err_o;


//=======================================================
// Instantiation of wishbone_bram_wrapper
//=======================================================

// Declare wires for connecting to the BRAM module
// logic we_a;                         // Write enable signal
// logic [12:0] addr_a;                // Address signal, 13 bits for ADDR_WIDTH = 13
// logic [63:0] din_a;                 // Data input, 64 bits for DATA_WIDTH = 64
// logic [63:0] dout_a;                // Data output, 64 bits for DATA_WIDTH = 64

 // Instantiation of bram_synch_one_port
//  bram_synch_one_port #(
//      .ADDR_WIDTH(13),   // Set address width (default is 13)
//      .DATA_WIDTH(64)    // Set data width (default is 64)
//  ) bram_inst (
//      .clk    (cpu_clk),          // Connect to system clock
//      .we_a   (we_a),         // Connect to write enable signal
//      .addr_a (addr_a),       // Connect to address input [ADDR_WIDTH-1:0]
//      .din_a  (din_a),        // Connect to data input [DATA_WIDTH-1:0]
//      .dout_a (dout_a)        // Connect to data output [DATA_WIDTH-1:0]
//  );

//bootloader	bootloader_inst (
//	.address ( addr_a ),
//	.clock ( cpu_clk ),
//	.data ( din_a ),
//	.wren ( we_a ),
//	.q ( dout_a )
//	);


// Declare wires for connecting to the Wishbone and BRAM interfaces
logic wb_bram_stb;                         // Wishbone strobe signal
logic wb_bram_cyc;                         // Wishbone cycle signal
logic wb_bram_we;                          // Wishbone write enable
logic [31:0] wb_bram_addr;                 // Wishbone address, 32 bits
logic [31:0] wb_bram_wdata;                // Wishbone write data, 32 bits
logic [31:0] wb_bram_rdata;                // Wishbone read data, 32 bits
logic wb_bram_ack;                         // Wishbone acknowledge signal
logic wb_bram_err;                         // Wishbone error signal

//// Instantiate the bram32_wishbone_wrapper
//bram32_wishbone_wrapper bram32_inst (
//    .clk(cpu_clk),           // Connect clock
//    .rst_n(soc_rst_n),           // Connect reset
//    .wb_adr_i(wb_bram_addr), // Connect address input
//    .wb_dat_i(wb_bram_wdata), // Connect data input for writes
//    .wb_dat_o(wb_bram_rdata), // Connect data output for reads
//    .wb_we_i(wb_bram_we),   // Connect write enable
//    .wb_stb_i(wb_bram_stb), // Connect strobe
//    .wb_cyc_i(wb_bram_cyc), // Connect cycle
//    .wb_ack_o(wb_bram_ack), // Connect acknowledge
//    .wb_err_o(wb_bram_err)  // Connect error output
//);

    

// wishbone_bram_wrapper #(
//     .ADDR_WIDTH(13),   // Set address width (13 for default)
//     .DATA_WIDTH(64)    // Set data width (64 for default)
// ) wishbone_bram_inst (
//     // Wishbone Interface
//     .clk        (cpu_clk),         // Connect to system clock
//     .rst_n      (soc_reset_n),       // Connect to active low reset
//     .wb_stb     (wb_bram_stb),      // Connect to Wishbone strobe signal
//     .wb_cyc     (wb_bram_cyc),      // Connect to Wishbone cycle signal
//     .wb_we      (wb_bram_we),       // Connect to Wishbone write enable
//     .wb_addr    (wb_bram_addr),     // Connect to Wishbone address bus [31:0]
//     .wb_wdata   (wb_bram_wdata),    // Connect to Wishbone write data bus [31:0]
//     .wb_rdata   (wb_bram_rdata),    // Connect to Wishbone read data bus [31:0]
//     .wb_ack     (wb_bram_ack),      // Connect to Wishbone acknowledge signal
//     .wb_err     (wb_bram_err),      // Connect to Wishbone error signal

//     // BRAM Interface
//     .bram_addr  (addr_a),   // Connect to BRAM address [ADDR_WIDTH-1:0]
//     .bram_we    (we_a),     // Connect to BRAM write enable
//     .bram_din   (din_a),    // Connect to BRAM data input [DATA_WIDTH-1:0]
//     .bram_dout  (dout_a)    // Connect to BRAM data output [DATA_WIDTH-1:0]
// );

//=======================================================
// Instantiate the Wishbone Interconnect module
//=======================================================
    wb_interconnect_2m2s u_wb_interconnect_2m2s (
        .clk_i(cpu_clk),
        .rst_n(soc_rst_n),
        // Master 0 Interface
        .m0_wbd_dat_i(wb_imem_dat_i),
        .m0_wbd_adr_i(wb_imem_adr_i),
        .m0_wbd_sel_i(wb_imem_sel_i),
        .m0_wbd_we_i(wb_imem_we_i),
        .m0_wbd_cyc_i(wb_imem_stb_i),
        .m0_wbd_stb_i(wb_imem_stb_i),
        .m0_wbd_dat_o(wb_imem_dat_o),
        .m0_wbd_ack_o(wb_imem_ack_o),
        .m0_wbd_err_o(wb_imem_err_o),
        // Master 1 Interface
        .m1_wbd_dat_i(wb_dmem_dat_i),
        .m1_wbd_adr_i(wb_dmem_adr_i),
        .m1_wbd_sel_i(wb_dmem_sel_i),
        .m1_wbd_we_i(wb_dmem_we_i),
        .m1_wbd_cyc_i(wb_dmem_stb_i),
        .m1_wbd_stb_i(wb_dmem_stb_i),
        .m1_wbd_dat_o(wb_dmem_dat_o),
        .m1_wbd_ack_o(wb_dmem_ack_o),
        .m1_wbd_err_o(wb_dmem_err_o),
        // Slave 0 Interface (UART)
        .s0_wbd_dat_i(wb_gpio_dat_o),
        .s0_wbd_ack_i(wb_gpio_ack),
        .s0_wbd_dat_o(wb_gpio_dat_i),
        .s0_wbd_adr_o(wb_gpio_adr),
        .s0_wbd_sel_o(),
        .s0_wbd_we_o(wb_gpio_we),
        .s0_wbd_cyc_o(wb_gpio_cyc),
        .s0_wbd_stb_o(wb_gpio_stb),
        // Slave 1 Interface (SRAM)
        .s1_wbd_dat_i(wb_bram_rdata),
        .s1_wbd_ack_i(wb_bram_ack),
        .s1_wbd_dat_o(wb_bram_wdata),
        .s1_wbd_adr_o(wb_bram_addr),
        .s1_wbd_sel_o(),
        .s1_wbd_we_o(wb_bram_we),
        .s1_wbd_cyc_o(wb_bram_cyc),
        .s1_wbd_stb_o(wb_bram_stb)
    );

//=======================================================
//  SIMPLE WISHBONE GPIO
//=======================================================

// Internal signals with specified directions
logic        wb_gpio_cyc;    // WISHBONE cycle signal
logic        wb_gpio_stb;    // WISHBONE strobe signal
logic [31:0] wb_gpio_adr;    // WISHBONE address bit
logic        wb_gpio_we;     // WISHBONE write enable
logic [7:0] wb_gpio_dat_i;  // Data input from WISHBONE
logic [7:0] wb_gpio_dat_o;  // Data output to WISHBONE
logic        wb_gpio_ack;    // Acknowledge signal
logic [7:0]  gpio_bus;       // Bidirectional GPIO bus

// Instantiate WBOPRT08
WBOPRT08 u_WBOPRT08 (
    .ACK_O(wb_gpio_ack),      // Connect acknowledge signal
    .CLK_I(cpu_clk),      // Connect clock
    .DAT_I(wb_gpio_dat_i),    // Connect data input
    .DAT_O(wb_gpio_dat_o),    // Connect data output
    .RST_I(~soc_rst_n),      // Connect reset
    .STB_I(wb_gpio_stb),      // Connect strobe
    .WE_I(wb_gpio_we),        // Connect write enable
    .PRT_O(gpio_bus)     // Connect output port
);

//=======================================================
//  FPGA Platform's System-on-Programmable-Chip (SOPC)
//=======================================================
de10lite_sopc
i_soc (
        // CLOCKs & RESETs
        .osc_50_clk                 (MAX10_CLK2_50          ),
        .cpu_clk_out_clk            (cpu_clk                ),
        .sdram_clk_out_clk          (DRAM_CLK               ),
        .pll_reset                  (1'b0                   ),
        .pwrup_rst_n_out_export     (pwrup_rst_n            ),
        .soc_reset_n                (soc_rst_n              ),
        .cpu_rst_out_reset_n        (cpu_rst_n              ),
        // SDRAM
        .sdram_addr                 (DRAM_ADDR              ),
        .sdram_ba                   (DRAM_BA                ),
        .sdram_cas_n                (DRAM_CAS_N             ),
        .sdram_cke                  (DRAM_CKE               ),
        .sdram_cs_n                 (DRAM_CS_N              ),
        .sdram_dq                   (DRAM_DQ                ),
        .sdram_dqm                  ({DRAM_UDQM,DRAM_LDQM}  ),
        .sdram_ras_n                (DRAM_RAS_N             ),
        .sdram_we_n                 (DRAM_WE_N              ),
        // I-MEM Avalon Bus
        .avl_imem_write             (avl_imem_write         ),
        .avl_imem_read              (avl_imem_read          ),
        .avl_imem_waitrequest       (avl_imem_waitrequest   ),
        .avl_imem_debugaccess       (1'd0                   ),
        .avl_imem_address           (avl_imem_address       ),
        .avl_imem_burstcount        (1'd1                   ),
        .avl_imem_byteenable        (avl_imem_byteenable    ),
        .avl_imem_writedata         (avl_imem_writedata     ),
        .avl_imem_readdatavalid     (avl_imem_readdatavalid ),
        .avl_imem_readdata          (avl_imem_readdata      ),
        .avl_imem_response          (avl_imem_response      ),
        // D-MEM Avalon Bus
        .avl_dmem_write             (avl_dmem_write         ),
        .avl_dmem_read              (avl_dmem_read          ),
        .avl_dmem_waitrequest       (avl_dmem_waitrequest   ),
        .avl_dmem_debugaccess       (1'd0                   ),
        .avl_dmem_address           (avl_dmem_address       ),
        .avl_dmem_burstcount        (1'd1                   ),
        .avl_dmem_byteenable        (avl_dmem_byteenable    ),
        .avl_dmem_writedata         (avl_dmem_writedata     ),
        .avl_dmem_readdatavalid     (avl_dmem_readdatavalid ),
        .avl_dmem_readdata          (avl_dmem_readdata      ),
        .avl_dmem_response          (avl_dmem_response      ),
        // PIO HEX LEDs
        .pio_hex_1_0_export         (pio_hex_1_0            ),
        .pio_hex_3_2_export         (pio_hex_3_2            ),
        .pio_hex_5_4_export         (pio_hex_5_4            ),
        // PIO LEDs
        .pio_led_export             (pio_led                ),
        // PIO SWITCHes
        .pio_sw_export              (pio_sw                 ),
        // UART
        .uart_waitrequest           (uart_waitrequest       ),
        .uart_readdata              (uart_readdata          ),
        .uart_readdatavalid         (uart_readdatavalid     ),
        .uart_burstcount            (                       ),
        .uart_writedata             (uart_writedata         ),
        .uart_address               (uart_address           ),
        .uart_write                 (uart_write             ),
        .uart_read                  (uart_read              ),
        .uart_byteenable            (                       ),
        .uart_debugaccess           (                       ),
        // PTFM IDs
        .soc_id_export              (FPGA_DE10_SOC_ID       ),
        .bld_id_export              (FPGA_DE10_BLD_ID       ),
        .core_clk_freq_export       (FPGA_DE10_CORE_CLK_FREQ)
);

//==========================================================
// JTAG
//==========================================================
`ifdef SCR1_DBG_EN
assign scr1_jtag_trst_n     = JTAG_TRST_N;
assign scr1_jtag_tck        = JTAG_TCK;
assign scr1_jtag_tms        = JTAG_TMS;
assign scr1_jtag_tdi        = JTAG_TDI;
assign JTAG_TDO             = (scr1_jtag_tdo_en) ? scr1_jtag_tdo_int : 1'bZ;
`endif // SCR1_DBG_EN

//==========================================================
// LEDs
//==========================================================
// assign LEDR[7:0]    =  pio_led;
assign HEX0[0]      = ~wb_imem_ack_o;
assign HEX0[1]      = ~wb_dmem_ack_o;
assign HEX0[2]		  = ~wb_gpio_stb;
assign HEX0[3]		  = ~wb_gpio_ack;
assign HEX0[4]		  = ~wb_bram_cyc;
assign HEX0[5]		  = ~wb_bram_ack;
assign HEX0[6]		  = ~1'b0;
assign HEX0[7]		  = ~1'b0;

assign HEX1[0]		  = ~wb_imem_stb_i;
assign HEX1[1]		  = ~wb_imem_err_o;
assign HEX1[2]		  = ~wb_dmem_stb_i;
assign HEX1[3]		  = ~wb_dmem_err_o;
assign HEX1[7:4]	  = ~1'b0;

assign LEDR[7:0] 	  =  gpio_bus;
assign LEDR[8]      = ~hard_rst_n;
assign LEDR[9]      =  heartbeat;
//assign {HEX1,HEX0}  =  pio_hex_1_0;

// Seven-Segment Display Outputs
seven_seg display_0 (
    .hex_digit(wb_imem_adr_i[18:15]),
    .segments(HEX2)
);

seven_seg display_1 (
    .hex_digit(wb_imem_adr_i[22:19]),
    .segments(HEX3)
);

seven_seg display_2 (
    .hex_digit(wb_imem_adr_i[26:23]),
    .segments(HEX4)
);

seven_seg display_3 (
    .hex_digit(wb_imem_adr_i[31:27]),
    .segments(HEX5)
);

// assign {HEX3,HEX2}  =  pio_hex_3_2;
// assign {HEX5,HEX4}  =  pio_hex_5_4;

//==========================================================
// DIP Switch
//==========================================================
assign pio_sw       = SW;

endmodule: de10lite_scr1
