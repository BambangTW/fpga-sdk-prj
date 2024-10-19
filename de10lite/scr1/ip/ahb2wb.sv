module ahb2wb(
    // Wishbone Master Interface
    output reg [31:0] adr_o,
    output reg [31:0] dat_o,
    input      [31:0] dat_i,
    input             ack_i,
    output reg        cyc_o,
    output reg        we_o,
    output reg        stb_o,
    // AHB Slave Interface
    input             hclk,
    input             hresetn,
    input      [31:0] haddr,
    input      [1:0]  htrans,
    input             hwrite,
    input      [2:0]  hsize,
    input      [2:0]  hburst,
    input             hsel,
    input      [31:0] hwdata,
    output reg [31:0] hrdata,
    output reg        hready,
    output reg        hresp,
    // Clock and Reset
    input             clk_i,
    input             rst_i
);

// Internal signals
reg [31:0] addr_reg;
reg        write_reg;
reg [31:0] data_reg;
reg        access_in_progress;

// AHB to Wishbone state machine
always @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
        adr_o     <= 32'b0;
        dat_o     <= 32'b0;
        cyc_o     <= 1'b0;
        we_o      <= 1'b0;
        stb_o     <= 1'b0;
        hrdata    <= 32'b0;
        hready    <= 1'b1;
        hresp     <= 1'b0;
        addr_reg  <= 32'b0;
        write_reg <= 1'b0;
        data_reg  <= 32'b0;
        access_in_progress <= 1'b0;
    end else begin
        // AHB transaction handling
        if (hsel && hready && htrans[1]) begin
            // Start of a new AHB transfer
            addr_reg  <= haddr;
            write_reg <= hwrite;
            data_reg  <= hwdata;
            cyc_o     <= 1'b1;
            stb_o     <= 1'b1;
            we_o      <= hwrite;
            adr_o     <= haddr;
            if (hwrite) begin
                dat_o <= hwdata;
            end
            access_in_progress <= 1'b1;
            hready <= 1'b0;
        end else if (access_in_progress) begin
            // Wait for Wishbone acknowledgment
            if (ack_i) begin
                cyc_o  <= 1'b0;
                stb_o  <= 1'b0;
                we_o   <= 1'b0;
                if (!write_reg) begin
                    hrdata <= dat_i;
                end
                access_in_progress <= 1'b0;
                hready <= 1'b1;
            end
        end else begin
            hready <= 1'b1;
        end
    end
end

endmodule
