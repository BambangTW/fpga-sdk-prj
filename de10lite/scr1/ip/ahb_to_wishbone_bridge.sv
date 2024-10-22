// =============================================================================
// Module:      ahb_to_wishbone_bridge
// Description: Bridges AHB-Lite Slave interface to Wishbone Master interface,
//              handling byte enables and other advanced features.
// =============================================================================

module ahb_to_wishbone_bridge (
    // Clock and Reset
    input  wire         clk,
    input  wire         reset_n,

    // AHB-Lite Slave Interface
    input  wire [31:0]  HADDR,
    input  wire [31:0]  HWDATA,
    input  wire         HWRITE,
    input  wire [2:0]   HSIZE,
    input  wire [1:0]   HTRANS,
    input  wire         HSEL,
    output reg  [31:0]  HRDATA,
    output reg          HREADY,
    output reg          HRESP,

    // Wishbone Master Interface
    output reg  [31:0]  wb_adr_o,
    output reg  [31:0]  wb_dat_o,
    output reg  [3:0]   wb_sel_o,
    output reg          wb_we_o,
    output reg          wb_cyc_o,
    output reg          wb_stb_o,
    input  wire [31:0]  wb_dat_i,
    input  wire         wb_ack_i,
    input  wire         wb_err_i
);

    // AHB Transfer Types
    localparam HTRANS_IDLE   = 2'b00;
    localparam HTRANS_BUSY   = 2'b01;
    localparam HTRANS_NONSEQ = 2'b10;
    localparam HTRANS_SEQ    = 2'b11;

    // State Encoding
    typedef enum logic [1:0] {
        IDLE,
        WRITE,
        READ
    } state_t;

    state_t state, next_state;

    // Internal Registers
    reg [31:0] haddr_reg;
    reg [31:0] hwdata_reg;
    reg [2:0]  hsize_reg;
    reg        hwrite_reg;

    // Byte Enable Calculation Function
    function [3:0] get_byte_enable(input [2:0] size, input [1:0] addr);
        case (size)
            3'b000: // Byte (8-bit)
                case (addr)
                    2'b00: get_byte_enable = 4'b0001;
                    2'b01: get_byte_enable = 4'b0010;
                    2'b10: get_byte_enable = 4'b0100;
                    2'b11: get_byte_enable = 4'b1000;
                    default: get_byte_enable = 4'b0000;
                endcase
            3'b001: // Halfword (16-bit)
                case (addr[1])
                    1'b0: get_byte_enable = 4'b0011;
                    1'b1: get_byte_enable = 4'b1100;
                    default: get_byte_enable = 4'b0000;
                endcase
            3'b010: // Word (32-bit)
                get_byte_enable = 4'b1111;
            default:
                get_byte_enable = 4'b0000; // Unsupported size
        endcase
    endfunction

    // Sequential Logic for State Machine and Registers
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state       <= IDLE;
            haddr_reg   <= 32'h0;
            hwdata_reg  <= 32'h0;
            hsize_reg   <= 3'b000;
            hwrite_reg  <= 1'b0;
        end else begin
            state       <= next_state;
            if ((HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ) && HSEL) begin
                haddr_reg  <= HADDR;
                hwdata_reg <= HWDATA;
                hsize_reg  <= HSIZE;
                hwrite_reg <= HWRITE;
            end
        end
    end

    // Combinational Logic for Next State and Output Signals
    always_comb begin
        next_state  = state;
        HREADY      = 1'b1;
        HRESP       = 1'b0; // Assume OKAY response by default
        wb_cyc_o    = 1'b0;
        wb_stb_o    = 1'b0;
        wb_we_o     = 1'b0;
        wb_adr_o    = 32'h0;
        wb_dat_o    = 32'h0;
        wb_sel_o    = 4'b0000;
        HRDATA      = 32'h0;

        case (state)
            IDLE: begin
                if ((HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ) && HSEL) begin
                    wb_cyc_o   = 1'b1;
                    wb_stb_o   = 1'b1;
                    wb_adr_o   = HADDR;
                    wb_sel_o   = get_byte_enable(HSIZE, HADDR[1:0]);
                    if (HWRITE) begin
                        wb_we_o    = 1'b1;
                        wb_dat_o   = HWDATA;
                        next_state = WRITE;
                        HREADY     = 1'b0; // Indicate wait state
                    end else begin
                        wb_we_o    = 1'b0;
                        next_state = READ;
                        HREADY     = 1'b0; // Indicate wait state
                    end
                end
            end

            WRITE: begin
                wb_cyc_o   = 1'b1;
                wb_stb_o   = 1'b1;
                wb_we_o    = 1'b1;
                wb_adr_o   = haddr_reg;
                wb_dat_o   = hwdata_reg;
                wb_sel_o   = get_byte_enable(hsize_reg, haddr_reg[1:0]);
                if (wb_ack_i || wb_err_i) begin
                    HREADY     = 1'b1;
                    HRESP      = wb_err_i; // If error, set HRESP
                    next_state = IDLE;
                end else begin
                    HREADY     = 1'b0; // Wait for ack
                end
            end

            READ: begin
                wb_cyc_o   = 1'b1;
                wb_stb_o   = 1'b1;
                wb_we_o    = 1'b0;
                wb_adr_o   = haddr_reg;
                wb_sel_o   = get_byte_enable(hsize_reg, haddr_reg[1:0]);
                if (wb_ack_i || wb_err_i) begin
                    HRDATA     = wb_dat_i;
                    HREADY     = 1'b1;
                    HRESP      = wb_err_i; // If error, set HRESP
                    next_state = IDLE;
                end else begin
                    HREADY     = 1'b0; // Wait for ack
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
