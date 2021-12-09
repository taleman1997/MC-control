`timescale 1ns / 1ps
//--------------------------------------------------------------------------------
// Engineer: Li Jianing
// Create Date: 2021/07/13 
// Design Name: Asynchronized fifo design
// Module Name: dualport_ram_async.v
// Description: 
// 
// Dependencies: 
// 
// Revision: 
//          Revision 0.01 - File Created
// Additional Comments:
// 
//--------------------------------------------------------------------------------

module dualport_ram_async #(
        //--------parameter define----------------//
		parameter	DATA_WIDTH = 8,
		parameter	ADDR_WIDTH = 4  //ram depth is equal to 2^(ADDR_WIDTH)
		)(
        //----------ports define------------------//
		input                       write_clk,
		input                       write_rst_n,
		input                       write_en,
		input  [ADDR_WIDTH-1:0]     write_addr,
		input  [DATA_WIDTH-1:0]     write_data,
		input                       read_clk,
		input                       read_rst_n,
		input                       read_en,
		input  [ADDR_WIDTH-1:0]     read_addr,
		output [DATA_WIDTH-1:0]     read_data
    );

    //----------localparam define-----------------//
    //left shift 1 with 4(ADDR_WIDTH) bits = 2^(ADDR_WIDTH)
    localparam RAM_DEPTH = 1 << ADDR_WIDTH; 

    //----------ram define------------------------//
    reg [DATA_WIDTH - 1 : 0] mem [RAM_DEPTH - 1 : 0];

    //----------loop variable define--------------//
    integer II;

    //------sequential logic for data write-------//
    always @(posedge write_clk or negedge write_rst_n) begin
        if (!write_rst_n) begin
            for (II = 0; II < RAM_DEPTH; II = II + 1) begin
                mem[II] <= {DATA_WIDTH{1'b0}};
            end
        end
        else if(write_en)
            mem[write_addr] <= write_data;
    end
    //------combinaional logic for data write-----//
    assign read_data = mem[read_addr];

endmodule
