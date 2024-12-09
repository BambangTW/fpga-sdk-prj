module seven_seg (
    input  logic [3:0] hex_digit,
    output logic [6:0] segments
);

    // Define segment patterns using local parameters for clarity
    localparam logic [6:0]
        SEG_0   = 7'b100_0000, // Displays '0'
        SEG_1   = 7'b111_1001, // Displays '1'
        SEG_2   = 7'b010_0100, // Displays '2'
        SEG_3   = 7'b011_0000, // Displays '3'
        SEG_4   = 7'b001_1001, // Displays '4'
        SEG_5   = 7'b001_0010, // Displays '5'
        SEG_6   = 7'b000_0010, // Displays '6'
        SEG_7   = 7'b111_1000, // Displays '7'
        SEG_8   = 7'b000_0000, // Displays '8'
        SEG_9   = 7'b001_0000, // Displays '9'
        SEG_A   = 7'b000_1000, // Displays 'A'
        SEG_b   = 7'b000_0011, // Displays 'b'
        SEG_C   = 7'b100_0110, // Displays 'C'
        SEG_d   = 7'b010_0001, // Displays 'd'
        SEG_E   = 7'b000_0110, // Displays 'E'
        SEG_F   = 7'b000_1110, // Displays 'F'
        SEG_OFF = 7'b111_1111; // All segments off

    always_comb begin
        unique case (hex_digit)
            4'h0: segments = SEG_0;
            4'h1: segments = SEG_1;
            4'h2: segments = SEG_2;
            4'h3: segments = SEG_3;
            4'h4: segments = SEG_4;
            4'h5: segments = SEG_5;
            4'h6: segments = SEG_6;
            4'h7: segments = SEG_7;
            4'h8: segments = SEG_8;
            4'h9: segments = SEG_9;
            4'hA: segments = SEG_A;
            4'hB: segments = SEG_b;
            4'hC: segments = SEG_C;
            4'hD: segments = SEG_d;
            4'hE: segments = SEG_E;
            4'hF: segments = SEG_F;
            default: segments = SEG_OFF;
        endcase
    end

endmodule
