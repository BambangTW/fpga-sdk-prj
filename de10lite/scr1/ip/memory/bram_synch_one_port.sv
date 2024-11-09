`timescale 1ns / 1ps

module bram_synch_one_port
    #(
        parameter ADDR_WIDTH = 14,
        parameter DATA_WIDTH = 32
    )
    (
        input  logic                     clk,      // Clock input
        input  logic                     reset_n,  // Active-low reset input
        input  logic                     we_a,     // Write enable
        input  logic [ADDR_WIDTH-1:0]    addr_a,   // Address input
        input  logic [DATA_WIDTH-1:0]    din_a,    // Data input for writing
        output logic [DATA_WIDTH-1:0]    dout_a    // Data output for reading
    );
    
    // Declare memory as an array with the given width and depth
    logic [DATA_WIDTH-1:0] memory [0:2**ADDR_WIDTH-1];

    // Memory initialization (Note: Initial blocks are generally not synthesizable)
    initial begin
        $readmemh("D:/fpga_project/ALTERA/scr1-sdk/fpga/de10lite/scr1/ip/scbl_final_rearranged.mem", memory);
    end
    

    // Sequential logic for synchronous read and write operations with reset
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            dout_a <= '0;  // Reset output data to zero
        end else begin
            if (we_a) 
                memory[addr_a] <= din_a;  // Write operation
            
            dout_a <= memory[addr_a];      // Read operation
        end
    end

endmodule
