module wishbone_bootloader_wrapper #(
    parameter BIG_ENDIAN = 0  // 0: Little-endian, 1: Big-endian
)(
    input logic clk_i,
    input logic rstn_i,
    input logic [31:0] adr_i,
    input logic [31:0] dat_i,
    output logic [31:0] dat_o,
    input logic we_i,
    input logic stb_i,
    input logic cyc_i,
    input logic [3:0] sel_i,
    output logic ack_o,
    output logic err_o
);

    // Internal signals
    logic [12:0] mem_addr;
    logic [63:0] mem_data_in;
    logic mem_wren;
    logic [63:0] mem_data_out;

    // Wide-to-Narrow and Narrow-to-Wide control signals
    logic [31:0] data_buffer;
    logic [1:0] state;
    logic [1:0] transaction_count;

    // Instantiate the bootloader RAM module
    bootloader u_bootloader (
        .address(mem_addr),
        .clock(clk_i),
        .data(mem_data_in),
        .wren(mem_wren),
        .q(mem_data_out)
    );

    // State encoding
    localparam IDLE        = 2'b00;
    localparam WAIT_HIGH   = 2'b01;
    localparam OUTPUT_LOW  = 2'b10;
    localparam OUTPUT_HIGH = 2'b11;

    // Memory address logic: translate 32-bit Wishbone address to 13-bit
    always_comb begin
        mem_addr = adr_i[14:2];  // Use adr_i bits [14:2] for addressing (ignores LSBs)
    end

    // State Machine
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            state <= IDLE;
            mem_wren <= 1'b0;
            ack_o <= 1'b0;
            err_o <= 1'b0;
            dat_o <= 32'b0;
            transaction_count <= 2'b00;
        end else begin
            // Reset acknowledge and error signals at the start of each cycle
            ack_o <= 1'b0;
            err_o <= 1'b0;
            mem_wren <= 1'b0;

            case (state)
                IDLE: begin
                    if (cyc_i && stb_i) begin
                        if (we_i) begin
                            // Write operation (collect 32-bit chunks)
                            if (transaction_count == 2'b00) begin
                                data_buffer <= dat_i;
                                transaction_count <= 2'b01;
                                state <= WAIT_HIGH;
                            end
                        end else begin
                            // Read operation (request a 64-bit read from bootloader)
                            state <= OUTPUT_LOW;
                        end
                    end
                end

                WAIT_HIGH: begin
                    if (cyc_i && stb_i && (transaction_count == 2'b01)) begin
                        // Combine two 32-bit chunks into one 64-bit value based on endianness
                        if (BIG_ENDIAN) begin
                            mem_data_in <= {dat_i, data_buffer}; // Big-endian: low word first
                        end else begin
                            mem_data_in <= {data_buffer, dat_i}; // Little-endian: high word first
                        end
                        mem_wren <= 1'b1;
                        ack_o <= 1'b1;  // Acknowledge the second part of the write
                        state <= IDLE;
                        transaction_count <= 2'b00;
                    end
                end

                OUTPUT_LOW: begin
                    // Output the first 32-bit segment of the 64-bit data based on endianness
                    if (BIG_ENDIAN) begin
                        dat_o <= mem_data_out[63:32];
                    end else begin
                        dat_o <= mem_data_out[31:0];
                    end
                    ack_o <= 1'b1;
                    state <= OUTPUT_HIGH;
                end

                OUTPUT_HIGH: begin
                    // Output the second 32-bit segment of the 64-bit data based on endianness
                    if (BIG_ENDIAN) begin
                        dat_o <= mem_data_out[31:0];
                    end else begin
                        dat_o <= mem_data_out[63:32];
                    end
                    ack_o <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
