`timescale 1ns / 1ps

module wb_arb(clk, rstn, req, gnt);

input       clk;
input       rstn;
input   [1:0] req;    // Req input for Master 0 and Master 1
output  [0:0] gnt;    // Grant output for two masters

///////////////////////////////////////////////////////////////////////
//
// Parameters
//

parameter   grant0 = 1'b0,
            grant1 = 1'b1;

///////////////////////////////////////////////////////////////////////
// Local Registers and Wires
///////////////////////////////////////////////////////////////////////

reg state, next_state;

///////////////////////////////////////////////////////////////////////
//  Misc Logic 
///////////////////////////////////////////////////////////////////////

assign gnt = state;

always @(posedge clk or negedge rstn)
    if (!rstn)
        state <= grant0;
    else
        state <= next_state;

///////////////////////////////////////////////////////////////////////
//
// Next State Logic 
//   - implements round robin arbitration algorithm
//   - switches grant if current req is dropped or next is asserted
//   - parks at last grant
///////////////////////////////////////////////////////////////////////

always @(state or req)
begin
    next_state = state;    // Default Keep State
    case(state)        
        grant0:
            // If Master 0's request is dropped, check Master 1
            if (!req[0]) begin
                if (req[1]) next_state = grant1;
            end
        grant1:
            // If Master 1's request is dropped, check Master 0
            if (!req[1]) begin
                if (req[0]) next_state = grant0;
            end
    endcase
end

endmodule