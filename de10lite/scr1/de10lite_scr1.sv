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
logic [31:0]                        ahb_imem_haddr;
logic                               ahb_imem_hready;
logic [31:0]                        ahb_imem_hrdata;
logic                               ahb_imem_hresp;
//
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

// --- AHB to Wishbone Bridges --------------------------
logic [31:0]                        wbm_imem_adr_o;
logic [31:0]                        wbm_imem_dat_o;
logic [31:0]                        wbm_imem_dat_i;
logic                               wbm_imem_we_o;
logic                               wbm_imem_cyc_o;
logic                               wbm_imem_stb_o;
logic                               wbm_imem_ack_i;
logic                               wbm_imem_err_i;

logic [31:0]                        wbm_dmem_adr_o;
logic [31:0]                        wbm_dmem_dat_o;
logic [31:0]                        wbm_dmem_dat_i;
logic                               wbm_dmem_we_o;
logic                               wbm_dmem_cyc_o;
logic                               wbm_dmem_stb_o;
logic                               wbm_dmem_ack_i;
logic                               wbm_dmem_err_i;

// --- Wishbone to Avalon Bridges -----------------------
logic                               wbs_imem_cyc_i;
logic                               wbs_imem_stb_i;
logic [31:0]                        wbs_imem_adr_i;
logic [31:0]                        wbs_imem_dat_i;
logic [3:0]                         wbs_imem_sel_i;
logic                               wbs_imem_we_i;
logic [31:0]                        wbs_imem_dat_o;
logic                               wbs_imem_ack_o;

logic                               wbs_dmem_cyc_i;
logic                               wbs_dmem_stb_i;
logic [31:0]                        wbs_dmem_adr_i;
logic [31:0]                        wbs_dmem_dat_i;
logic [3:0]                         wbs_dmem_sel_i;
logic                               wbs_dmem_we_i;
logic [31:0]                        wbs_dmem_dat_o;
logic                               wbs_dmem_ack_o;

// --- Avalon Interfaces ---------------------------------
logic                               avl_imem_write;
logic                               avl_imem_read;
logic                               avl_imem_waitrequest;
logic [31:0]                        avl_imem_address;
logic [3:0]                         avl_imem_byteenable;
logic [31:0]                        avl_imem_writedata;
logic                               avl_imem_readdatavalid;
logic [31:0]                        avl_imem_readdata;
logic [1:0]                         avl_imem_response;
//
logic                               avl_dmem_write;
logic                               avl_dmem_read;
logic                               avl_dmem_waitrequest;
logic [31:0]                        avl_dmem_address;
logic [3:0]                         avl_dmem_byteenable;
logic [31:0]                        avl_dmem_writedata;
logic                               avl_dmem_readdatavalid;
logic [31:0]                        avl_dmem_readdata;
logic [1:0]                         avl_dmem_response;

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
scr1_top_ahb
i_scr1 (
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

//=======================================================
//  AHB to Wishbone Bridges
//=======================================================
// Instruction AHB to Wishbone Bridge
ahb2wb i_ahb2wb_imem (
    .hclk(cpu_clk),
    .hresetn(soc_rst_n),
    // AHB Master Interface
    .haddr(ahb_imem_haddr),
    .hwrite(1'b0), // Instruction bus is read-only
    .htrans(ahb_imem_htrans),
    .hsize(ahb_imem_hsize),
    .hburst(ahb_imem_hburst),
    .hwdata(32'b0),
    .hrdata(ahb_imem_hrdata),
    .hready(ahb_imem_hready),
    .hresp(ahb_imem_hresp),
    .hsel(1'b1),
    // Wishbone Master Interface
    .adr_o(wbm_imem_adr_o),
    .dat_i(wbm_imem_dat_i),
    .dat_o(wbm_imem_dat_o),
    .we_o(wbm_imem_we_o),
    .cyc_o(wbm_imem_cyc_o),
    .stb_o(wbm_imem_stb_o),
    .ack_i(wbm_imem_ack_i),
    .clk_i(cpu_clk),
    .rst_i(~soc_rst_n)
);

// Data AHB to Wishbone Bridge
ahb2wb i_ahb2wb_dmem (
    .hclk(cpu_clk),
    .hresetn(soc_rst_n),
    // AHB Master Interface
    .haddr(ahb_dmem_haddr),
    .hwrite(ahb_dmem_hwrite),
    .htrans(ahb_dmem_htrans),
    .hsize(ahb_dmem_hsize),
    .hburst(ahb_dmem_hburst),
    .hwdata(ahb_dmem_hwdata),
    .hrdata(ahb_dmem_hrdata),
    .hready(ahb_dmem_hready),
    .hresp(ahb_dmem_hresp),
    .hsel(1'b1),
    // Wishbone Master Interface
    .adr_o(wbm_dmem_adr_o),
    .dat_i(wbm_dmem_dat_i),
    .dat_o(wbm_dmem_dat_o),
    .we_o(wbm_dmem_we_o),
    .cyc_o(wbm_dmem_cyc_o),
    .stb_o(wbm_dmem_stb_o),
    .ack_i(wbm_dmem_ack_i),
    .clk_i(cpu_clk),
    .rst_i(~soc_rst_n)
);

//=======================================================
//  Wishbone Interconnect
//=======================================================
wb_interconnect i_wb_interconnect (
    .clk_i(cpu_clk),
    .rst_n(soc_rst_n),

    // Master 0 Interface (Instruction Bus)
    .m0_wbd_dat_i(wbm_imem_dat_o),
    .m0_wbd_adr_i(wbm_imem_adr_o),
    .m0_wbd_sel_i(4'b1111),
    .m0_wbd_we_i(wbm_imem_we_o),
    .m0_wbd_cyc_i(wbm_imem_cyc_o),
    .m0_wbd_stb_i(wbm_imem_stb_o),
    .m0_wbd_dat_o(wbm_imem_dat_i),
    .m0_wbd_ack_o(wbm_imem_ack_i),
    .m0_wbd_err_o(),

    // Master 1 Interface (Data Bus)
    .m1_wbd_dat_i(wbm_dmem_dat_o),
    .m1_wbd_adr_i(wbm_dmem_adr_o),
    .m1_wbd_sel_i(4'b1111),
    .m1_wbd_we_i(wbm_dmem_we_o),
    .m1_wbd_cyc_i(wbm_dmem_cyc_o),
    .m1_wbd_stb_i(wbm_dmem_stb_o),
    .m1_wbd_dat_o(wbm_dmem_dat_i),
    .m1_wbd_ack_o(wbm_dmem_ack_i),
    .m1_wbd_err_o(),

    // Slave 0 Interface (Instruction Wishbone to Avalon Bridge)
    .s0_wbd_dat_i(wbs_imem_dat_o),
    .s0_wbd_ack_i(wbs_imem_ack_o),
    .s0_wbd_dat_o(wbs_imem_dat_i),
    .s0_wbd_adr_o(wbs_imem_adr_i),
    .s0_wbd_sel_o(wbs_imem_sel_i),
    .s0_wbd_we_o(wbs_imem_we_i),
    .s0_wbd_cyc_o(wbs_imem_cyc_i),
    .s0_wbd_stb_o(wbs_imem_stb_i),

    // Slave 1 Interface (Data Wishbone to Avalon Bridge)
    .s1_wbd_dat_i(wbs_dmem_dat_o),
    .s1_wbd_ack_i(wbs_dmem_ack_o),
    .s1_wbd_dat_o(wbs_dmem_dat_i),
    .s1_wbd_adr_o(wbs_dmem_adr_i),
    .s1_wbd_sel_o(wbs_dmem_sel_i),
    .s1_wbd_we_o(wbs_dmem_we_i),
    .s1_wbd_cyc_o(wbs_dmem_cyc_i),
    .s1_wbd_stb_o(wbs_dmem_stb_i),
);

//=======================================================
//  Wishbone to Avalon Bridges
//=======================================================
// Instruction Wishbone to Avalon Bridge
wb_to_avalon_bridge i_wb2av_imem (
    .clk(cpu_clk),
    .reset_n(soc_rst_n),
    // Wishbone Slave Interface
    .wbs_dat_i(wbs_imem_dat_i),
    .wbs_adr_i(wbs_imem_adr_i),
    .wbs_sel_i(wbs_imem_sel_i),
    .wbs_we_i(wbs_imem_we_i),
    .wbs_cyc_i(wbs_imem_cyc_i),
    .wbs_stb_i(wbs_imem_stb_i),
    .wbs_dat_o(wbs_imem_dat_o),
    .wbs_ack_o(wbs_imem_ack_o),
    // Avalon Master Interface
    .address(avl_imem_address),
    .write(avl_imem_write),
    .read(avl_imem_read),
    .writedata(avl_imem_writedata),
    .byteenable(avl_imem_byteenable),
    .waitrequest(avl_imem_waitrequest),
    .readdata(avl_imem_readdata),
    .readdatavalid(avl_imem_readdatavalid),
    .response(avl_imem_response)
);

// Data Wishbone to Avalon Bridge
wb_to_avalon_bridge i_wb2av_dmem (
    .clk(cpu_clk),
    .reset_n(soc_rst_n),
    // Wishbone Slave Interface
    .wbs_dat_i(wbs_dmem_dat_i),
    .wbs_adr_i(wbs_dmem_adr_i),
    .wbs_sel_i(wbs_dmem_sel_i),
    .wbs_we_i(wbs_dmem_we_i),
    .wbs_cyc_i(wbs_dmem_cyc_i),
    .wbs_stb_i(wbs_dmem_stb_i),
    .wbs_dat_o(wbs_dmem_dat_o),
    .wbs_ack_o(wbs_dmem_ack_o),
    // Avalon Master Interface
    .address(avl_dmem_address),
    .write(avl_dmem_write),
    .read(avl_dmem_read),
    .writedata(avl_dmem_writedata),
    .byteenable(avl_dmem_byteenable),
    .waitrequest(avl_dmem_waitrequest),
    .readdata(avl_dmem_readdata),
    .readdatavalid(avl_dmem_readdatavalid),
    .response(avl_dmem_response)
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

uart_top
i_uart(
    .wb_clk_i       (cpu_clk                ),
    // Wishbone signals
    .wb_rst_i       (~soc_rst_n             ),
    .wb_adr_i       (uart_address[4:2]      ),
    .wb_dat_i       (uart_writedata[7:0]    ),
    .wb_dat_o       (uart_wb_dat            ),
    .wb_we_i        (uart_write             ),
    .wb_stb_i       (uart_read_vd|uart_write),
    .wb_cyc_i       (uart_read_vd|uart_write),
    .wb_ack_o       (uart_wb_ack            ),
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
assign LEDR[7:0]    =  pio_led;
assign LEDR[8]      = ~hard_rst_n;
assign LEDR[9]      =  heartbeat;
assign {HEX1,HEX0}  =  pio_hex_1_0;
assign {HEX3,HEX2}  =  pio_hex_3_2;
assign {HEX5,HEX4}  =  pio_hex_5_4;

//==========================================================
// DIP Switch
//==========================================================
assign pio_sw       = SW;

endmodule: de10lite_scr1
