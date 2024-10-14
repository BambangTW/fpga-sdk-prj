module wishbone_bram_64
    #(
        parameter ADDR_WIDTH = 13,  // Address width for RAM
        parameter BRAM_DATA_WIDTH = 64,  // RAM data width
        parameter WB_DATA_WIDTH = 32   // Wishbone data width
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
        output reg wb_ack
    );

    // FSM states for width adapter
    reg [1:0] state;
    localparam IDLE = 2'b00,
               WRITE = 2'b01,
               READ = 2'b10;

    // Buffers for temporary storage of lower/upper halves
    reg [WB_DATA_WIDTH - 1:0] lower_half, upper_half;
    reg addr_offset;  // Offset bit to track lower/upper half

    // Instantiate bootloader_ram_64
    wire [63:0] ram_q;
    reg [63:0] ram_data;  // Data to write to the RAM
    wire ram_wren = wb_we;  // Use wb_we as the write enable

    bootloader_ram_64 ram_inst (
        .address(wb_addr[ADDR_WIDTH-1:1]),  // Use the higher bits for addressing
        .clock(clk),
        .data(ram_data),
        .wren(ram_wren),
        .q(ram_q)
    );

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
                                state <= WRITE;
                                ram_data[31:0] <= wb_din;  // Write lower 32 bits
                            end else begin
                                state <= WRITE;
                                ram_data[63:32] <= wb_din;  // Write upper 32 bits
                            end
                        end

                        // Handle reads
                        else begin
                            state <= READ;
                            if (addr_offset == 0) begin
                                wb_dout <= ram_q[31:0];  // Read lower 32 bits
                            end else begin
                                wb_dout <= ram_q[63:32];  // Read upper 32 bits
                            end
                        end
                    end
                end

                // Write operation to the RAM
                WRITE: begin
                    wb_ack <= 1;
                    state <= IDLE;
                end

                // Read operation from RAM
                READ: begin
                    wb_ack <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
