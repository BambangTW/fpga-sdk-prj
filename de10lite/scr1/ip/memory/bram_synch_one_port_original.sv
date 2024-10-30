

`timescale 1ns / 1ps

module bram_synch_one_port #(
    parameter int ADDR_WIDTH = 13,
    parameter int DATA_WIDTH = 64
)(
    input  logic                     clk,        // Clock input
    input  logic                     we_a,       // Write enable
    input  logic [ADDR_WIDTH-1:0]    addr_a,     // Address input
    input  logic [DATA_WIDTH-1:0]    din_a,      // Data input for writing
    output logic [DATA_WIDTH-1:0]    dout_a      // Data output for reading
);

    // Declare memory as an array with the given width and depth
    logic [DATA_WIDTH-1:0] memory [0:(2**ADDR_WIDTH)-1];

    // Variables for hex file parsing
    integer file, r, i, addr;
    logic [7:0] byte_count, record_type, checksum;
    logic [15:0] address;
    logic [7:0] data_byte [0:255];  // Array to hold each line's data
    logic [DATA_WIDTH-1:0] word_data;  // Full data word (for BRAM)

    // Synchronous memory initialization using manual hex file parsing
    initial begin
        // Open the hex file
        file = $fopen("D:/fpga_project/XILINX/scr1_testbench/scr1_testbench.srcs/sources_1/imports/memory/scbl.hex", "r");
        if (file == 0) begin
            $display("Error opening file");
            $finish;
        end

        // Read the file line by line
        while (!$feof(file)) begin
            r = $fscanf(file, ":%2h%4h%2h", byte_count, address, record_type);

            // Only process if it's a data record (record_type == 8'h00)
            if (record_type == 8'h00) begin
                for (i = 0; i < byte_count; i = i + 1) begin
                    // Read the actual data bytes
                    r = $fscanf(file, "%2h", data_byte[i]);
                end

                // Read the checksum (but we don't need to use it)
                r = $fscanf(file, "%2h", checksum);

                // Load the extracted data bytes into memory
                word_data = {data_byte[0], data_byte[1], data_byte[2], data_byte[3],
                             data_byte[4], data_byte[5], data_byte[6], data_byte[7]};
                addr = address;  // Calculate word address
                memory[addr] = word_data;
            end else begin
                // Skip non-data records
                for (i = 0; i < byte_count; i = i + 1) begin
                    r = $fscanf(file, "%2h", data_byte[i]);
                end
                r = $fscanf(file, "%2h", checksum);  // Skip checksum
            end
        end

        // Close the file
        $fclose(file);
    end

    // Sequential logic for synchronous read and write operations
    always_ff @(posedge clk) begin
        if (we_a)
            memory[addr_a] <= din_a;  // Write operation

        dout_a <= memory[addr_a];  // Read operation
    end

endmodule
