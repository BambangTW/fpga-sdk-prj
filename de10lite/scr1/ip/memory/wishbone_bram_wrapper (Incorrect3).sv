`timescale 1ns / 1ps

module wishbone_bram_wrapper
    #(parameter ADDR_WIDTH = 13, DATA_WIDTH = 64)
    (
        // Wishbone interface
        input  logic         clk,       // Clock input
        input  logic         rst,       // Reset input (active high)
        input  logic         wb_stb,    // Wishbone strobe
        input  logic         wb_cyc,    // Wishbone cycle
        input  logic         wb_we,     // Wishbone write enable
        input  logic [31:0]  wb_addr,   // Wishbone address
        input  logic [31:0]  wb_wdata,  // Wishbone write data
        output logic [31:0]  wb_rdata,  // Wishbone read data
        output logic         wb_ack,    // Wishbone acknowledge
        output logic         wb_err,    // Wishbone error

        // BRAM interface
        output logic [ADDR_WIDTH-1:0] bram_addr,   // BRAM address
        output logic                  bram_we,     // BRAM write enable
        output logic [DATA_WIDTH-1:0] bram_din,    // BRAM write data
        input  logic [DATA_WIDTH-1:0] bram_dout    // BRAM read data
    );

    // Internal signals
    logic [DATA_WIDTH-1:0] bram_data_reg;
    logic ack_reg;
    logic [ADDR_WIDTH-1:0] addr_reg;
    logic [31:0] wb_rdata_reg;
    
    // Extract BRAM address from Wishbone address, ignoring the lower 2 bits
    assign bram_addr = wb_addr[14:2];  // Map Wishbone address space to BRAM (13-bit address)

    // BRAM write enable logic: only assert on second Wishbone word write (when wb_addr[1] is 1)
    assign bram_we = wb_stb & wb_cyc & wb_we & (wb_addr[1] == 1);
    
    // Create BRAM data from two consecutive 32-bit Wishbone writes
    always_ff @(posedge clk) begin
        if (rst) begin
            bram_data_reg <= 64'b0;
        end else if (wb_stb & wb_cyc & wb_we) begin
            if (wb_addr[1] == 0) begin
                // Lower 32 bits
                bram_data_reg[31:0] <= wb_wdata;
            end else begin
                // Upper 32 bits
                bram_data_reg[63:32] <= wb_wdata;
            end
        end
    end

    // BRAM data input assignment
    assign bram_din = bram_data_reg;

    // Wishbone read data logic: select lower or upper 32 bits based on wb_addr[1]
    always_ff @(posedge clk) begin
        if (rst) begin
            wb_rdata_reg <= 32'b0;
        end else if (wb_stb & wb_cyc & ~wb_we) begin
            if (wb_addr[1] == 0) begin
                // Read lower 32 bits of the 64-bit BRAM word
                wb_rdata_reg <= bram_dout[31:0];
            end else begin
                // Read upper 32 bits of the 64-bit BRAM word
                wb_rdata_reg <= bram_dout[63:32];
            end
        end
    end

    // Wishbone read data output
    assign wb_rdata = wb_rdata_reg;

    // Acknowledge logic
    always_ff @(posedge clk) begin
        if (rst) begin
            ack_reg <= 0;
        end else begin
            ack_reg <= wb_stb & wb_cyc;  // Acknowledge the Wishbone transaction
        end
    end
    assign wb_ack = ack_reg;

    // Error logic (not used, but can be extended for error handling)
    assign wb_err = 0;

endmodule
