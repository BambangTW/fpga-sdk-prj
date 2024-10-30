module wishbone_bootloader_wrapper #(
    parameter BIG_ENDIAN = 0  // 0: Little-endian, 1: Big-endian
)(
    input wire clk_i,
    input wire rst_i,
    input wire [31:0] adr_i,
    input wire [31:0] dat_i,
    output reg [31:0] dat_o,
    input wire we_i,
    input wire stb_i,
    input wire cyc_i,
    input wire [3:0] sel_i,
    output reg ack_o,
    output reg err_o
);

    // Internal signals
    reg [12:0] mem_addr;
    reg [63:0] mem_data_in;
    reg mem_wren;
    wire [63:0] mem_data_out;

    // Wide-to-Narrow and Narrow-to-Wide control signals
    reg [31:0] data_buffer;
    reg [1:0] state;
    reg [1:0] transaction_count;

    // Instantiate the bootloader RAM module
    bootloader u_bootloader (
        .address(mem_addr),
        .clock(clk_i),
        .data(mem_data_in),
        .wren(mem_wren),
        .q(mem_data_out)
    );

    // State encoding
    localparam IDLE = 2'b00;
    localparam WAIT_HIGH = 2'b01;
    localparam OUTPUT_LOW = 2'b10;
    localparam OUTPUT_HIGH = 2'b11;

    // Memory address logic: translate 32-bit Wishbone address to 13-bit
    always @(*) begin
        mem_addr = adr_i[14:2];  // Use adr_i bits [14:2] for addressing (ignores LSBs)
    end

    // Function for endian conversion (32-bit to 64-bit and vice versa)
    function [63:0] assemble_64_bit(input [31:0] high_word, input [31:0] low_word);
        begin
            if (BIG_ENDIAN) begin
                assemble_64_bit = {low_word, high_word}; // Big-endian: low word first
            end else begin
                assemble_64_bit = {high_word, low_word}; // Little-endian: high word first
            end
        end
    endfunction

    function [31:0] select_32_bit(input [63:0] data_in, input bit select_high);
        begin
            if (BIG_ENDIAN) begin
                // In big-endian, lower address stores higher bytes, so flip the logic
                select_32_bit = select_high ? data_in[31:0] : data_in[63:32];
            end else begin
                // In little-endian, lower address stores lower bytes, as expected
                select_32_bit = select_high ? data_in[63:32] : data_in[31:0];
            end
        end
    endfunction

    // State Machine
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            state <= IDLE;
            mem_wren <= 0;
            ack_o <= 0;
            err_o <= 0;
            dat_o <= 32'b0;
            transaction_count <= 2'b00;
        end else begin
            // Reset acknowledge and error signals at the start of each cycle
            ack_o <= 0;
            err_o <= 0;
            mem_wren <= 0;

            case (state)
                IDLE: begin
                    if (cyc_i && stb_i) begin
                        // Check if it's a write or read operation
                        if (we_i) begin
                            // Write operation (collect 32-bit chunks)
                            if (transaction_count == 0) begin
                                // Store first 32-bit chunk
                                data_buffer <= dat_i;
                                transaction_count <= 1;
                                state <= WAIT_HIGH;
                            end
                        end else begin
                            // Read operation (request a 64-bit read from bootloader)
                            state <= OUTPUT_LOW;
                        end
                    end
                end

                WAIT_HIGH: begin
                    if (cyc_i && stb_i && transaction_count == 1) begin
                        // Combine two 32-bit chunks into one 64-bit value based on endianness
                        mem_data_in <= assemble_64_bit(dat_i, data_buffer);
                        mem_wren <= 1;
                        ack_o <= 1;  // Acknowledge the second part of the write
                        state <= IDLE;
                        transaction_count <= 0;
                    end
                end

                OUTPUT_LOW: begin
                    // Output the first 32-bit segment of the 64-bit data based on endianness
                    dat_o <= select_32_bit(mem_data_out, 0);
                    ack_o <= 1;
                    state <= OUTPUT_HIGH;
                end

                OUTPUT_HIGH: begin
                    // Output the second 32-bit segment of the 64-bit data based on endianness
                    dat_o <= select_32_bit(mem_data_out, 1);
                    ack_o <= 1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
