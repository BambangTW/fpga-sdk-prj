`timescale 1ns / 1ps

module wishbone_bram_wrapper
    #(
        parameter ADDR_WIDTH = 13,    // 13-bit BRAM address
        parameter DATA_WIDTH = 64     // 64-bit BRAM data
    )
    (
        // Wishbone Interface
        input  logic         clk,       // Clock input
        input  logic         rst_n,     // Reset input (active low)
        input  logic         wb_stb,    // Wishbone strobe
        input  logic         wb_cyc,    // Wishbone cycle
        input  logic         wb_we,     // Wishbone write enable
        input  logic [31:0]  wb_addr,   // Wishbone address
        input  logic [31:0]  wb_wdata,  // Wishbone write data
        output logic [31:0]  wb_rdata,  // Wishbone read data
        output logic         wb_ack,    // Wishbone acknowledge
        output logic         wb_err,    // Wishbone error

        // BRAM Interface
        output logic [ADDR_WIDTH-1:0] bram_addr,   // BRAM address
        output logic                  bram_we,     // BRAM write enable
        output logic [DATA_WIDTH-1:0] bram_din,    // BRAM write data
        input  logic [DATA_WIDTH-1:0] bram_dout    // BRAM read data
    );

    // Local Parameters
    localparam BASE_ADDR = 32'hFFFF0000;
    localparam OFFSET_BITS = 16; // 0xFFFF0000 to 0xFFFFFFFF is 64KB

    // Internal Signals
    logic [15:0] offset;
    logic [ADDR_WIDTH-1:0] translated_addr;
    logic half;
    logic [DATA_WIDTH-1:0] bram_data_reg;
    logic [31:0] read_data_reg;
    logic ack_reg;
    logic write_enable;

    // Address Translation
    // Calculate the offset from the base address
    always_comb begin
        if (wb_addr >= BASE_ADDR) begin
            offset = wb_addr[15:0]; // Assuming the mapping is within 0xFFFF0000 to 0xFFFFFFFF
        end else begin
            offset = 16'h0000; // Default to 0 if out of range (can be modified for error handling)
        end
    end

    // Determine BRAM address and which half to access
    assign translated_addr = offset[15:3];       // Divide by 8 to get BRAM address
    assign half          = offset[2];            // Determine lower or upper 32 bits

    // Assign BRAM address
    assign bram_addr = translated_addr;

    // Write Enable Logic
    // Assert bram_we only when a write operation is detected
    assign write_enable = wb_stb & wb_cyc & wb_we;

    assign bram_we = write_enable;

    // BRAM Data Input Logic
    // For write operations, modify the appropriate half of the BRAM data
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bram_data_reg <= {DATA_WIDTH{1'b0}};
        end else if (write_enable) begin
            // Read the current BRAM data
            bram_data_reg <= bram_dout;
            
            // Update the relevant half
            if (half == 0) begin
                // Update lower 32 bits
                bram_data_reg[31:0] <= wb_wdata;
            end else begin
                // Update upper 32 bits
                bram_data_reg[63:32] <= wb_wdata;
            end
        end
    end

    // Assign BRAM write data
    assign bram_din = bram_data_reg;

    // Read Data Logic
    // Capture the BRAM read data based on the accessed half
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_data_reg <= 32'b0;
        end else if (wb_stb & wb_cyc & ~wb_we) begin
            if (half == 0) begin
                // Read lower 32 bits
                read_data_reg <= bram_dout[31:0];
            end else begin
                // Read upper 32 bits
                read_data_reg <= bram_dout[63:32];
            end
        end
    end

    // Assign Wishbone read data
    assign wb_rdata = read_data_reg;

    // Acknowledge Logic
    // Delay the acknowledge by one cycle to ensure data integrity
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ack_reg <= 1'b0;
        end else begin
            ack_reg <= wb_stb & wb_cyc;
        end
    end

    assign wb_ack = ack_reg;

    // Error Logic
    // Currently not used; can be extended for comprehensive error handling
    assign wb_err = 1'b0;

endmodule
