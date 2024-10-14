module wb_bootloader_ram (
    // Wishbone Slave Interface
    input  wire        wb_clk_i,
    input  wire        wb_rst_i,
    input  wire [31:0] wb_adr_i,
    input  wire [31:0] wb_dat_i,
    input  wire [3:0]  wb_sel_i,
    input  wire        wb_we_i,
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    output reg  [31:0] wb_dat_o,
    output reg         wb_ack_o,
    output wire        wb_err_o
);

    // Signals for connecting to bootloader_ram
    reg  [13:0] ram_address;
    reg  [31:0] ram_data_in;
    reg         ram_wren;
    wire [31:0] ram_data_out;

    // Instantiate the bootloader_ram module
    bootloader_ram i_bootloader_ram (
        .address (ram_address),
        .clock   (wb_clk_i),
        .data    (ram_data_in),
        .wren    (ram_wren),
        .q       (ram_data_out)
    );

    // Error signal is unused in this module
    assign wb_err_o = 1'b0;

    // Acknowledge signal generation
    always_ff @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            wb_ack_o <= 1'b0;
        end else begin
            // Generate ack on the next clock cycle after stb_i & cyc_i are asserted
            if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
                wb_ack_o <= 1'b1;
            end else begin
                wb_ack_o <= 1'b0;
            end
        end
    end

    // Address and data handling
    always_ff @(posedge wb_clk_i) begin
        if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
            ram_address <= wb_adr_i[15:2]; // Assuming word-aligned addresses
            ram_wren    <= wb_we_i;
            ram_data_in <= wb_dat_i;
        end else begin
            ram_wren <= 1'b0;
        end
    end

    // Data output
    always_ff @(posedge wb_clk_i) begin
        if (wb_cyc_i && wb_stb_i && !wb_we_i && !wb_ack_o) begin
            wb_dat_o <= ram_data_out;
        end
    end

endmodule
