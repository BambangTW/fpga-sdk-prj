module wishbone_bram_wrapper
    #(parameter WB_ADDR_WIDTH = 14,  // Wishbone address width (14-bit for 64 KB)
      parameter WB_DATA_WIDTH = 32,  // Wishbone data width (32-bit)
      parameter BRAM_ADDR_WIDTH = 13,  // BRAM address width (13 bits for 64-bit words)
      parameter BRAM_DATA_WIDTH = 64   // BRAM data width (64-bit)
    )
    (
        // Wishbone Interface
        input  logic                     clk_i,        // Wishbone clock input
        input  logic                     rst_i,        // Wishbone reset input (active high)
        input  logic                     cyc_i,        // Wishbone cycle valid input
        input  logic                     stb_i,        // Wishbone strobe input
        input  logic                     we_i,         // Wishbone write enable input
        input  logic [WB_ADDR_WIDTH-1:0] adr_i,        // Wishbone address input (14 bits)
        input  logic [WB_DATA_WIDTH-1:0] dat_i,        // Wishbone data input (32-bit to be written)
        output logic [WB_DATA_WIDTH-1:0] dat_o,        // Wishbone data output (32-bit read data)
        input  logic [WB_DATA_WIDTH/8-1:0] sel_i,      // Wishbone byte select input (4 bits for 32-bit bus)
        output logic                     ack_o,        // Wishbone acknowledge output
        output logic                     err_o,        // Wishbone error output

        // BRAM Interface (internal signals to the BRAM module)
        output logic                     we_a,         // Write enable for BRAM
        output logic [BRAM_ADDR_WIDTH-1:0] addr_a,     // Address to BRAM (13 bits)
        output logic [BRAM_DATA_WIDTH-1:0] din_a,      // Data input to BRAM (64-bit)
        input  logic [BRAM_DATA_WIDTH-1:0] dout_a      // Data output from BRAM (64-bit)
    );

    // Internal signals
    logic [BRAM_DATA_WIDTH-1:0] bram_data_in, bram_data_out;  // 64-bit BRAM data
    logic [1:0] word_select;                                  // Select high or low 32 bits
    logic stb_reg;

    // Address translation: Since the Wishbone address is in 32-bit words and BRAM is 64-bit,
    // we need to divide the address by 2 and use the LSB to select high/low 32-bit word
    assign addr_a = adr_i[WB_ADDR_WIDTH-1:1];  // Use upper bits of Wishbone address for BRAM
    assign word_select = adr_i[0];             // LSB selects high or low 32 bits of BRAM word

    // Write enable logic: Determine which 32-bit word and which byte lanes to write
    always_ff @(posedge clk_i) begin
        if (cyc_i && stb_i && we_i) begin
            if (word_select == 0) begin
                // Writing to the lower 32 bits of the 64-bit BRAM word
                if (sel_i[0]) bram_data_in[7:0]   <= dat_i[7:0];
                if (sel_i[1]) bram_data_in[15:8]  <= dat_i[15:8];
                if (sel_i[2]) bram_data_in[23:16] <= dat_i[23:16];
                if (sel_i[3]) bram_data_in[31:24] <= dat_i[31:24];
            end else begin
                // Writing to the upper 32 bits of the 64-bit BRAM word
                if (sel_i[0]) bram_data_in[39:32] <= dat_i[7:0];
                if (sel_i[1]) bram_data_in[47:40] <= dat_i[15:8];
                if (sel_i[2]) bram_data_in[55:48] <= dat_i[23:16];
                if (sel_i[3]) bram_data_in[63:56] <= dat_i[31:24];
            end
            we_a <= 1'b1;  // Enable writing to BRAM
        end else begin
            we_a <= 1'b0;  // Disable writing to BRAM
        end
    end

    // Read logic: Select high or low 32 bits of the 64-bit BRAM data
    always_ff @(posedge clk_i) begin
        if (cyc_i && stb_i && !we_i) begin
            if (word_select == 0) begin
                dat_o <= dout_a[31:0];  // Read lower 32 bits
            end else begin
                dat_o <= dout_a[63:32]; // Read upper 32 bits
            end
        end
    end

    // Acknowledge signal logic
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            ack_o <= 1'b0;
            stb_reg <= 1'b0;
        end else begin
            if (cyc_i && stb_i && !ack_o) begin
                stb_reg <= 1'b1;        // Capture strobe signal when transaction starts
            end

            if (stb_reg && !ack_o) begin
                ack_o <= 1'b1;          // Acknowledge the transaction
            end else begin
                ack_o <= 1'b0;          // Reset acknowledge signal after transaction
                stb_reg <= 1'b0;        // Clear strobe register after transaction
            end
        end
    end

    // No error handling in this simple implementation
    assign err_o = 1'b0;

endmodule
