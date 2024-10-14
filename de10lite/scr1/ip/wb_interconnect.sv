module wb_interconnect (
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

    // Master signals
    logic [31:0] m_wbd_adr_i;
    logic [31:0] m_wbd_dat_i;
    logic [3:0]  m_wbd_sel_i;
    logic        m_wbd_we_i;
    logic        m_wbd_cyc_i;
    logic        m_wbd_stb_i;
    logic [31:0] m_wbd_dat_o;
    logic        m_wbd_ack_o;
    logic        m_wbd_err_o;

    // Arbitration between masters
    typedef enum logic [1:0] {
        MASTER_0,
        MASTER_1
    } master_sel_t;

    master_sel_t current_master;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            current_master <= MASTER_0;
        end else begin
            if (current_master == MASTER_0 && m0_wbd_cyc_i) begin
                current_master <= MASTER_0;
            end else if (current_master == MASTER_1 && m1_wbd_cyc_i) begin
                current_master <= MASTER_1;
            end else if (m0_wbd_cyc_i) begin
                current_master <= MASTER_0;
            end else if (m1_wbd_cyc_i) begin
                current_master <= MASTER_1;
            end else begin
                current_master <= MASTER_0;
            end
        end
    end

    // Connect selected master signals
    always_comb begin
        case (current_master)
            MASTER_0: begin
                m_wbd_adr_i = m0_wbd_adr_i;
                m_wbd_dat_i = m0_wbd_dat_i;
                m_wbd_sel_i = m0_wbd_sel_i;
                m_wbd_we_i  = m0_wbd_we_i;
                m_wbd_cyc_i = m0_wbd_cyc_i;
                m_wbd_stb_i = m0_wbd_stb_i;
            end
            MASTER_1: begin
                m_wbd_adr_i = m1_wbd_adr_i;
                m_wbd_dat_i = m1_wbd_dat_i;
                m_wbd_sel_i = m1_wbd_sel_i;
                m_wbd_we_i  = m1_wbd_we_i;
                m_wbd_cyc_i = m1_wbd_cyc_i;
                m_wbd_stb_i = m1_wbd_stb_i;
            end
            default: begin
                m_wbd_adr_i = 32'h0;
                m_wbd_dat_i = 32'h0;
                m_wbd_sel_i = 4'h0;
                m_wbd_we_i  = 1'b0;
                m_wbd_cyc_i = 1'b0;
                m_wbd_stb_i = 1'b0;
            end
        endcase
    end

    // Updated Address decoding with master restrictions
    always_comb begin
        s0_sel = 1'b0;
        s1_sel = 1'b0;

        if (m_wbd_cyc_i && m_wbd_stb_i) begin
            // Bootloader RAM accessible by both masters
            if (m_wbd_adr_i >= 32'hFFFF_0000 && m_wbd_adr_i <= 32'hFFFF_FFFF) begin
                s0_sel = 1'b1; // Bootloader RAM
            end 
            // UART accessible only by DMEM (Master 1)
            else if ((m_wbd_adr_i >= 32'hFF01_0000 && m_wbd_adr_i <= 32'hFF01_0FFF) && (current_master == MASTER_1)) begin
                s1_sel = 1'b1; // UART
            end 
            else begin
                // Default to error response (optional: handle as needed)
            end
        end
    end

    // Connect master to selected slave
    assign s0_wbd_adr_o = m_wbd_adr_i;
    assign s0_wbd_dat_o = m_wbd_dat_i;
    assign s0_wbd_sel_o = m_wbd_sel_i;
    assign s0_wbd_we_o  = m_wbd_we_i;
    assign s0_wbd_cyc_o = m_wbd_cyc_i && s0_sel;
    assign s0_wbd_stb_o = m_wbd_stb_i && s0_sel;

    assign s1_wbd_adr_o = m_wbd_adr_i;
    assign s1_wbd_dat_o = m_wbd_dat_i;
    assign s1_wbd_sel_o = m_wbd_sel_i;
    assign s1_wbd_we_o  = m_wbd_we_i;
    assign s1_wbd_cyc_o = m_wbd_cyc_i && s1_sel;
    assign s1_wbd_stb_o = m_wbd_stb_i && s1_sel;

    // Collect slave responses
    always_comb begin
        if (s0_sel) begin
            m_wbd_dat_o = s0_wbd_dat_i;
            m_wbd_ack_o = s0_wbd_ack_i;
            m_wbd_err_o = s0_wbd_err_i;
        end else if (s1_sel) begin
            m_wbd_dat_o = s1_wbd_dat_i;
            m_wbd_ack_o = s1_wbd_ack_i;
            m_wbd_err_o = s1_wbd_err_i;
        end else begin
            m_wbd_dat_o = 32'hDEAD_BEEF; // Indicate invalid access
            m_wbd_ack_o = m_wbd_cyc_i && m_wbd_stb_i;
            m_wbd_err_o = 1'b1;
        end
    end

    // Assign responses back to the appropriate master
    assign m0_wbd_dat_o = (current_master == MASTER_0) ? m_wbd_dat_o : 32'h0;
    assign m0_wbd_ack_o = (current_master == MASTER_0) ? m_wbd_ack_o : 1'b0;
    assign m0_wbd_err_o = (current_master == MASTER_0) ? m_wbd_err_o : 1'b0;

    assign m1_wbd_dat_o = (current_master == MASTER_1) ? m_wbd_dat_o : 32'h0;
    assign m1_wbd_ack_o = (current_master == MASTER_1) ? m_wbd_ack_o : 1'b0;
    assign m1_wbd_err_o = (current_master == MASTER_1) ? m_wbd_err_o : 1'b0;

endmodule
