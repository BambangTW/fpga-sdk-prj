module wishbone_avalon_bridge (
    // Wishbone Slave Interface
    input  wire           wb_clk_i,         // Wishbone clock
    input  wire           wb_rst_i,         // Wishbone reset
    input  wire [31:0]    wb_adr_i,         // Wishbone address
    input  wire [31:0]    wb_dat_i,         // Wishbone write data
    output reg  [31:0]    wb_dat_o,         // Wishbone read data
    input  wire           wb_cyc_i,         // Wishbone cycle valid
    input  wire           wb_stb_i,         // Wishbone strobe
    input  wire           wb_we_i,          // Wishbone write enable
    output reg            wb_ack_o,         // Wishbone acknowledgment

    // Avalon Master Interface
    output reg  [31:0]    av_address_o,     // Avalon address
    output reg            av_write_o,       // Avalon write signal
    output reg            av_read_o,        // Avalon read signal
    output reg  [31:0]    av_writedata_o,   // Avalon write data
    output reg  [3:0]     av_byteenable_o,  // Avalon byte-enable signal
    input  wire           av_waitrequest_i, // Avalon wait request
    input  wire           av_readdatavalid_i, // Avalon read data valid
    input  wire [31:0]    av_readdata_i     // Avalon read data
);

    // Internal signals
    reg [1:0]  state, next_state; // State machine for controlling the bridge

    // State encoding
    localparam IDLE      = 2'b00,
               WRITE     = 2'b01,
               READ      = 2'b10,
               WAIT_READ = 2'b11;

    // Byte-enable logic based on Wishbone address and transaction size
    always_comb begin
        // Default byte-enable
        av_byteenable_o = 4'b1111;  // Word access: all bytes enabled

        // Handle non-word accesses
        if (wb_stb_i && !wb_we_i) begin
            case (wb_adr_i[1:0])
                2'b00: av_byteenable_o = 4'b0011; // Half-word at byte 0 and 1
                2'b10: av_byteenable_o = 4'b1100; // Half-word at byte 2 and 3
                default: av_byteenable_o = 4'b1111;
            endcase
        end else begin
            case (wb_adr_i[1:0])
                2'b00: av_byteenable_o = 4'b0001; // Byte 0 (lower 8 bits)
                2'b01: av_byteenable_o = 4'b0010; // Byte 1
                2'b10: av_byteenable_o = 4'b0100; // Byte 2
                2'b11: av_byteenable_o = 4'b1000; // Byte 3
            endcase
        end
    end

    // State transition logic
    always_ff @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            state <= IDLE;
        else
            state <= next_state;
    end

    // State machine logic
    always_comb begin
        // Default values
        wb_ack_o       = 1'b0;
        wb_dat_o       = 32'd0;           // Ensure wb_dat_o is always assigned
        av_write_o     = 1'b0;
        av_read_o      = 1'b0;
        av_address_o   = wb_adr_i;
        av_writedata_o = wb_dat_i;
        next_state     = state;

        case (state)
            IDLE: begin
                if (wb_cyc_i && wb_stb_i) begin
                    // Wishbone transaction is valid
                    if (wb_we_i) begin
                        next_state  = WRITE;
                        av_write_o  = 1'b1; // Initiate Avalon write
                    end else begin
                        next_state = READ;
                        av_read_o  = 1'b1;  // Initiate Avalon read
                    end
                end
            end

            WRITE: begin
                av_write_o = 1'b1; // Continue Avalon write
                if (!av_waitrequest_i) begin
                    wb_ack_o   = 1'b1; // Wishbone acknowledges transaction
                    next_state = IDLE; // Return to idle
                end
            end

            READ: begin
                av_read_o = 1'b1; // Continue Avalon read
                if (!av_waitrequest_i) begin
                    next_state = WAIT_READ; // Wait for read data to become valid
                end
            end

            WAIT_READ: begin
                if (av_readdatavalid_i) begin
                    wb_dat_o   = av_readdata_i; // Assign Avalon read data to Wishbone
                    wb_ack_o   = 1'b1;          // Wishbone acknowledges transaction
                    next_state = IDLE;          // Return to idle
                end else begin
                    // Ensure wb_dat_o is assigned even if av_readdatavalid_i is low
                    wb_dat_o = 32'd0;
                end
            end

            default: begin
                // Assign default values in case of undefined state
                next_state = IDLE;
            end
        endcase
    end

endmodule
