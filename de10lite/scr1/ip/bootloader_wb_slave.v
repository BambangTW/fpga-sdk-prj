// File: bootloader_wb_slave.v
// Description: Wishbone slave module for the bootloader memory
// Author: Your Name
// Date: [Current Date]

module bootloader_wb_slave (
    input  wire        clk_i,     // Clock input
    input  wire        rst_i,     // Reset input
    // Wishbone Slave Interface
    input  wire [31:0] wb_adr_i,  // Address from interconnect
    input  wire [31:0] wb_dat_i,  // Data input from interconnect
    output reg  [31:0] wb_dat_o,  // Data output to interconnect
    input  wire        wb_we_i,   // Write enable from interconnect
    input  wire        wb_stb_i,  // Strobe from interconnect
    input  wire        wb_cyc_i,  // Cycle valid from interconnect
    output reg         wb_ack_o,  // Acknowledge to interconnect
    // Bootloader Memory Interface
    output reg  [12:0] address_o, // Address to bootloader memory
    output reg  [63:0] data_o,    // Data to bootloader memory
    input  wire [63:0] data_i,    // Data from bootloader memory
    output reg         wren_o     // Write enable to bootloader memory
);
    // State Machine States
    localparam STATE_IDLE       = 2'd0;
    localparam STATE_WRITE_LOW  = 2'd1;
    localparam STATE_WRITE_HIGH = 2'd2;
    localparam STATE_READ       = 2'd3;

    reg [1:0] state;
    reg [31:0] latched_data;  // Holds the lower 32 bits during write
    reg [63:0] read_data;     // Holds the 64-bit data read from memory

    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            // Reset all outputs and state
            wb_dat_o     <= 32'd0;
            wb_ack_o     <= 1'b0;
            address_o    <= 13'd0;
            data_o       <= 64'd0;
            wren_o       <= 1'b0;
            state        <= STATE_IDLE;
            latched_data <= 32'd0;
            read_data    <= 64'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    wb_ack_o <= 1'b0;
                    wren_o   <= 1'b0;
                    if (wb_cyc_i && wb_stb_i) begin
                        // Calculate memory address (adjust for base address and word alignment)
                        address_o <= wb_adr_i[14:3];  // 13-bit address, ignore lower 3 bits

                        if (wb_we_i) begin
                            // Write operation
                            if (wb_adr_i[2] == 1'b0) begin
                                // Lower 32 bits
                                latched_data <= wb_dat_i;
                                state        <= STATE_WRITE_HIGH;
                            end else begin
                                // Upper 32 bits
                                data_o[31:0]  <= latched_data;
                                data_o[63:32] <= wb_dat_i;
                                wren_o        <= 1'b1;
                                wb_ack_o      <= 1'b1;
                                state         <= STATE_IDLE;
                            end
                        end else begin
                            // Read operation
                            state <= STATE_READ;
                        end
                    end
                end

                STATE_WRITE_HIGH: begin
                    if (wb_cyc_i && wb_stb_i && wb_we_i && wb_adr_i[2] == 1'b1) begin
                        // Upper 32 bits received
                        data_o[31:0]  <= latched_data;
                        data_o[63:32] <= wb_dat_i;
                        wren_o        <= 1'b1;
                        wb_ack_o      <= 1'b1;
                        state         <= STATE_IDLE;
                    end
                end

                STATE_READ: begin
                    // Read the 64-bit word from memory
                    read_data <= data_i;
                    wb_ack_o  <= 1'b1;
                    // Send the requested 32 bits
                    if (wb_adr_i[2] == 1'b0) begin
                        // Lower 32 bits
                        wb_dat_o <= data_i[31:0];
                    end else begin
                        // Upper 32 bits
                        wb_dat_o <= data_i[63:32];
                    end
                    state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end
endmodule
