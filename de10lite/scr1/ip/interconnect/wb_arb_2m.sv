module wb_arb_2m (
    input  logic       clk,
    input  logic       rstn,
    input  logic [1:0] req,   // Request inputs from two masters
    output logic       gnt    // Grant output (1-bit since we have two masters)
);

    // Parameters for state encoding
    parameter [0:0]
        grant0 = 1'b0,
        grant1 = 1'b1;

    // State registers
    logic state, next_state;

    // Assign grant output
    assign gnt = state;

    // State transition logic
    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            state <= grant0;
        else
            state <= next_state;
    end

    // Next state logic implementing simple round-robin arbitration
    always @(*) begin
        next_state = state; // Default: stay in current state
        case (state)
            grant0: begin
                if (!req[0]) begin
                    if (req[1])
                        next_state = grant1;
                end
            end
            grant1: begin
                if (!req[1]) begin
                    if (req[0])
                        next_state = grant0;
                end
            end
        endcase
    end

endmodule
