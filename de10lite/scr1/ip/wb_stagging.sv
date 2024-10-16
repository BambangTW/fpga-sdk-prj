module wb_stagging (
    input logic        clk_i, 
    input logic        rst_n,
    // WishBone Input master I/P
    input   logic [31:0] m_wbd_dat_i,
    input   logic [31:0] m_wbd_adr_i,
    input   logic [3:0]  m_wbd_sel_i,
    input   logic        m_wbd_we_i,
    input   logic        m_wbd_cyc_i,
    input   logic        m_wbd_stb_i,
    input   logic [3:0]  m_wbd_tid_i,
    output  logic [31:0] m_wbd_dat_o,
    output  logic        m_wbd_ack_o,
    output  logic        m_wbd_err_o,

    // Slave Interface
    input   logic [31:0] s_wbd_dat_i,
    input   logic        s_wbd_ack_i,
    input   logic        s_wbd_err_i,
    output  logic [31:0] s_wbd_dat_o,
    output  logic [31:0] s_wbd_adr_o,
    output  logic [3:0]  s_wbd_sel_o,
    output  logic        s_wbd_we_o,
    output  logic        s_wbd_cyc_o,
    output  logic        s_wbd_stb_o,
    output  logic [3:0]  s_wbd_tid_o
);

logic        holding_busy;
logic [31:0] m_wbd_dat_i_ff;
logic [31:0] m_wbd_adr_i_ff;
logic [3:0]  m_wbd_sel_i_ff;
logic        m_wbd_we_i_ff;
logic        m_wbd_cyc_i_ff;
logic        m_wbd_stb_i_ff;
logic [3:0]  m_wbd_tid_i_ff;
logic [31:0] s_wbd_dat_i_ff;
logic        s_wbd_ack_i_ff;
logic        s_wbd_err_i_ff;

assign s_wbd_dat_o = m_wbd_dat_i_ff;
assign s_wbd_adr_o = m_wbd_adr_i_ff;
assign s_wbd_sel_o = m_wbd_sel_i_ff;
assign s_wbd_we_o  = m_wbd_we_i_ff;
assign s_wbd_cyc_o = m_wbd_cyc_i_ff;
assign s_wbd_stb_o = m_wbd_stb_i_ff;
assign s_wbd_tid_o = m_wbd_tid_i_ff;

assign m_wbd_dat_o = s_wbd_dat_i_ff;
assign m_wbd_ack_o = s_wbd_ack_i_ff;
assign m_wbd_err_o = s_wbd_err_i_ff;

always @(negedge rst_n or posedge clk_i) begin
    if (!rst_n) begin
        holding_busy   <= 1'b0;
        m_wbd_dat_i_ff <= 'h0;
        m_wbd_adr_i_ff <= 'h0;
        m_wbd_sel_i_ff <= 'h0;
        m_wbd_we_i_ff  <= 'h0;
        m_wbd_cyc_i_ff <= 'h0;
        m_wbd_stb_i_ff <= 'h0;
        m_wbd_tid_i_ff <= 'h0;
        s_wbd_dat_i_ff <= 'h0;
        s_wbd_ack_i_ff <= 'h0;
        s_wbd_err_i_ff <= 'h0;
    end else begin
        s_wbd_dat_i_ff <= s_wbd_dat_i;
        s_wbd_ack_i_ff <= s_wbd_ack_i;
        s_wbd_err_i_ff <= s_wbd_err_i;
        if (m_wbd_stb_i && !holding_busy && !m_wbd_ack_o) begin
            holding_busy   <= 1'b1;
            m_wbd_dat_i_ff <= m_wbd_dat_i;
            m_wbd_adr_i_ff <= m_wbd_adr_i;
            m_wbd_sel_i_ff <= m_wbd_sel_i;
            m_wbd_we_i_ff  <= m_wbd_we_i;
            m_wbd_cyc_i_ff <= m_wbd_cyc_i;
            m_wbd_stb_i_ff <= m_wbd_stb_i;
            m_wbd_tid_i_ff <= m_wbd_tid_i;
        end else if (holding_busy && s_wbd_ack_i) begin
            holding_busy   <= 1'b0;
            m_wbd_dat_i_ff <= 'h0;
            m_wbd_adr_i_ff <= 'h0;
            m_wbd_sel_i_ff <= 'h0;
            m_wbd_we_i_ff  <= 'h0;
            m_wbd_cyc_i_ff <= 'h0;
            m_wbd_stb_i_ff <= 'h0;
            m_wbd_tid_i_ff <= 'h0;
        end
    end
end

endmodule
