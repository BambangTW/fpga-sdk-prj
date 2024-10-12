module wishbone_slave (
    input  wire        clk,
    input  wire        rst,
    // Wishbone signals
    input  wire [31:0] adr_i,
    input  wire [31:0] dat_i,
    output reg  [31:0] dat_o,
    input  wire        we_i,
    input  wire        stb_i,
    input  wire        cyc_i,
    output reg         ack_o
);
    // Simple memory array (256 x 32-bit words)
    reg [31:0] memory [0:255];

    // Acknowledge logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ack_o <= 1'b0;
            dat_o <= 32'd0;
        end else begin
            if (stb_i && cyc_i) begin
                ack_o <= 1'b1;
                if (we_i) begin
                    // Write operation
                    memory[adr_i[9:2]] <= dat_i;
                end else begin
                    // Read operation
                    dat_o <= memory[adr_i[9:2]];
                end
            end else begin
                ack_o <= 1'b0;
            end
        end
    end

endmodule
