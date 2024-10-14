module wb_arb(
    input        clk,
    input        rstn,
    input  [1:0] req,  // Request inputs for Master 1 and Master 0
    output [1:0] gnt   // Grant outputs for Master 1 and Master 0
);

    // Round-Robin Arbitration Logic
    typedef enum logic [1:0] {
        MASTER_0 = 2'd0,
        MASTER_1 = 2'd1
    } master_sel_t;

    master_sel_t current_grant;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            current_grant <= MASTER_0;
        end else begin
            case (current_grant)
                MASTER_0: begin
                    if (req[1]) begin
                        current_grant <= MASTER_1;
                    end else if (req[0]) begin
                        current_grant <= MASTER_0;
                    end
                end
                MASTER_1: begin
                    if (req[0]) begin
                        current_grant <= MASTER_0;
                    end else if (req[1]) begin
                        current_grant <= MASTER_1;
                    end
                end
                default: current_grant <= MASTER_0;
            endcase
        end
    end

    // Grant signals
    assign gnt = (current_grant == MASTER_0) ? 2'd1 : 2'd2;

endmodule
