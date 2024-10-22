
// =============================================================================
// Module:      wishbone_to_avalon_bridge
// Description: Bridges Wishbone Slave interface to Avalon Master interface,
//              handling byte enables and other advanced features.
// =============================================================================

module wishbone_to_avalon_bridge (
    // Clock and Reset
    input  wire         clk,
    input  wire         reset_n,

    // Wishbone Slave Interface
    input  wire [31:0]  wb_adr_i,
    input  wire [31:0]  wb_dat_i,
    input  wire [3:0]   wb_sel_i,
    input  wire         wb_we_i,
    input  wire         wb_cyc_i,
    input  wire         wb_stb_i,
    output reg  [31:0]  wb_dat_o,
    output reg          wb_ack_o,
    output reg          wb_err_o,

    // Avalon Master Interface
    output reg  [31:0]  av_address,
    output reg          av_write,
    output reg          av_read,
    output reg  [31:0]  av_writedata,
    output reg  [3:0]   av_byteenable,
    input  wire [31:0]  av_readdata,
    input  wire         av_waitrequest,
    input  wire         av_readdatavalid,
    input  wire  [1:0]  av_response // Assuming 2-bit response: 00 for OKAY
);

    // State Encoding
    typedef enum logic [1:0] {
        IDLE,
        WRITE,
        READ,
        READ_STALL
    } state_t;

    state_t state, next_state;

    // Internal Registers
    reg [31:0] wb_adr_reg;
    reg [31:0] wb_dat_reg;
    reg [3:0]  wb_sel_reg;
    reg        wb_we_reg;

    // Sequential Logic for State Machine and Registers
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state        <= IDLE;
            wb_adr_reg   <= 32'h0;
            wb_dat_reg   <= 32'h0;
            wb_sel_reg   <= 4'b0000;
            wb_we_reg    <= 1'b0;
            wb_ack_o     <= 1'b0;
            wb_err_o     <= 1'b0;
            wb_dat_o     <= 32'h0;
        end else begin
            state        <= next_state;
            wb_ack_o     <= 1'b0; // Default to deasserted
            wb_err_o     <= 1'b0; // Default to no error
            if (wb_cyc_i && wb_stb_i && (state == IDLE)) begin
                wb_adr_reg  <= wb_adr_i;
                wb_dat_reg  <= wb_dat_i;
                wb_sel_reg  <= wb_sel_i;
                wb_we_reg   <= wb_we_i;
            end
        end
    end

    // Combinational Logic for Next State and Output Signals
    always_comb begin
        next_state      = state;
        // av_address      = 32'h0;
        // av_write        = 1'b0;
        // av_read         = 1'b0;
        // av_writedata    = 32'h0;
        // av_byteenable   = 4'b0000;
        // // wb_dat_o        = 32'h0;

        case (state)
            IDLE: begin
                if (wb_cyc_i && wb_stb_i) begin
                    av_address    = wb_adr_i;
                    av_byteenable = wb_sel_i;
                    if (wb_we_i) begin
                        av_write     = 1'b1;
                        av_writedata = wb_dat_i;
                        next_state   = WRITE;
                    end else begin
                        av_read    = 1'b1;
                        next_state = READ;
                    end
                end
            end

            WRITE: begin
                av_address    = wb_adr_reg;
                av_byteenable = wb_sel_reg;
                av_write      = 1'b1;
                av_writedata  = wb_dat_reg;
                if (!av_waitrequest) begin
                    wb_ack_o    = 1'b1;
                    wb_err_o    = (av_response != 2'b00);
                    next_state  = IDLE;
                end else begin
                    next_state = WRITE; // Remain in WRITE state
                end
            end

            READ: begin
                av_address    = wb_adr_reg;
                av_byteenable = wb_sel_reg;
                av_read       = 1'b1;
                if (!av_waitrequest) begin
                    if (av_readdatavalid) begin
                        wb_dat_o    = av_readdata;
                        wb_ack_o    = 1'b1;
                        wb_err_o    = (av_response != 2'b00);
                        next_state  = IDLE;
                    end else begin
                        next_state = READ_STALL;
                    end
                end else begin
                    next_state = READ; // Remain in READ state
                end
            end

            READ_STALL: begin
                if (av_readdatavalid) begin
                    wb_dat_o    = av_readdata;
                    wb_ack_o    = 1'b1;
                    wb_err_o    = (av_response != 2'b00);
                    next_state  = IDLE;
                end else begin
                    next_state = READ_STALL; // Remain in READ_STALL state
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule