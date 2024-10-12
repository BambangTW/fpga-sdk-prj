// Copyright (c) 2024 NeuroEdge


//File name		:	wb_interconnect.v
//Designer		: 	Bambang T. W.
//Date			: 	10 Oct 2024
//Description	: 	WISHBONE INTERCONNECT
//Revision		:	1.0

module wishbone_interconnect (
    input  wire        clk_i,
    input  wire        rst_i,
    // Master 0 Interface (IMEM)
    input  wire [31:0] m0_adr_i,
    input  wire [31:0] m0_dat_i,
    output reg  [31:0] m0_dat_o,
    input  wire        m0_we_i,
    input  wire        m0_stb_i,
    input  wire        m0_cyc_i,
    output reg         m0_ack_o,
    // Master 1 Interface (DMEM)
    input  wire [31:0] m1_adr_i,
    input  wire [31:0] m1_dat_i,
    output reg  [31:0] m1_dat_o,
    input  wire        m1_we_i,
    input  wire        m1_stb_i,
    input  wire        m1_cyc_i,
    output reg         m1_ack_o,
    // Slave 0 Interface
    output reg  [31:0] s0_adr_o,
    output reg  [31:0] s0_dat_o,
    input  wire [31:0] s0_dat_i,
    output reg         s0_we_o,
    output reg         s0_stb_o,
    output reg         s0_cyc_o,
    input  wire        s0_ack_i,
    // Slave 1 Interface
    output reg  [31:0] s1_adr_o,
    output reg  [31:0] s1_dat_o,
    input  wire [31:0] s1_dat_i,
    output reg         s1_we_o,
    output reg         s1_stb_o,
    output reg         s1_cyc_o,
    input  wire        s1_ack_i
);

    // Arbitration between masters
    reg current_master; // 0: Master 0 (IMEM), 1: Master 1 (DMEM)

    // Simple Round-Robin Arbiter
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            current_master <= 0;
        end else begin
            if (current_master == 0 && m0_cyc_i && m0_stb_i) begin
                // Master 0 is active
                current_master <= 0;
            end else if (current_master == 1 && m1_cyc_i && m1_stb_i) begin
                // Master 1 is active
                current_master <= 1;
            end else if (m0_cyc_i && m0_stb_i) begin
                current_master <= 0;
            end else if (m1_cyc_i && m1_stb_i) begin
                current_master <= 1;
            end
        end
    end

    // Address decoding for Slave 0 and Slave 1 (GPIO)
    wire sel_s0_m0 = (m0_adr_i[31:16] == 16'hFFFF);
    wire sel_s1_m0 = (m0_adr_i[31:28] == 4'h1);
    // wire sel_s1_m0 = (m0_adr_i[31:0] == 32'hFF020000);

    wire sel_s0_m1 = (m1_adr_i[31:16] == 16'hFFFF);
    wire sel_s1_m1 = (m1_adr_i[31:16] == 16'hFF02);

    // Connect master to slave based on arbitration and address decoding
    always @(*) begin
        // Default outputs
        s0_adr_o = 32'd0;
        s0_dat_o = 32'd0;
        s0_we_o  = 1'b0;
        s0_stb_o = 1'b0;
        s0_cyc_o = 1'b0;

        s1_adr_o = 32'd0;
        s1_dat_o = 32'd0;
        s1_we_o  = 1'b0;
        s1_stb_o = 1'b0;
        s1_cyc_o = 1'b0;

        m0_dat_o = 32'd0;
        m0_ack_o = 1'b0;

        m1_dat_o = 32'd0;
        m1_ack_o = 1'b0;

        if (current_master == 0) begin
            if (sel_s0_m0) begin
                s0_adr_o = m0_adr_i;
                s0_dat_o = m0_dat_i;
                s0_we_o  = m0_we_i;
                s0_stb_o = m0_stb_i;
                s0_cyc_o = m0_cyc_i;

                m0_dat_o = s0_dat_i;
                m0_ack_o = s0_ack_i;
            end else if (sel_s1_m0) begin
                s1_adr_o = m0_adr_i;
                s1_dat_o = m0_dat_i;
                s1_we_o  = m0_we_i;
                s1_stb_o = m0_stb_i;
                s1_cyc_o = m0_cyc_i;

                m0_dat_o = s1_dat_i;
                m0_ack_o = s1_ack_i;
            end
        end else if (current_master == 1) begin
            if (sel_s0_m1) begin
                s0_adr_o = m1_adr_i;
                s0_dat_o = m1_dat_i;
                s0_we_o  = m1_we_i;
                s0_stb_o = m1_stb_i;
                s0_cyc_o = m1_cyc_i;

                m1_dat_o = s0_dat_i;
                m1_ack_o = s0_ack_i;
            end else if (sel_s1_m1) begin
                s1_adr_o = m1_adr_i;
                s1_dat_o = m1_dat_i;
                s1_we_o  = m1_we_i;
                s1_stb_o = m1_stb_i;
                s1_cyc_o = m1_cyc_i;

                m1_dat_o = s1_dat_i;
                m1_ack_o = s1_ack_i;
            end
        end
    end

endmodule
