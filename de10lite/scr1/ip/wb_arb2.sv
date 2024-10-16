module wb_arb2 (
    input       clk,
    input       rstn,
    input [1:0] req,   // Two requests: Master I and Master D
    output [1:0] gnt   // Grant output
);

parameter [1:0]
    grant0 = 2'h0,
    grant1 = 2'h1;

reg [1:0] state, next_state;

assign gnt = state;

always @(posedge clk or negedge rstn)
    if (!rstn)
        state <= grant0;
    else
        state <= next_state;

always @(state or req) begin
    next_state = state;  // Default Keep State
    case (state)
        grant0:
            if (!req[0])
                next_state = req[1] ? grant1 : grant0;
        grant1:
            if (!req[1])
                next_state = req[0] ? grant0 : grant1;
    endcase
end

endmodule
