module wb_gpo
   #(parameter W = 8)  // width of output port
   (
    input  logic clk_i,
    input  logic reset_n,
    // Wishbone interface
    input  logic stb_i,               // Strobe signal
    input  logic we_i,                // Write enable
    input  logic [15:0] adr_i,        // Address bus
    input  logic [31:0] dat_i,    // Data input for write operations
    output logic [31:0] dat_o,    // Data output for read operations
    output logic ack_o,               // Acknowledge signal
    // external port    
    output logic [W-1:0] gpo_o             // Output port
   );

   // declaration
   logic [W-1:0] buf_reg;
   logic wr_en;

   // body
   // output buffer register
   always_ff @(posedge clk_i or negedge reset_n)
      if (!reset_n)
         buf_reg <= 0;
      else   
         if (wr_en)
            buf_reg <= adr_i[W-1:0];

   // Wishbone write enable logic
   assign wr_en = stb_i && we_i;

   // Wishbone read interface (no read functionality in original logic)
   assign dat_o = 32'b0; // As per original design, dat_o is always zero

   // Acknowledge signal
   always_ff @(posedge clk_i or negedge reset_n)
      if (!reset_n)
         ack_o <= 1'b0;
      else
         ack_o <= stb_i; // Acknowledge transaction when strobe is active

   // External output
   assign gpo_o = buf_reg;

endmodule
