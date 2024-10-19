module wb_interconnect (
    input  logic         clk_i,
    input  logic         rst_n,

    // Master 0 Interface
    input  logic [31:0]  m0_wbd_dat_i,
    input  logic [31:0]  m0_wbd_adr_i,
    input  logic [3:0]   m0_wbd_sel_i,
    input  logic         m0_wbd_we_i,
    input  logic         m0_wbd_cyc_i,
    input  logic         m0_wbd_stb_i,
    output logic [31:0]  m0_wbd_dat_o,
    output logic         m0_wbd_ack_o,
    output logic         m0_wbd_err_o,

    // Master 1 Interface
    input  logic [31:0]  m1_wbd_dat_i,
    input  logic [31:0]  m1_wbd_adr_i,
    input  logic [3:0]   m1_wbd_sel_i,
    input  logic         m1_wbd_we_i,
    input  logic         m1_wbd_cyc_i,
    input  logic         m1_wbd_stb_i,
    output logic [31:0]  m1_wbd_dat_o,
    output logic         m1_wbd_ack_o,
    output logic         m1_wbd_err_o,

    // Slave 0 Interface
    input  logic [31:0]  s0_wbd_dat_i,
    input  logic         s0_wbd_ack_i,
    output logic [31:0]  s0_wbd_dat_o,
    output logic [31:0]  s0_wbd_adr_o,
    output logic [3:0]   s0_wbd_sel_o,
    output logic         s0_wbd_we_o,
    output logic         s0_wbd_cyc_o,
    output logic         s0_wbd_stb_o,

    // Slave 1 Interface
    input  logic [31:0]  s1_wbd_dat_i,
    input  logic         s1_wbd_ack_i,
    output logic [31:0]  s1_wbd_dat_o,
    output logic [31:0]  s1_wbd_adr_o,
    output logic [3:0]   s1_wbd_sel_o,
    output logic         s1_wbd_we_o,
    output logic         s1_wbd_cyc_o,
    output logic         s1_wbd_stb_o
);

    // Internal signals
    logic [1:0]          gnt;           // Grant signals from arbiter
    logic [1:0]          req;           // Request signals to arbiter

    // Master request signals
    wire                 m0_req = m0_wbd_cyc_i & m0_wbd_stb_i & ~m0_wbd_ack_o;
    wire                 m1_req = m1_wbd_cyc_i & m1_wbd_stb_i & ~m1_wbd_ack_o;

    assign req = {m1_req, m0_req};

    // Instantiate the arbiter
    wb_arb u_wb_arb (
        .clk  (clk_i),
        .rstn (rst_n),
        .req  (req),
        .gnt  (gnt)
    );

    // Internal master-slave signals
    logic [31:0] m_wbd_dat_i;
    logic [31:0] m_wbd_adr_i;
    logic [3:0]  m_wbd_sel_i;
    logic        m_wbd_we_i;
    logic        m_wbd_cyc_i;
    logic        m_wbd_stb_i;

    logic [31:0] m0_dat_o;
    logic        m0_ack_o;
    logic        m0_err_o;

    logic [31:0] m1_dat_o;
    logic        m1_ack_o;
    logic        m1_err_o;

    logic [31:0] m_wbd_dat_o;
    logic        m_wbd_ack_o;
    logic        m_wbd_err_o;

    // Assign outputs to masters
    assign m0_wbd_dat_o = m0_dat_o;
    assign m0_wbd_ack_o = m0_ack_o;
    assign m0_wbd_err_o = m0_err_o;

    assign m1_wbd_dat_o = m1_dat_o;
    assign m1_wbd_ack_o = m1_ack_o;
    assign m1_wbd_err_o = m1_err_o;

    // Master Multiplexing
    logic [1:0] current_master;

    always_comb begin
        // Default assignments
        m_wbd_dat_i  = 32'b0;
        m_wbd_adr_i  = 32'b0;
        m_wbd_sel_i  = 4'b0;
        m_wbd_we_i   = 1'b0;
        m_wbd_cyc_i  = 1'b0;
        m_wbd_stb_i  = 1'b0;

        m0_dat_o     = 32'b0;
        m0_ack_o     = 1'b0;
        m0_err_o     = 1'b0;
        m1_dat_o     = 32'b0;
        m1_ack_o     = 1'b0;
        m1_err_o     = 1'b0;

        current_master = 2'b00;

        case (gnt)
            2'b01: begin // Grant to Master 0
                current_master = 2'b01;
                m_wbd_dat_i = m0_wbd_dat_i;
                m_wbd_adr_i = m0_wbd_adr_i;
                m_wbd_sel_i = m0_wbd_sel_i;
                m_wbd_we_i  = m0_wbd_we_i;
                m_wbd_cyc_i = m0_wbd_cyc_i;
                m_wbd_stb_i = m0_wbd_stb_i;
            end
            2'b10: begin // Grant to Master 1
                current_master = 2'b10;
                m_wbd_dat_i = m1_wbd_dat_i;
                m_wbd_adr_i = m1_wbd_adr_i;
                m_wbd_sel_i = m1_wbd_sel_i;
                m_wbd_we_i  = m1_wbd_we_i;
                m_wbd_cyc_i = m1_wbd_cyc_i;
                m_wbd_stb_i = m1_wbd_stb_i;
            end
            default: begin
                // No grant; outputs remain at default values
            end
        endcase
    end

    // Address decoding to select the slave
    logic s0_selected;
    logic s1_selected;

    assign s0_selected = ((m_wbd_adr_i[31:26] == 6'b000000) || (m_wbd_adr_i[31:16] == 16'hFFFF));
    assign s1_selected = ((m_wbd_adr_i[31:24] == 8'hFF) && (m_wbd_adr_i[31:16] != 16'hFFFF));

    // Connect master to slaves
    assign s0_wbd_dat_o = m_wbd_dat_i;
    assign s0_wbd_adr_o = m_wbd_adr_i;
    assign s0_wbd_sel_o = m_wbd_sel_i;
    assign s0_wbd_we_o  = m_wbd_we_i;
    assign s0_wbd_cyc_o = m_wbd_cyc_i & s0_selected;
    assign s0_wbd_stb_o = m_wbd_stb_i & s0_selected;

    assign s1_wbd_dat_o = m_wbd_dat_i;
    assign s1_wbd_adr_o = m_wbd_adr_i;
    assign s1_wbd_sel_o = m_wbd_sel_i;
    assign s1_wbd_we_o  = m_wbd_we_i;
    assign s1_wbd_cyc_o = m_wbd_cyc_i & s1_selected;
    assign s1_wbd_stb_o = m_wbd_stb_i & s1_selected;

    // Slave responses back to master
    always_comb begin
        // Default assignments
        m_wbd_dat_o = 32'b0;
        m_wbd_ack_o = 1'b0;
        m_wbd_err_o = 1'b0;
        logic access_allowed = 1'b0;

        // Determine if access is allowed based on current master and address
        if (current_master == 2'b01) begin
            // Master 0: Can access only Slave 0
            access_allowed = ((m_wbd_adr_i[31:26] == 6'b000000) || (m_wbd_adr_i[31:16] == 16'hFFFF));
        end else if (current_master == 2'b10) begin
            // Master 1: Can access both Slave 0 and Slave 1
            access_allowed = ((m_wbd_adr_i[31:26] == 6'b000000) || // SDRAM
                              (m_wbd_adr_i[31:16] == 16'hFFFF) || // On-chip SRAM
                              ((m_wbd_adr_i[31:24] == 8'hFF) && (m_wbd_adr_i[31:16] != 16'hFFFF))); // Peripherals
        end else begin
            access_allowed = 1'b0;
        end

        if (access_allowed) begin
            if (s0_selected) begin
                m_wbd_dat_o = s0_wbd_dat_i;
                m_wbd_ack_o = s0_wbd_ack_i;
            end else if (s1_selected) begin
                m_wbd_dat_o = s1_wbd_dat_i;
                m_wbd_ack_o = s1_wbd_ack_i;
            end else begin
                // Address not mapped to any slave
                m_wbd_err_o = 1'b1;
                m_wbd_ack_o = 1'b1;
            end
        end else begin
            // Access not allowed
            m_wbd_err_o = 1'b1;
            m_wbd_ack_o = 1'b1;
        end

        // Return response to the current master
        if (current_master == 2'b01) begin
            m0_dat_o = m_wbd_dat_o;
            m0_ack_o = m_wbd_ack_o;
            m0_err_o = m_wbd_err_o;
        end else if (current_master == 2'b10) begin
            m1_dat_o = m_wbd_dat_o;
            m1_ack_o = m_wbd_ack_o;
            m1_err_o = m_wbd_err_o;
        end
    end

endmodule
