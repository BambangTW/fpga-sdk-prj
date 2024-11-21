//==============================================================================
// Project      : Wishbone Arbiter Design
// File Name    : wb_arb_2m.sv
// Author       : Bambang T. Wibowo
// Date         : 2024-11-18
// Description  : 2 Master - 2 Slave Wishbone Interconnect with Arbitration
//==============================================================================
// Revision History
//------------------------------------------------------------------------------
// Version  | Author      | Date       | Changes
//----------|-------------|------------|----------------------------------------
// 1.0      | Bambang T.W.| 2024-11-18 | Initial creation
//==============================================================================

module wb_arb_2m (
    input       clk,
    input       rstn,
    input [1:0] req,    // Request input from 2 masters
    output      gnt     // Grant output (1 bit for 2 masters)
);

///////////////////////////////////////////////////////////////////
// Parameters
///////////////////////////////////////////////////////////////////

parameter grant0 = 1'b0;
parameter grant1 = 1'b1;

///////////////////////////////////////////////////////////////////
// Local Registers and Wires
///////////////////////////////////////////////////////////////////

reg state, next_state;

///////////////////////////////////////////////////////////////////
// Assign Grant
///////////////////////////////////////////////////////////////////

assign gnt = state;

always @(posedge clk or negedge rstn)
    if (!rstn)
        state <= grant0;
    else
        state <= next_state;

///////////////////////////////////////////////////////////////////
// Next State Logic
// Implements round-robin arbitration algorithm
///////////////////////////////////////////////////////////////////

always @(*) begin
    next_state = state; // Default keep current state
    case (state)
        grant0:
            if (!req[0]) begin
                if (req[1])
                    next_state = grant1;
            end
        grant1:
            if (!req[1]) begin
                if (req[0])
                    next_state = grant0;
            end
    endcase
end

endmodule
