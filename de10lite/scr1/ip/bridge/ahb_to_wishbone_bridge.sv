`timescale 1ns / 1ps

module ahb_to_wishbone_bridge (
    // AHB Slave Interface
    input  logic         HCLK,
    input  logic         HRESETn,
    input  logic [31:0]  HADDR,
    input  logic [1:0]   HTRANS,
    input  logic         HWRITE,
    input  logic [2:0]   HSIZE,
    input  logic [2:0]   HBURST,
    input  logic [31:0]  HWDATA,
    input  logic         HSEL,
    input  logic         HREADY,
    output logic [31:0]  HRDATA,
    output logic         HREADYOUT,
    output logic         HRESP,

    // Wishbone Master Interface
    output logic         WB_CLK_O,
    output logic         WB_RST_O,
    output logic [31:0]  WB_ADR_O,
    output logic [31:0]  WB_DAT_O,
    output logic [3:0]   WB_SEL_O,
    output logic         WB_WE_O,
    output logic         WB_CYC_O,
    output logic         WB_STB_O,
    input  logic [31:0]  WB_DAT_I,
    input  logic         WB_ACK_I,
    input  logic         WB_ERR_I
);

    // Internal signals
    typedef enum logic [1:0] {
        IDLE,
        DATA_PHASE
    } state_t;

    state_t state, next_state;

    logic [31:0] addr_reg;
    logic        write_reg;
    logic [31:0] wdata_reg;
    logic [2:0]  size_reg;
    logic [3:0]  sel_reg;

    // Assign Wishbone clock and reset
    assign WB_CLK_O = HCLK;
    assign WB_RST_O = ~HRESETn;

    // Byte enable generation based on HSIZE and HADDR
    function logic [3:0] generate_sel(input logic [2:0] size, input logic [1:0] addr);
        case (size)
            3'b000: begin // Byte
                case (addr[1:0])
                    2'b00: generate_sel = 4'b0001;
                    2'b01: generate_sel = 4'b0010;
                    2'b10: generate_sel = 4'b0100;
                    2'b11: generate_sel = 4'b1000;
                endcase
            end
            3'b001: begin // Halfword
                if (addr[1])
                    generate_sel = 4'b1100;
                else
                    generate_sel = 4'b0011;
            end
            3'b010: generate_sel = 4'b1111; // Word
            default: generate_sel = 4'b1111; // Default to word
        endcase
    endfunction

    // State Machine
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state      <= IDLE;
            HREADYOUT  <= 1'b1;
            HRESP      <= 1'b0;
            WB_CYC_O   <= 1'b0;
            WB_STB_O   <= 1'b0;
            WB_WE_O    <= 1'b0;
            HRDATA     <= 32'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    HREADYOUT <= 1'b1;
                    if (HSEL && HTRANS[1] && HREADY) begin
                        // Latch address and control signals
                        addr_reg  <= HADDR;
                        write_reg <= HWRITE;
                        size_reg  <= HSIZE;
                        sel_reg   <= generate_sel(HSIZE, HADDR[1:0]);
                        if (HWRITE) begin
                            wdata_reg <= HWDATA;
                        end
                        // Initiate Wishbone transaction
                        WB_CYC_O <= 1'b1;
                        WB_STB_O <= 1'b1;
                        WB_WE_O  <= HWRITE;
                        WB_ADR_O <= HADDR;
                        WB_DAT_O <= HWDATA;
                        WB_SEL_O <= generate_sel(HSIZE, HADDR[1:0]);
                        next_state <= DATA_PHASE;
                        HREADYOUT <= 1'b0; // Wait state
                    end else begin
                        next_state <= IDLE;
                    end
                end

                DATA_PHASE: begin
                    if (WB_ACK_I) begin
                        WB_CYC_O <= 1'b0;
                        WB_STB_O <= 1'b0;
                        if (write_reg) begin
                            // Write operation complete
                            HRESP     <= 1'b0; // OKAY
                            HREADYOUT <= 1'b1;
                        end else begin
                            // Read operation complete
                            HRDATA    <= WB_DAT_I;
                            HRESP     <= 1'b0; // OKAY
                            HREADYOUT <= 1'b1;
                        end
                        next_state <= IDLE;
                    end else if (WB_ERR_I) begin
                        WB_CYC_O <= 1'b0;
                        WB_STB_O <= 1'b0;
                        HRESP     <= 1'b1; // ERROR
                        HREADYOUT <= 1'b1;
                        next_state <= IDLE;
                    end else begin
                        // Wait state
                        HREADYOUT <= 1'b0;
                        next_state <= DATA_PHASE;
                    end
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule
