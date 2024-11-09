`timescale 1ns / 1ps

module bram32_wishbone_wrapper (
    // Wishbone interface signals
    input  logic          clk,           // Clock input
    input  logic          rst_n,           // Reset input
    input  logic [31:0]   wb_adr_i,      // Wishbone address input (32 bits)
    input  logic [31:0]   wb_dat_i,      // Wishbone data input for writes (32 bits)
    output logic [31:0]   wb_dat_o,      // Wishbone data output for reads (32 bits)
    input  logic          wb_we_i,       // Wishbone write enable
    input  logic          wb_stb_i,      // Wishbone strobe
    input  logic          wb_cyc_i,      // Wishbone cycle
    output logic          wb_ack_o,      // Wishbone acknowledge
    output logic          wb_err_o       // Wishbone error (not used in this version)
);

    // Parameters for BRAM configuration
    localparam ADDR_WIDTH = 14;
    localparam DATA_WIDTH = 32;

    // Internal signals
    logic [ADDR_WIDTH-1:0] bram_addr;   // BRAM address (14 bits)
    logic [DATA_WIDTH-1:0] bram_din;    // BRAM data input (32 bits)
    logic [DATA_WIDTH-1:0] bram_dout;   // BRAM data output (32 bits)
    logic                  bram_we;     // BRAM write enable

    // Instantiate the BRAM module
    bram_synch_one_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) bram_inst (
        .clk(clk),
        .reset_n(rst_n),
        .we_a(bram_we),
        .addr_a(bram_addr),
        .din_a(bram_din),
        .dout_a(bram_dout)
    );

    // Address mapping: Extract the lower 14 bits for the BRAM address
    assign bram_addr = wb_adr_i[13:0];

    // Connect the BRAM data input to the Wishbone data input
    assign bram_din = wb_dat_i;

    // Acknowledge and error handling logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o <= 0;
            wb_err_o <= 0;
        end else begin
            // Default values
            wb_ack_o <= 0;
            wb_err_o <= 0;
            bram_we <= 0;

            if (wb_cyc_i && wb_stb_i) begin
                if (wb_we_i) begin
                    // Write operation
                    bram_we <= 1;
                end else begin
                    // Read operation
                    wb_dat_o <= bram_dout;
                end
                wb_ack_o <= 1; // Acknowledge the transaction
            end else begin
                wb_ack_o <= 0;
            end
        end
    end
endmodule
