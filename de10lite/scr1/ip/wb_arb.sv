module wb_arb(
    input  logic        clk,
    input  logic        rstn,
    input  logic [1:0]  req,  // Request signals from masters
    output logic [1:0]  gnt   // Grant signals to masters
);

    // Internal registers
    logic [1:0] state;
    logic [1:0] next_state;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn)
            state <= 2'b01; // Start with Master 0
        else
            state <= next_state;
    end

    always_comb begin
        case (state)
            2'b01: begin // Master 0 has the grant
                if (req[0])
                    next_state = 2'b01; // Stay with Master 0
                else if (req[1])
                    next_state = 2'b10; // Grant to Master 1
                else
                    next_state = 2'b01; // Default to Master 0
            end
            2'b10: begin // Master 1 has the grant
                if (req[1])
                    next_state = 2'b10; // Stay with Master 1
                else if (req[0])
                    next_state = 2'b01; // Grant to Master 0
                else
                    next_state = 2'b10; // Default to Master 1
            end
            default: next_state = 2'b01; // Default to Master 0
        endcase
    end

    assign gnt = next_state;

endmodule
