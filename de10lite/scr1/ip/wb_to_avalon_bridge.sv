module wb_to_avalon_bridge(
    input  logic        clk,
    input  logic        reset_n,
    // Wishbone Slave Interface
    input  logic [31:0] wbs_dat_i,
    input  logic [31:0] wbs_adr_i,
    input  logic [3:0]  wbs_sel_i,
    input  logic        wbs_we_i,
    input  logic        wbs_cyc_i,
    input  logic        wbs_stb_i,
    output logic [31:0] wbs_dat_o,
    output logic        wbs_ack_o,
    // Avalon Master Interface
    output logic [31:0] address,
    output logic        write,
    output logic        read,
    output logic [31:0] writedata,
    output logic [3:0]  byteenable,
    input  logic        waitrequest,
    input  logic [31:0] readdata,
    input  logic        readdatavalid,
    input  logic [1:0]  response
);

    // Internal state
    typedef enum logic [1:0] {
        IDLE,
        WAIT_WRITE,
        WAIT_READ
    } state_t;

    state_t state, next_state;

    // Internal signals
    logic pending_transaction;

    // Sequential logic for state machine
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Combinational logic for state transitions and outputs
    always_comb begin
        // Default outputs
        write        = 1'b0;
        read         = 1'b0;
        address      = 32'b0;
        writedata    = 32'b0;
        byteenable   = 4'b1111;
        wbs_dat_o    = 32'b0;
        wbs_ack_o    = 1'b0;
        next_state   = state;

        case (state)
            IDLE: begin
                if (wbs_cyc_i && wbs_stb_i) begin
                    address    = wbs_adr_i;
                    byteenable = wbs_sel_i;
                    if (wbs_we_i) begin
                        write     = 1'b1;
                        writedata = wbs_dat_i;
                        next_state = WAIT_WRITE;
                    end else begin
                        read      = 1'b1;
                        next_state = WAIT_READ;
                    end
                end
            end
            WAIT_WRITE: begin
                if (!waitrequest) begin
                    wbs_ack_o  = 1'b1;
                    next_state = IDLE;
                end else begin
                    write      = 1'b1;
                    writedata  = wbs_dat_i;
                    address    = wbs_adr_i;
                    byteenable = wbs_sel_i;
                end
            end
            WAIT_READ: begin
                if (readdatavalid) begin
                    wbs_dat_o  = readdata;
                    wbs_ack_o  = 1'b1;
                    next_state = IDLE;
                end else begin
                    read       = 1'b1;
                    address    = wbs_adr_i;
                    byteenable = wbs_sel_i;
                end
            end
        endcase
    end

endmodule
