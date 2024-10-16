/// Copyright by Syntacore LLC © 2016, 2017, 2021. See LICENSE for details
/// @file       <de10lite_scr1.sv>
/// @brief      Top-level entity with SCR1 for DE10-lite board
///

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
    //  KEY[0] is used as manual reset for SCR1 (see below).
    // === RAM ==============================================
    // SDRAM signals are no longer used
    // === LEDs ============================================
    output logic          [9:0]     LEDR,
    output logic          [7:0]     HEX0,
    output logic          [7:0]     HEX1,
    output logic          [7:0]     HEX2,
    output logic          [7:0]     HEX3,
    output logic          [7:0]     HEX4,
    output logic          [7:0]     HEX5,
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
    `endif // SCR1_DBG_EN
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

// --- Wishbone Interface for I-MEM Bridge --------------
logic [31:0]                        wb_imem_adr_o;
logic                               wb_imem_we_o;
logic                               wb_imem_cyc_o;
logic                               wb_imem_stb_o;
logic [3:0]                         wb_imem_sel_o;
logic [31:0]                        wb_imem_dat_o;
logic                               wb_imem_ack_i;
logic [31:0]                        wb_imem_dat_i;

// --- Wishbone Interface for D-MEM Bridge --------------
logic [31:0]                        wb_dmem_adr_o;
logic                               wb_dmem_we_o;
logic                               wb_dmem_cyc_o;
logic                               wb_dmem_stb_o;
logic [3:0]                         wb_dmem_sel_o;
logic [31:0]                        wb_dmem_dat_o;
logic                               wb_dmem_ack_i;
logic [31:0]                        wb_dmem_dat_i;

// --- UART ---------------------------------------------
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

// --- Wishbone Interconnect Signals ---------------------
logic [31:0]                        wb_ram_adr_o;
logic [31:0]                        wb_ram_dat_o;
logic [3:0]                         wb_ram_sel_o;
logic                               wb_ram_we_o;
logic                               wb_ram_cyc_o;
logic                               wb_ram_stb_o;
logic [31:0]                        wb_ram_dat_i;
logic                               wb_ram_ack_i;
logic                               wb_ram_err_i;

// UART Slave Interface
logic [31:0]                        wb_uart_adr_i;
logic [31:0]                        wb_uart_dat_i;
logic [3:0]                         wb_uart_sel_i;
logic                               wb_uart_we_i;
logic                               wb_uart_cyc_i;
logic                               wb_uart_stb_i;
logic [31:0]                        wb_uart_dat_o;
logic                               wb_uart_ack_o;
logic                               wb_uart_err_o;

//=======================================================
//  Resets
//=======================================================
assign extn_rst_in_n    = KEY[0]
`ifdef SCR1_DBG_EN
                        & JTAG_SRST_N
`endif // SCR1_DBG_EN
;

always_ff @(posedge cpu_clk, negedge pwrup_rst_n) begin
    if (~pwrup_rst_n) begin
        extn_rst_n_sync     <= '0;
    end else begin
        extn_rst_n_sync[0]  <= extn_rst_in_n;
        extn_rst_n_sync[1]  <= extn_rst_n_sync[0];
    end
end
assign extn_rst_n = extn_rst_n_sync[1];

always_ff @(posedge cpu_clk, negedge pwrup_rst_n) begin
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
always_ff @(posedge cpu_clk, negedge hard_rst_n) begin
    if (~hard_rst_n) begin
        rtc_counter     <= '0;
        tick_2Hz        <= 1'b0;
    end else begin
        if (rtc_counter == '0) begin
            rtc_counter <= (FPGA_DE10_CORE_CLK_FREQ/2);
            tick_2Hz    <= 1'b1;
        end else begin
            rtc_counter <= rtc_counter - 1'b1;
            tick_2Hz    <= 1'b0;
        end
    end
end

always_ff @(posedge cpu_clk, negedge hard_rst_n) begin
    if (~hard_rst_n) begin
        heartbeat       <= 1'b0;
    end else begin
        if (tick_2Hz) begin
            heartbeat   <= ~heartbeat;
        end
    end
end

//=======================================================
//  SCR1 Core's Processor Cluster
//=======================================================
scr1_top_ahb i_scr1 (
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
    .ext_irq                    (scr1_irq               ),
`endif // SCR1_IPIC_EN
    .soft_irq                   ('0                     ),

`ifdef SCR1_DBG_EN
    // Debug Interface - JTAG I/F
    .trst_n                     (scr1_jtag_trst_n       ),
    .tck                        (scr1_jtag_tck          ),
    .tms                        (scr1_jtag_tms          ),
    .tdi                        (scr1_jtag_tdi          ),
    .tdo                        (scr1_jtag_tdo_int      ),
    .tdo_en                     (scr1_jtag_tdo_en       ),
`endif // SCR1_DBG_EN

    // Instruction Memory Interface
    .imem_hprot                 (ahb_imem_hprot         ),
    .imem_hburst                (ahb_imem_hburst        ),
    .imem_hsize                 (ahb_imem_hsize         ),
    .imem_htrans                (ahb_imem_htrans        ),
    .imem_hmastlock             (                       ),
    .imem_haddr                 (ahb_imem_haddr         ),
    .imem_hready                (ahb_imem_hready        ),
    .imem_hrdata                (ahb_imem_hrdata        ),
    .imem_hresp                 (ahb_imem_hresp         ),
    // Data Memory Interface
    .dmem_hprot                 (ahb_dmem_hprot         ),
    .dmem_hburst                (ahb_dmem_hburst        ),
    .dmem_hsize                 (ahb_dmem_hsize         ),
    .dmem_htrans                (ahb_dmem_htrans        ),
    .dmem_hmastlock             (                       ),
    .dmem_haddr                 (ahb_dmem_haddr         ),
    .dmem_hwrite                (ahb_dmem_hwrite        ),
    .dmem_hwdata                (ahb_dmem_hwdata        ),
    .dmem_hready                (ahb_dmem_hready        ),
    .dmem_hrdata                (ahb_dmem_hrdata        ),
    .dmem_hresp                 (ahb_dmem_hresp         )
);

`ifdef SCR1_IPIC_EN
assign scr1_irq = {31'd0, uart_irq};
`else
assign scr1_irq = uart_irq;
`endif // SCR1_IPIC_EN

//==========================================================
// UART 16550 IP
//==========================================================
//always_ff @(posedge cpu_clk, negedge soc_rst_n)
//    if (~soc_rst_n)
//        uart_read_vd <= '0;
//    else if (uart_wb_ack)
//        uart_read_vd <= '0;
//    else if (uart_read)
//        uart_read_vd <= '1;
//
//always_ff @(posedge cpu_clk) begin
//    uart_readdatavalid  <= uart_wb_ack & uart_read_vd;
//    uart_readdata       <= {24'd0, uart_wb_dat};
//end
//
//assign uart_waitrequest = ~uart_wb_ack;

uart_top i_uart (
    .wb_clk_i       (cpu_clk                ),
    // Wishbone signals
    .wb_rst_i       (~soc_rst_n             ),
    .wb_adr_i       (wb_uart_adr_i          ),
    .wb_dat_i       (wb_uart_dat_i          ),
    .wb_dat_o       (wb_uart_dat_o          ),
    .wb_we_i        (wb_uart_we_i           ),
    .wb_stb_i       (wb_uart_stb_i          ),
    .wb_cyc_i       (wb_uart_cyc_i          ),
    .wb_ack_o       (wb_uart_ack_o          ),
    .wb_sel_i       (wb_uart_sel_i          ),
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

//==========================================================
// AHB I-MEM Bridge
//==========================================================
ahb_wishbone_bridge i_ahb_imem (
    // Wishbone master side
    .clk            (cpu_clk                ),
    .reset_n        (soc_rst_n              ),
    .adr_o          (wb_imem_adr_o          ),
    .we_o           (wb_imem_we_o           ),
    .cyc_o          (wb_imem_cyc_o          ),
    .stb_o          (wb_imem_stb_o          ),
    .byteenable     (wb_imem_sel_o          ),
    .dat_o          (wb_imem_dat_o          ),
    .ack_i          (wb_imem_ack_i          ),
    .dat_i          (wb_imem_dat_i          ),
    // AHB slave side
    .HRDATA         (ahb_imem_hrdata        ),
    .HRESP          (ahb_imem_hresp         ),
    .HSIZE          (ahb_imem_hsize         ),
    .HTRANS         (ahb_imem_htrans        ),
    .HADDR          (ahb_imem_haddr         ),
    .HWDATA         ('0                     ),  // Instruction fetches
    .HWRITE         ('0                     ),  // Instruction fetches
    .HREADY         (ahb_imem_hready        )
);

//==========================================================
// AHB D-MEM Bridge
//==========================================================
ahb_wishbone_bridge i_ahb_dmem (
    // Wishbone master side
    .clk            (cpu_clk                ),
    .reset_n        (soc_rst_n              ),
    .adr_o          (wb_dmem_adr_o          ),
    .we_o           (wb_dmem_we_o           ),
    .cyc_o          (wb_dmem_cyc_o          ),
    .stb_o          (wb_dmem_stb_o          ),
    .byteenable     (wb_dmem_sel_o          ),
    .dat_o          (wb_dmem_dat_o          ),
    .ack_i          (wb_dmem_ack_i          ),
    .dat_i          (wb_dmem_dat_i          ),
    // AHB slave side
    .HRDATA         (ahb_dmem_hrdata        ),
    .HRESP          (ahb_dmem_hresp         ),
    .HSIZE          (ahb_dmem_hsize         ),
    .HTRANS         (ahb_dmem_htrans        ),
    .HADDR          (ahb_dmem_haddr         ),
    .HWDATA         (ahb_dmem_hwdata        ),
    .HWRITE         (ahb_dmem_hwrite        ),
    .HREADY         (ahb_dmem_hready        )
);

//=======================================================
//  Wishbone Interconnect (Replaced wb_interconnect3 with wb_interconnect4)
//=======================================================
wb_interconnect4 i_wb_interconnect (
    // System Clock and Reset
    .clk_i          (cpu_clk                ),
    .rst_n          (soc_rst_n              ),

    // Master 0 Interface (I-MEM)
    .m0_wbd_dat_i   (wb_imem_dat_o          ),
    .m0_wbd_adr_i   (wb_imem_adr_o          ),
    .m0_wbd_sel_i   (wb_imem_sel_o          ),
    .m0_wbd_we_i    (wb_imem_we_o           ),
    .m0_wbd_cyc_i   (wb_imem_cyc_o          ),
    .m0_wbd_stb_i   (wb_imem_stb_o          ),
    .m0_wbd_dat_o   (wb_imem_dat_i          ),
    .m0_wbd_ack_o   (wb_imem_ack_i          ),
    .m0_wbd_err_o   (),                      // Not connected

    // Master 1 Interface (D-MEM)
    .m1_wbd_dat_i   (wb_dmem_dat_o          ),
    .m1_wbd_adr_i   (wb_dmem_adr_o          ),
    .m1_wbd_sel_i   (wb_dmem_sel_o          ),
    .m1_wbd_we_i    (wb_dmem_we_o           ),
    .m1_wbd_cyc_i   (wb_dmem_cyc_o          ),
    .m1_wbd_stb_i   (wb_dmem_stb_o          ),
    .m1_wbd_dat_o   (wb_dmem_dat_i          ),
    .m1_wbd_ack_o   (wb_dmem_ack_i          ),
    .m1_wbd_err_o   (),                      // Not connected

    // Slave 0 Interface (Bootloader RAM)
    .s0_wbd_dat_i   (wb_ram_dat_i           ),
    .s0_wbd_ack_i   (wb_ram_ack_i           ),
    .s0_wbd_dat_o   (wb_ram_dat_o           ),
    .s0_wbd_adr_o   (wb_ram_adr_o           ),
    .s0_wbd_sel_o   (wb_ram_sel_o           ),
    .s0_wbd_we_o    (wb_ram_we_o            ),
    .s0_wbd_cyc_o   (wb_ram_cyc_o           ),
    .s0_wbd_stb_o   (wb_ram_stb_o           ),

    // Slave 1 Interface (UART)
    .s1_wbd_dat_i   (wb_uart_dat_o          ),
    .s1_wbd_ack_i   (wb_uart_ack_o          ),
    .s1_wbd_dat_o   (wb_uart_dat_i          ),
    .s1_wbd_adr_o   (wb_uart_adr_i          ),
    .s1_wbd_sel_o   (wb_uart_sel_i          ),
    .s1_wbd_we_o    (wb_uart_we_i           ),
    .s1_wbd_cyc_o   (wb_uart_cyc_i          ),
    .s1_wbd_stb_o   (wb_uart_stb_i          )
);

// **Important Changes:**
//
// 1. **Module Replacement:**
//    - Replaced `wb_interconnect3` with `wb_interconnect4`.
//
// 2. **Port Connections:**
//    - The `wb_interconnect4` module includes an additional output port `*_err_o` for each master.
//    - In this example, the `*_err_o` ports are left unconnected by using `()`. If error handling is required, connect these to appropriate signals or tie them to a default value.
//
// 3. **Power Pins:**
//    - The `wb_interconnect4` module has conditional power pins (`vccd1` and `vssd1`).
//    - If your design uses power pins, ensure that `USE_POWER_PINS` is defined and connect them accordingly.
//    - In this example, it's assumed that power pins are not used, so no connections are made.
//
// 4. **Error Signals:**
//    - Since `wb_interconnect4` introduces error signals (`m0_wbd_err_o`, `m1_wbd_err_o`, etc.), decide how to handle them.
//    - In this replacement, they are left unconnected. If you wish to monitor or handle errors, connect these ports to appropriate logic in your design.
//
// **Example Handling of Error Signals (Optional):**
// If you want to monitor error signals, you can modify the instantiation as follows:
//
// ```systemverilog
// .m0_wbd_err_o   (wb_imem_err_i          ),
// .m1_wbd_err_o   (wb_dmem_err_i          ),
// ```
//
// Then, declare `wb_imem_err_i` and `wb_dmem_err_i` in your signal declarations and handle them as needed.


//=======================================================
//  Instantiate the wb_bootloader_ram
//=======================================================
wb_bootloader_ram i_wb_bootloader_ram (
     .wb_clk_i    (cpu_clk            ),
     .wb_rst_i    (~soc_rst_n         ),
     .wb_adr_i    (wb_ram_adr_o       ),
     .wb_dat_i    (wb_ram_dat_o       ),
     .wb_sel_i    (wb_ram_sel_o       ),
     .wb_we_i     (wb_ram_we_o        ),
     .wb_cyc_i    (wb_ram_cyc_o       ),
     .wb_stb_i    (wb_ram_stb_o       ),
     .wb_dat_o    (wb_ram_dat_i       ),
     .wb_ack_o    (wb_ram_ack_i       ),
     .wb_err_o    (wb_ram_err_i       )
 );

//=======================================================
//  Instantiate the wishbone_bram_64 module (replace wb_bootloader_ram)
//=======================================================
//wishbone_bram_64 i_wishbone_bram_64 (
//    .clk        (cpu_clk            ),         // Clock input
//    .reset      (~soc_rst_n         ),      // Reset input, active low
//    .wb_addr    (wb_ram_adr_o       ), // Address width matching 13 bits
//    .wb_din     (wb_ram_dat_o       ),    // Data input from Wishbone
//    .wb_dout    (wb_ram_dat_i       ),    // Data output to Wishbone
//    .wb_we      (wb_ram_we_o        ),     // Write enable
//    .wb_stb     (wb_ram_stb_o       ),    // Strobe signal
//    .wb_ack     (wb_ram_ack_i       )     // Acknowledge signal
//);

//=======================================================
//  FPGA Platform's System-on-Programmable-Chip (SOPC)
//=======================================================
// If the `de10lite_sopc` module is not required for other functionalities, it can be removed.
// Otherwise, ensure it provides necessary clock and reset signals.

de10lite_sopc i_soc (
    // CLOCKs & RESETs
    .osc_50_clk                 (MAX10_CLK2_50          ),
    .cpu_clk_out_clk            (cpu_clk                ),
    .pll_reset                  (1'b0                   ),
    .pwrup_rst_n_out_export     (pwrup_rst_n            ),
    .soc_reset_n                (soc_rst_n              ),
    .cpu_rst_out_reset_n        (cpu_rst_n              ),
    // PIO HEX LEDs
    .pio_hex_1_0_export         (pio_hex_1_0            ),
    .pio_hex_3_2_export         (pio_hex_3_2            ),
    .pio_hex_5_4_export         (pio_hex_5_4            ),
    // PIO LEDs
    // .pio_led_export             (pio_led                ),
    // PIO SWITCHes
    .pio_sw_export              (pio_sw                 ),
    // UART
    // .uart_waitrequest           (uart_waitrequest       ),
    // .uart_readdata              (uart_readdata          ),
    // .uart_readdatavalid         (uart_readdatavalid     ),
    // .uart_writedata             (uart_writedata         ),
    // .uart_address               (uart_address           ),
    // .uart_write                 (uart_write             ),
    // .uart_read                  (uart_read              ),
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
// LEDs - Implementing Test Hooks
//==========================================================

// Assign LEDs based on Wishbone interconnect signals
assign pio_led[0] = wb_imem_cyc_o;    // Master 0 (I-MEM) Active
assign pio_led[1] = wb_dmem_cyc_o;    // Master 1 (D-MEM) Active
assign pio_led[2] = wb_ram_cyc_o;     // Slave 0 (Bootloader RAM) Active
assign pio_led[3] = wb_uart_cyc_i;    // Slave 1 (UART) Active
assign pio_led[4] = wb_ram_ack_i;     // Slave 0 (Bootloader RAM) Acknowledge
assign pio_led[5] = wb_uart_ack_o;    // Slave 1 (UART) Acknowledge
assign pio_led[6] = uart_irq;         // UART Interrupt (IRQ[0])
assign pio_led[7] = wb_ram_err_i;     // Error Indicator

//==========================================================
// LEDs
//==========================================================
assign LEDR[7:0]    =  pio_led;
assign LEDR[8]      = ~hard_rst_n;
assign LEDR[9]      =  heartbeat;
assign {HEX1, HEX0} =  pio_hex_1_0;
assign {HEX3, HEX2} =  pio_hex_3_2;
assign {HEX5, HEX4} =  pio_hex_5_4;

//==========================================================
// DIP Switch
//==========================================================
assign pio_sw       = SW;

endmodule: de10lite_scr1
