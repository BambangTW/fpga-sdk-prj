module wishbone_bram_width_adapter
    #(
        parameter ADDR_WIDTH = 13,  // Address width for BRAM
        parameter BRAM_DATA_WIDTH = 64,  // BRAM data width
        parameter WB_DATA_WIDTH = 32,   // Wishbone data width
        parameter BURST_SIZE = 1  // Set to 1 if you want to optimize for full-sized transactions
    )
    (
        input clk,
        input reset,

        // Wishbone side (32-bit)
        input [ADDR_WIDTH - 1:0] wb_addr,
        input [WB_DATA_WIDTH - 1:0] wb_din,
        output reg [WB_DATA_WIDTH - 1:0] wb_dout,
        input wb_we,
        input wb_stb,
        output reg wb_ack,

        // BRAM side (64-bit)
        input [ADDR_WIDTH - 1:0] bram_addr,
        input [BRAM_DATA_WIDTH - 1:0] bram_din,
        output reg [BRAM_DATA_WIDTH - 1:0] bram_dout,
        input bram_we,
        output reg bram_en
    );

    // FSM states for width adapter
    reg [1:0] state;
    localparam IDLE = 2'b00,
               WRITE_LOWER = 2'b01,
               WRITE_UPPER = 2'b10,
               READ_LOWER = 2'b11;

    // Buffers for temporary storage of upper/lower halves
    reg [WB_DATA_WIDTH - 1:0] lower_half, upper_half;
    reg addr_offset;  // Offset bit to track lower/upper half
    reg [BRAM_DATA_WIDTH - 1:0] bram_buffer;  // Buffer to combine lower and upper Wishbone data

    // State machine to handle reading and writing
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            wb_ack <= 0;
            addr_offset <= 0;
        end else begin
            case (state)
                // Idle state, waiting for Wishbone transaction
                IDLE: begin
                    wb_ack <= 0;
                    if (wb_stb) begin
                        addr_offset <= wb_addr[0];  // Using the LSB to select lower/upper half

                        // Handle writes
                        if (wb_we) begin
                            if (addr_offset == 0) begin
                                state <= WRITE_LOWER;
                                lower_half <= wb_din;  // Capture lower 32 bits
                            end else begin
                                state <= WRITE_UPPER;
                                upper_half <= wb_din;  // Capture upper 32 bits
                            end
                        end

                        // Handle reads
                        else begin
                            state <= READ_LOWER;
                            if (addr_offset == 0) begin
                                wb_dout <= bram_dout[31:0];  // Read lower 32 bits
                            end else begin
                                wb_dout <= bram_dout[63:32];  // Read upper 32 bits
                            end
                        end
                    end
                end

                // Write lower 32 bits to the BRAM
                WRITE_LOWER: begin
                    bram_buffer[31:0] <= lower_half;  // Write lower half
                    wb_ack <= 1;
                    bram_en <= 1;
                    state <= IDLE;
                end

                // Write upper 32 bits to the BRAM
                WRITE_UPPER: begin
                    bram_buffer[63:32] <= upper_half;  // Write upper half
                    bram_en <= 1;
                    wb_ack <= 1;
                    state <= IDLE;
                end

                // Read operation from BRAM
                READ_LOWER: begin
                    wb_ack <= 1;
                    bram_en <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
