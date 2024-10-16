module wb_interconnect2 (
    input  logic            clk_i,
    input  logic            rst_n,

    // Master 0 Interface (I-MEM)
    input  logic [31:0]     m0_wbd_dat_i,
    input  logic [31:0]     m0_wbd_adr_i,
    input  logic [3:0]      m0_wbd_sel_i,
    input  logic            m0_wbd_we_i,
    input  logic            m0_wbd_cyc_i,
    input  logic            m0_wbd_stb_i,
    output logic [31:0]     m0_wbd_dat_o,
    output logic            m0_wbd_ack_o,
    output logic            m0_wbd_err_o,

    // Master 1 Interface (D-MEM)
    input  logic [31:0]     m1_wbd_dat_i,
    input  logic [31:0]     m1_wbd_adr_i,
    input  logic [3:0]      m1_wbd_sel_i,
    input  logic            m1_wbd_we_i,
    input  logic            m1_wbd_cyc_i,
    input  logic            m1_wbd_stb_i,
    output logic [31:0]     m1_wbd_dat_o,
    output logic            m1_wbd_ack_o,
    output logic            m1_wbd_err_o,

    // Slave 0 Interface (Bootloader RAM)
    output logic [31:0]     s0_wbd_adr_o,
    output logic [31:0]     s0_wbd_dat_o,
    output logic [3:0]      s0_wbd_sel_o,
    output logic            s0_wbd_we_o,
    output logic            s0_wbd_cyc_o,
    output logic            s0_wbd_stb_o,
    input  logic [31:0]     s0_wbd_dat_i,
    input  logic            s0_wbd_ack_i,
    input  logic            s0_wbd_err_i,

    // Slave 1 Interface (UART)
    output logic [31:0]     s1_wbd_adr_o,
    output logic [31:0]     s1_wbd_dat_o,
    output logic [3:0]      s1_wbd_sel_o,
    output logic            s1_wbd_we_o,
    output logic            s1_wbd_cyc_o,
    output logic            s1_wbd_stb_o,
    input  logic [31:0]     s1_wbd_dat_i,
    input  logic            s1_wbd_ack_i,
    input  logic            s1_wbd_err_i
);

    // Address decoding for slaves based on the specified address ranges
    // Bootloader RAM: 0xFFFF0000 - 0xFFFFFFFF (64 kB)
    // UART: 0xFF010000 - 0xFF010FFF (4 kB)

    // Slave select signals
    logic s0_sel, s1_sel;

    // Arbitration signals
    logic [1:0] gnt;

    // Arbitration module instance
    wb_arb u_wb_arb (
        .clk(clk_i),
        .rstn(rst_n),
        .req({m1_wbd_stb_i & m1_wbd_cyc_i & ~m1_wbd_ack_o,
              m0_wbd_stb_i & m0_wbd_cyc_i & ~m0_wbd_ack_o}),
        .gnt(gnt)
    );

    // Current Master Selection
    typedef enum logic [1:0] {
        MASTER_0 = 2'd0, // I-MEM
        MASTER_1 = 2'd1  // D-MEM
    } master_sel_t;

    master_sel_t current_master;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            current_master <= MASTER_0;
        end else begin
            case (gnt)
                2'd0: current_master <= MASTER_0;
                2'd1: current_master <= MASTER_1;
                default: current_master <= MASTER_0;
            endcase
        end
    end

    // Master Interface Signals
    logic [31:0] selected_wbd_dat_i;
    logic [31:0] selected_wbd_adr_i;
    logic [3:0]  selected_wbd_sel_i;
    logic        selected_wbd_we_i;
    logic        selected_wbd_cyc_i;
    logic        selected_wbd_stb_i;

    always_comb begin
        case (current_master)
            MASTER_0: begin
                selected_wbd_dat_i = m0_wbd_dat_i;
                selected_wbd_adr_i = m0_wbd_adr_i;
                selected_wbd_sel_i = m0_wbd_sel_i;
                selected_wbd_we_i  = m0_wbd_we_i;
                selected_wbd_cyc_i = m0_wbd_cyc_i;
                selected_wbd_stb_i = m0_wbd_stb_i;
            end
            MASTER_1: begin
                selected_wbd_dat_i = m1_wbd_dat_i;
                selected_wbd_adr_i = m1_wbd_adr_i;
                selected_wbd_sel_i = m1_wbd_sel_i;
                selected_wbd_we_i  = m1_wbd_we_i;
                selected_wbd_cyc_i = m1_wbd_cyc_i;
                selected_wbd_stb_i = m1_wbd_stb_i;
            end
            default: begin
                selected_wbd_dat_i = 32'h0;
                selected_wbd_adr_i = 32'h0;
                selected_wbd_sel_i = 4'h0;
                selected_wbd_we_i  = 1'b0;
                selected_wbd_cyc_i = 1'b0;
                selected_wbd_stb_i = 1'b0;
            end
        endcase
    end

    // Address decoding logic
    always_comb begin
        s0_sel = 1'b0;
        s1_sel = 1'b0;

        if (selected_wbd_cyc_i && selected_wbd_stb_i) begin
            // Bootloader RAM
            if (selected_wbd_adr_i >= 32'hFFFF_0000 && selected_wbd_adr_i <= 32'hFFFF_FFFF) begin
                s0_sel = 1'b1;
            end
            // UART (accessible only by D-MEM)
            else if ((selected_wbd_adr_i >= 32'hFF01_0000 && selected_wbd_adr_i <= 32'hFF01_0FFF) && 
                     (current_master == MASTER_1)) begin
                s1_sel = 1'b1;
            end
            else begin
                // Add more slaves here if needed
            end
        end
    end

    // Connect master to selected slave
    assign s0_wbd_adr_o = selected_wbd_adr_i;
    assign s0_wbd_dat_o = selected_wbd_dat_i;
    assign s0_wbd_sel_o = selected_wbd_sel_i;
    assign s0_wbd_we_o  = selected_wbd_we_i;
    assign s0_wbd_cyc_o = selected_wbd_cyc_i & s0_sel;
    assign s0_wbd_stb_o = selected_wbd_stb_i & s0_sel;

    assign s1_wbd_adr_o = selected_wbd_adr_i;
    assign s1_wbd_dat_o = selected_wbd_dat_i;
    assign s1_wbd_sel_o = selected_wbd_sel_i;
    assign s1_wbd_we_o  = selected_wbd_we_i;
    assign s1_wbd_cyc_o = selected_wbd_cyc_i & s1_sel;
    assign s1_wbd_stb_o = selected_wbd_stb_i & s1_sel;

    // Collect slave responses
    logic [31:0] combined_dat_o;
    logic        combined_ack_o;
    logic        combined_err_o;

    always_comb begin
        if (s0_sel) begin
            combined_dat_o = s0_wbd_dat_i;
            combined_ack_o = s0_wbd_ack_i;
            combined_err_o = s0_wbd_err_i;
        end else if (s1_sel) begin
            combined_dat_o = s1_wbd_dat_i;
            combined_ack_o = s1_wbd_ack_i;
            combined_err_o = s1_wbd_err_i;
        end else begin
            combined_dat_o = 32'hDEAD_BEEF; // Indicates invalid access
            combined_ack_o = selected_wbd_cyc_i && selected_wbd_stb_i;
            combined_err_o = 1'b1;
        end
    end

    // Assign responses back to the appropriate master
    assign m0_wbd_dat_o = (current_master == MASTER_0) ? combined_dat_o : 32'h0;
    assign m0_wbd_ack_o = (current_master == MASTER_0) ? combined_ack_o : 1'b0;
    assign m0_wbd_err_o = (current_master == MASTER_0) ? combined_err_o : 1'b0;

    assign m1_wbd_dat_o = (current_master == MASTER_1) ? combined_dat_o : 32'h0;
    assign m1_wbd_ack_o = (current_master == MASTER_1) ? combined_ack_o : 1'b0;
    assign m1_wbd_err_o = (current_master == MASTER_1) ? combined_err_o : 1'b0;

endmodule
