module ahb_wishbone_bridge (
    // Wishbone master side
    input   logic           clk,
    input   logic           reset_n,
    output  logic [31:0]    adr_o,         // Wishbone address output
    output  logic           we_o,          // Wishbone write enable
    output  logic           cyc_o,         // Wishbone cycle valid
    output  logic           stb_o,         // Wishbone strobe signal
    output  logic [ 3:0]    byteenable,    // Byte-enable
    output  logic [31:0]    dat_o,         // Wishbone write data
    input   logic           ack_i,         // Wishbone acknowledge
    input   logic [31:0]    dat_i,         // Wishbone read data

    // AHB slave side
    output  logic [31:0]    HRDATA,
    output  logic           HRESP,
    input   logic [ 2:0]    HSIZE,
    input   logic [ 1:0]    HTRANS,
    input   logic [31:0]    HADDR,
    input   logic [31:0]    HWDATA,
    input   logic           HWRITE,
    output  logic           HREADY
);

typedef enum logic [1:0] {
    IDLE,
    WRITE,
    READ,
    WAIT_ACK
} state_type;

state_type    state;
state_type    next_state;
logic [31:0]  haddr_reg;

// State machine for AHB to Wishbone transaction
always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n)
        state <= IDLE;
    else
        state <= next_state;
end

// Address latch logic for AHB address phase
always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        haddr_reg <= 32'h0;
    end
    else if ((HTRANS == 2'b10) || (HTRANS == 2'b11)) begin
        haddr_reg <= HADDR;
    end
end

// Byte-enable logic based on AHB size and address
always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        byteenable <= 4'b1111;
    end
    else if ((HTRANS == 2'b10) || (HTRANS == 2'b11)) begin
        case ({HADDR[1:0], HSIZE})
            {2'b00, 3'b000}: byteenable <= 4'b0001;  // 8-bit transfer
            {2'b01, 3'b000}: byteenable <= 4'b0010;
            {2'b10, 3'b000}: byteenable <= 4'b0100;
            {2'b11, 3'b000}: byteenable <= 4'b1000;
            {2'b00, 3'b001}: byteenable <= 4'b0011;  // 16-bit transfer
            {2'b10, 3'b001}: byteenable <= 4'b1100;
            {2'b00, 3'b010}: byteenable <= 4'b1111;  // 32-bit transfer
            default:        byteenable <= 4'b0000;
        endcase
    end
end

// Assigning Wishbone write data and AHB read data
assign dat_o     = HWDATA;
assign HRDATA    = dat_i;   // Data read from Wishbone to AHB
assign adr_o     = haddr_reg;
assign HRESP     = ack_i ? 2'b00 : 2'b10;  // OKAY or ERROR response

// State machine logic to control Wishbone handshaking and transaction flow
always_comb begin
    next_state   = state;
    HREADY       = 1'b1;
    cyc_o        = 1'b0;
    stb_o        = 1'b0;
    we_o         = 1'b0;

    case (state)
        IDLE: begin
            if ((HTRANS == 2'b10) || (HTRANS == 2'b11)) begin
                cyc_o  = 1'b1;
                stb_o  = 1'b1;
                if (HWRITE) begin
                    we_o = 1'b1;
                    next_state = WRITE;
                end else begin
                    next_state = READ;
                end
            end
        end

        WRITE: begin
            cyc_o  = 1'b1;
            stb_o  = 1'b1;
            we_o   = 1'b1;
            if (ack_i) begin
                next_state = IDLE;
            end else begin
                next_state = WAIT_ACK;
            end
        end

        READ: begin
            cyc_o  = 1'b1;
            stb_o  = 1'b1;
            if (ack_i) begin
                next_state = IDLE;
            end else begin
                next_state = WAIT_ACK;
            end
        end

        WAIT_ACK: begin
            cyc_o  = 1'b1;
            stb_o  = 1'b1;
            if (ack_i) begin
                next_state = IDLE;
            end
        end
    endcase
end

endmodule
