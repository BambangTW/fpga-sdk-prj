module bootloader_wb_slave2 (
    input wire clk_i,
    input wire rst_i,

    // WISHBONE Slave Interface (32-bit)
    input wire [31:0] wb_adr_i,
    input wire [31:0] wb_dat_i,
    output reg [31:0] wb_dat_o,
    input wire wb_we_i,
    input wire wb_stb_i,
    input wire wb_cyc_i,
    output reg wb_ack_o,

    // Bootloader Interface (64-bit)
    output reg [12:0] address_o,
    output reg [63:0] data_o,
    input wire [63:0] data_i,
    output reg wren_o
);

    // State machine for handling two 32-bit transactions for a single 64-bit access
    reg state;
	 localparam 	IDLE = 3'b000, 
						WRITE_LOWER = 3'b001, 
						WRITE_UPPER = 3'b010, 
						READ_LOWER = 3'b011, 
						READ_UPPER = 3'b100;
 
    reg [31:0] temp_data;  // Temporary storage for lower 32 bits of data during read
    reg read_phase;        // Used to distinguish between the two 32-bit read phases

    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            wb_ack_o <= 1'b0;
            wren_o <= 1'b0;
            state <= IDLE;
        end else if (wb_cyc_i && wb_stb_i) begin
            case (state)
                IDLE: begin
                    wb_ack_o <= 1'b0;
                    if (wb_we_i) begin
                        // Writing to bootloader (data packing for 64-bit width)
                        if (wb_adr_i[2] == 1'b0) begin
                            // Lower 32 bits
                            address_o <= wb_adr_i[14:2];
                            data_o[31:0] <= wb_dat_i;
                            wren_o <= 1'b0;
                            state <= WRITE_UPPER;  // Move to upper 32-bit write
                        end else begin
                            // Upper 32 bits
                            data_o[63:32] <= wb_dat_i;
                            wren_o <= 1'b1;  // Complete 64-bit write
                            state <= IDLE;
                            wb_ack_o <= 1'b1;
                        end
                    end else begin
                        // Reading from bootloader (data unpacking for 64-bit width)
                        if (wb_adr_i[2] == 1'b0) begin
                            // Lower 32 bits first
                            address_o <= wb_adr_i[14:2];
                            wb_dat_o <= data_i[31:0];
                            state <= READ_UPPER;  // Move to upper 32-bit read
                        end else begin
                            // Upper 32 bits
                            wb_dat_o <= data_i[63:32];
                            state <= IDLE;
                            wb_ack_o <= 1'b1;
                        end
                    end
                end
                
                WRITE_UPPER: begin
                    // Write the upper 32 bits
                    data_o[63:32] <= wb_dat_i;
                    wren_o <= 1'b1;  // Trigger the write after both 32-bit values are ready
                    state <= IDLE;
                    wb_ack_o <= 1'b1;
                end
                
                READ_UPPER: begin
                    // Read the upper 32 bits
                    wb_dat_o <= data_i[63:32];
                    state <= IDLE;
                    wb_ack_o <= 1'b1;
                end
            endcase
        end else begin
            wb_ack_o <= 1'b0;
            wren_o <= 1'b0;
        end
    end
endmodule