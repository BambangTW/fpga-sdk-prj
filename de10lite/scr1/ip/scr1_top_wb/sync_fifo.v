module sync_fifo #(
    parameter W = 8,
    parameter DP = 4,
    parameter AW = (DP == 2)   ? 1 : 
                   (DP == 4)   ? 2 :
                   (DP == 8)   ? 3 :
                   (DP == 16)  ? 4 :
                   (DP == 32)  ? 5 :
                   (DP == 64)  ? 6 :
                   (DP == 128) ? 7 :
                   (DP == 256) ? 8 : 0
)(
    input              clk,
    input              reset_n,
    input              wr_en,
    input              rd_en,
    input  [W-1 : 0]   wr_data,
    output [W-1 : 0]   rd_data,
    output             full,
    output             empty
);

    // synopsys translate_off
    initial begin
        if (AW == 0) begin
            $display ("%m : ERROR!!! Fifo depth %d not in range 2 to 256", DP);
        end
    end
    // synopsys translate_on

    // Memory array
    reg [W-1 : 0] mem [0 : DP-1];

    // Write and read pointers
    reg [AW:0] wr_ptr;
    reg [AW:0] rd_ptr;

    // Full and empty flags
    reg full_q;
    reg empty_q;

    // FIFO count
    reg [AW:0] fifo_cnt;

    // Write operation
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            wr_ptr   <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr[AW-1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // Read operation
    reg [W-1:0] rd_data_q;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            rd_ptr <= 0;
            rd_data_q <= 0;
        end else if (rd_en && !empty) begin
            rd_data_q <= mem[rd_ptr[AW-1:0]];
            rd_ptr <= rd_ptr + 1;
        end
    end
    assign rd_data = rd_data_q;

    // FIFO count logic
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            fifo_cnt <= 0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: fifo_cnt <= fifo_cnt + 1; // Write
                2'b01: fifo_cnt <= fifo_cnt - 1; // Read
                default: fifo_cnt <= fifo_cnt;    // No change
            endcase
        end
    end

    // Full and empty flag logic
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            full_q  <= 0;
            empty_q <= 1;
        end else begin
            full_q  <= (fifo_cnt == DP);
            empty_q <= (fifo_cnt == 0);
        end
    end
    assign full  = full_q;
    assign empty = empty_q;

    // Underflow and overflow checks
    // synopsys translate_off
    always @(posedge clk) begin
        if (wr_en && full) begin
            $display($time, "%m Error! FIFO overflow!");
            $stop;
        end
        if (rd_en && empty) begin
            $display($time, "%m Error! FIFO underflow!");
            $stop;
        end
    end
    // synopsys translate_on

endmodule
