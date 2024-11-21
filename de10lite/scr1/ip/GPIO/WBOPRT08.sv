module WBOPRT08 (
    // WISHBONE SLAVE interface
    output logic        ACK_O,
    input  logic        CLK_I,
    input  logic [7:0]  DAT_I,
    output logic [7:0]  DAT_O,
    input  logic        RST_I,
    input  logic        STB_I,
    input  logic        WE_I,
    // Output port (non-WISHBONE signals)
    output logic [7:0]  PRT_O
);

    // Internal signal
    logic [7:0] Q;

    // Sequential logic
    always_ff @(posedge CLK_I or posedge RST_I) begin
        if (RST_I) begin
            Q <= 8'b00000000;
        end else if (STB_I && WE_I) begin
            Q <= DAT_I;
        end
    end

    // Combinational assignments
    assign ACK_O = STB_I;
    assign DAT_O = Q;
    assign PRT_O = Q;

endmodule
