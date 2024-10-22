module ahb_splitter (
    input  logic                 clk,
    input  logic                 rst_n,
    
    // SCR1 Core AHB master interface
    input  logic  [31:0]         HADDR,
    input  logic  [31:0]         HWDATA,
    input  logic  [2:0]          HSIZE,
    input  logic  [1:0]          HTRANS,
    input  logic  [3:0]          HPROT,
    input  logic                 HWRITE,
    output logic  [31:0]         HRDATA,
    output logic                 HRESP,
    output logic                 HREADY,

    // AHB bus 1 (connected to AHB-to-Avalon bridge 1)
    output logic  [31:0]         HADDR1,
    output logic  [31:0]         HWDATA1,
    output logic  [2:0]          HSIZE1,
    output logic  [1:0]          HTRANS1,
    output logic  [3:0]          HPROT1,
    output logic                 HWRITE1,
    input  logic  [31:0]         HRDATA1,
    input  logic                 HRESP1,
    input  logic                 HREADY1,

    // AHB bus 2 (connected to AHB-to-Avalon bridge 2)
    output logic  [31:0]         HADDR2,
    output logic  [31:0]         HWDATA2,
    output logic  [2:0]          HSIZE2,
    output logic  [1:0]          HTRANS2,
    output logic  [3:0]          HPROT2,
    output logic                 HWRITE2,
    input  logic  [31:0]         HRDATA2,
    input  logic                 HRESP2,
    input  logic                 HREADY2
);

// Internal signals for round-robin arbitration
logic  select;
logic  next_select;
logic  grant1, grant2;
logic  ahb_ready;

// Registers for holding the AHB bus 1 signals
logic [31:0] HADDR1_reg;
logic [31:0] HWDATA1_reg;
logic [2:0]  HSIZE1_reg;
logic [1:0]  HTRANS1_reg;
logic [3:0]  HPROT1_reg;
logic        HWRITE1_reg;

// Registers for holding the AHB bus 2 signals
logic [31:0] HADDR2_reg;
logic [31:0] HWDATA2_reg;
logic [2:0]  HSIZE2_reg;
logic [1:0]  HTRANS2_reg;
logic [3:0]  HPROT2_reg;
logic        HWRITE2_reg;

// Round-Robin Arbiter
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        select <= 1'b0;
    // end else if (ahb_ready) begin
    //     select <= next_select;
    end else begin
        select <= 1'b0;
    end
end

// Compute next select based on the current selection (toggle between 0 and 1)
assign next_select = ~select;

// Grant signals for arbitration
assign grant1 = (select == 1'b0);
assign grant2 = (select == 1'b1);

// Register the AHB bus 1 signals, update only when granted
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        HADDR1_reg  <= 32'd0;
        HWDATA1_reg <= 32'd0;
        HSIZE1_reg  <= 3'd0;
        HTRANS1_reg <= 2'd0;
        HPROT1_reg  <= 4'd0;
        HWRITE1_reg <= 1'b0;
    end else if (grant1) begin
        HADDR1_reg  <= HADDR;
        HWDATA1_reg <= HWDATA;
        HSIZE1_reg  <= HSIZE;
        HTRANS1_reg <= HTRANS;
        HPROT1_reg  <= HPROT;
        HWRITE1_reg <= HWRITE;
    end
end

// Register the AHB bus 2 signals, update only when granted
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        HADDR2_reg  <= 32'd0;
        HWDATA2_reg <= 32'd0;
        HSIZE2_reg  <= 3'd0;
        HTRANS2_reg <= 2'd0;
        HPROT2_reg  <= 4'd0;
        HWRITE2_reg <= 1'b0;
    end else if (grant2) begin
        HADDR2_reg  <= HADDR;
        HWDATA2_reg <= HWDATA;
        HSIZE2_reg  <= HSIZE;
        HTRANS2_reg <= HTRANS;
        HPROT2_reg  <= HPROT;
        HWRITE2_reg <= HWRITE;
    end
end

// Output the registered values to the respective buses
assign HADDR1    = HADDR1_reg;
assign HWDATA1   = HWDATA1_reg;
assign HSIZE1    = HSIZE1_reg;
assign HTRANS1   = HTRANS1_reg;
assign HPROT1    = HPROT1_reg;
assign HWRITE1   = HWRITE1_reg;

assign HADDR2    = HADDR2_reg;
assign HWDATA2   = HWDATA2_reg;
assign HSIZE2    = HSIZE2_reg;
assign HTRANS2   = HTRANS2_reg;
assign HPROT2    = HPROT2_reg;
assign HWRITE2   = HWRITE2_reg;

// Demux for read data and response signals based on the grant
assign HRDATA    = grant1 ? HRDATA1  : HRDATA2;
assign HRESP     = grant1 ? HRESP1   : HRESP2;
assign HREADY    = grant1 ? HREADY1  : HREADY2;

// AHB ready signal is the combined readiness of both buses
// assign ahb_ready = (grant1 && HREADY1) || (grant2 && HREADY2);

endmodule


// module ahb_splitter (
//     input  logic                 clk,
//     input  logic                 rst_n,
    
//     // SCR1 Core AHB master interface
//     input  logic  [31:0]         HADDR,
//     input  logic  [31:0]         HWDATA,
//     input  logic  [2:0]          HSIZE,
//     input  logic  [1:0]          HTRANS,
//     input  logic  [3:0]          HPROT,
//     input  logic                 HWRITE,
//     output logic  [31:0]         HRDATA,
//     output logic                 HRESP,
//     output logic                 HREADY,

//     // AHB bus 1 (connected to AHB-to-Avalon bridge 1)
//     output logic  [31:0]         HADDR1,
//     output logic  [31:0]         HWDATA1,
//     output logic  [2:0]          HSIZE1,
//     output logic  [1:0]          HTRANS1,
//     output logic  [3:0]          HPROT1,
//     output logic                 HWRITE1,
//     input  logic  [31:0]         HRDATA1,
//     input  logic                 HRESP1,
//     input  logic                 HREADY1,

//     // AHB bus 2 (connected to AHB-to-Avalon bridge 2)
//     output logic  [31:0]         HADDR2,
//     output logic  [31:0]         HWDATA2,
//     output logic  [2:0]          HSIZE2,
//     output logic  [1:0]          HTRANS2,
//     output logic  [3:0]          HPROT2,
//     output logic                 HWRITE2,
//     input  logic  [31:0]         HRDATA2,
//     input  logic                 HRESP2,
//     input  logic                 HREADY2
// );

// // Internal signals for round-robin arbitration
// logic  select;
// logic  next_select;
// logic  grant1, grant2;
// logic  ahb_ready;

// // Round-Robin Arbiter
// always_ff @(posedge clk or negedge rst_n) begin
//     if (!rst_n) begin
//         select <= 1'b0;
//     end 
// 	 else if (ahb_ready) begin
//         select <= 1'b0;
//     end
// //	 else begin
// //        select <= next_select;
// //    end
// end

// // Compute next select based on the current selection
// assign next_select = ~select; // Toggle between 0 and 1 for round-robin

// // Grant signals for arbitration
// assign grant1 = (select == 1'b0);
// assign grant2 = (select == 1'b1);

// // Mux to select between AHB buses for address/control signals
// assign HADDR1    = grant1 ? HADDR    : 32'd0;
// assign HWDATA1   = grant1 ? HWDATA   : 32'd0;
// assign HSIZE1    = grant1 ? HSIZE    : 3'd0;
// assign HTRANS1   = grant1 ? HTRANS   : 2'd0;
// assign HPROT1    = grant1 ? HPROT    : 4'd0;
// assign HWRITE1   = grant1 ? HWRITE   : 1'b0;

// assign HADDR2    = grant2 ? HADDR    : 32'd0;
// assign HWDATA2   = grant2 ? HWDATA   : 32'd0;
// assign HSIZE2    = grant2 ? HSIZE    : 3'd0;
// assign HTRANS2   = grant2 ? HTRANS   : 2'd0;
// assign HPROT2    = grant2 ? HPROT    : 4'd0;
// assign HWRITE2   = grant2 ? HWRITE   : 1'b0;

// // Demux for read data and response signals based on the grant
// assign HRDATA    = grant1 ? HRDATA1  : HRDATA2;
// assign HRESP     = grant1 ? HRESP1   : HRESP2;
// assign HREADY    = grant1 ? HREADY1  : HREADY2;

// // AHB ready signal is the combined readiness of both buses
// //assign ahb_ready = (grant1 && HREADY1) || (grant2 && HREADY2);
// //assign ahb_ready = (HREADY1) || (HREADY2);
// assign ahb_ready = HREADY;

// endmodule

// //=======================================================
// //  Signals / Variables declarations
// //=======================================================

// // SCR1 AHB master interface signals (instruction and data buses)
// logic [31:0] ahb_haddr;
// logic [31:0] ahb_hwdata;
// logic [2:0]  ahb_hsize;
// logic [1:0]  ahb_htrans;
// logic [3:0]  ahb_hprot;
// logic        ahb_hwrite;
// logic [31:0] ahb_hrdata;
// logic        ahb_hresp;
// logic        ahb_hready;

// // AHB-to-Avalon bridge 1 (for Bus 1)
// logic [31:0] ahb_haddr1;
// logic [31:0] ahb_hwdata1;
// logic [2:0]  ahb_hsize1;
// logic [1:0]  ahb_htrans1;
// logic [3:0]  ahb_hprot1;
// logic        ahb_hwrite1;
// logic [31:0] ahb_hrdata1;
// logic        ahb_hresp1;
// logic        ahb_hready1;

// // AHB-to-Avalon bridge 2 (for Bus 2)
// logic [31:0] ahb_haddr2;
// logic [31:0] ahb_hwdata2;
// logic [2:0]  ahb_hsize2;
// logic [1:0]  ahb_htrans2;
// logic [3:0]  ahb_hprot2;
// logic        ahb_hwrite2;
// logic [31:0] ahb_hrdata2;
// logic        ahb_hresp2;
// logic        ahb_hready2;

// //==========================================================
// // AHB Arbiter for splitting AHB into two buses
// //==========================================================
// ahb_splitter i_ahb_splitter_IMEM (
//     .clk          (cpu_clk),        // Clock from the SCR1 core
//     .rst_n        (soc_rst_n),      // Reset signal

//     // SCR1 AHB Master interface
//     .HADDR        (ahb_haddr),      // AHB address
//     .HWDATA       (ahb_hwdata),     // AHB write data
//     .HSIZE        (ahb_hsize),      // AHB size
//     .HTRANS       (ahb_htrans),     // AHB transfer type
//     .HPROT        (ahb_hprot),      // AHB protection control
//     .HWRITE       (ahb_hwrite),     // AHB write enable
//     .HRDATA       (ahb_hrdata),     // AHB read data
//     .HRESP        (ahb_hresp),      // AHB response
//     .HREADY       (ahb_hready),     // AHB ready

//     // AHB bus 1 (connected to AHB-to-Avalon bridge 1)
//     .HADDR1       (ahb_haddr1),
//     .HWDATA1      (ahb_hwdata1),
//     .HSIZE1       (ahb_hsize1),
//     .HTRANS1      (ahb_htrans1),
//     .HPROT1       (ahb_hprot1),
//     .HWRITE1      (ahb_hwrite1),
//     .HRDATA1      (ahb_hrdata1),
//     .HRESP1       (ahb_hresp1),
//     .HREADY1      (ahb_hready1),

//     // AHB bus 2 (connected to AHB-to-Avalon bridge 2)
//     .HADDR2       (ahb_haddr2),
//     .HWDATA2      (ahb_hwdata2),
//     .HSIZE2       (ahb_hsize2),
//     .HTRANS2      (ahb_htrans2),
//     .HPROT2       (ahb_hprot2),
//     .HWRITE2      (ahb_hwrite2),
//     .HRDATA2      (ahb_hrdata2),
//     .HRESP2       (ahb_hresp2),
//     .HREADY2      (ahb_hready2)
// );