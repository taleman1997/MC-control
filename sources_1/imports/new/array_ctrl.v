`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.11.2021 12:03:18
// Design Name: 
// Module Name: array_ctrl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module array_ctrl #(
    parameter DATA_WIDTH = 64,
    parameter RADDR_WIDHT = 14,
    parameter CADDR_WIDTH = 6,
    parameter FRAME_WIDTH = DATA_WIDTH + RADDR_WIDHT + CADDR_WIDTH + 3
)(
    input                           clk                     ,
    input                           rstn                    ,
    input                           mc_en                   ,

    input  [FRAME_WIDTH - 1:0]      axi_frame_data          ,
    input                           axi_frame_valid         ,
    output                          axi_frame_ready         ,
    output [DATA_WIDTH - 1:0]       array_rdata_to_axi      ,
    output                          array_rvalid            ,

    output reg                      array_banksel_n         ,
    output reg [RADDR_WIDHT - 1:0]  array_raddr             ,
    output                          array_cas_wr            ,
    output [CADDR_WIDTH - 1:0]      array_caddr_wr          ,
    output                          array_cas_rd            ,
    output [CADDR_WIDTH - 1:0]      array_caddr_rd          ,
    output                          array_wdata_rdy         ,
    output [DATA_WIDTH - 1:0]       array_wdata             ,
    input                           array_rdata_rdy         ,
    input  [DATA_WIDTH - 1:0]       array_rdata             ,

    input [7:0]                     mc_trc_cfg              ,
    input [7:0]                     mc_tras_cfg             ,
    input [7:0]                     mc_trp_cfg              ,
    input [7:0]                     mc_trcd_cfg             ,
    input [7:0]                     mc_twr_cfg              ,
    input [7:0]                     mc_trtp_cfg             ,
    input [27:0]                    mc_rf_start_time_cfg    ,
    input [27:0]                    mc_rf_period_time_cfg

);


//wires defines
wire                        array_banksel_n_wr;
wire                        axi_wframe_valid;
wire                        axi_wframe_ready;
wire                        write_finish;
wire [RADDR_WIDHT - 1:0]    array_raddr_wr;
wire [FRAME_WIDTH - 1:0]    axi_wframe_data;

wire                        array_banksel_n_rd;
wire                        axi_rframe_valid;
wire                        axi_rframe_ready;
wire                        read_finish;
wire [RADDR_WIDHT - 1:0]    array_raddr_rd;
wire [FRAME_WIDTH - 1:0]    axi_rframe_data;

wire                        rf_start;
wire                        rf_finish;
wire                        array_banksel_n_rf;
wire [RADDR_WIDHT - 1:0]    array_raddr_rf;

wire [1:0]                  curr_state_output;

localparam  IDLE    = 2'd0;
localparam  READ    = 2'd1;
localparam  WRITE   = 2'd2;
localparam  REFRESH = 2'd3;

//assign the output
always @(*) begin
    case(curr_state_output)
    IDLE:begin
        array_banksel_n = 1'b1;
        array_raddr = 14'd0;
    end   
    READ:begin
        array_banksel_n = array_banksel_n_rd;
        array_raddr = array_raddr_rd;
    end   
    WRITE:begin
        array_banksel_n = array_banksel_n_wr;
        array_raddr = array_raddr_wr;
    end  
    REFRESH:begin
        array_banksel_n = array_banksel_n_rf;
        array_raddr = array_raddr_rf;
    end 
    endcase
end




fsm_ctrl #(
    .FRAME_WIDTH (FRAME_WIDTH)
)inst_fsm_ctrl(
    .clk                     (clk                   ),
    .rstn                    (rstn                  ),
    .mc_en                   (mc_en                 ),
    .mc_rf_start_time_cfg    (mc_rf_start_time_cfg  ),
    .mc_rf_period_time_cfg   (mc_rf_period_time_cfg ),
    .axi_frame_data          (axi_frame_data        ),
    .axi_frame_valid         (axi_frame_valid       ),
    .axi_frame_ready         (axi_frame_ready       ),
    .axi_wframe_data         (axi_wframe_data       ),
    .axi_wframe_valid        (axi_wframe_valid      ),
    .axi_wframe_ready        (axi_wframe_ready      ),
    .write_finish_i          (write_finish          ),
    .axi_rframe_data         (axi_rframe_data       ),
    .axi_rframe_valid        (axi_rframe_valid      ),
    .axi_rframe_ready        (axi_rframe_ready      ),
    .read_finish_i           (read_finish           ),
    .refresh_finish_i        (rf_finish             ),
    .refresh_start_o         (rf_start              ),
    .curr_state_output       (curr_state_output     ) 
);



array_wr_ctrl #(
    .DATA_WIDTH    (DATA_WIDTH ),
    .RADDR_WIDTH   (RADDR_WIDHT),
    .CADDR_WIDTH   (CADDR_WIDTH),
    .FRAME_WIDTH   (FRAME_WIDTH)
)inst_array_wr_ctrl(
    .clk                 (clk               ),
    .rstn                (rstn              ),
    .mc_trcd_cfg         (mc_trcd_cfg       ),
    .mc_twr_cfg          (mc_twr_cfg        ),
    .mc_trp_cfg          (mc_trp_cfg        ),
    .mc_tras_cfg         (mc_tras_cfg       ),       
    .axi_wframe_data     (axi_wframe_data   ),
    .axi_wframe_valid    (axi_wframe_valid  ),
    .axi_wframe_ready    (axi_wframe_ready  ),
    .write_finish        (write_finish      ),
    .array_banksel_n     (array_banksel_n_wr),
    .array_raddr_wr      (array_raddr_wr    ),
    .array_cas_wr        (array_cas_wr      ),
    .array_caddr_wr      (array_caddr_wr    ),
    .array_wdata_rdy     (array_wdata_rdy   ),
    .array_wdata         (array_wdata       )   
);



array_rd_ctrl #(
    .DATA_WIDTH    (DATA_WIDTH ),
    .RADDR_WIDTH   (RADDR_WIDHT),
    .CADDR_WIDTH   (CADDR_WIDTH),
    .FRAME_WIDTH   (FRAME_WIDTH)
)inst_array_rd_ctrl(
    .clk                 (clk                   ),
    .rstn                (rstn                  ),                
    .mc_tras_cfg         (mc_tras_cfg           ),
    .mc_trp_cfg          (mc_trp_cfg            ),
    .mc_trcd_cfg         (mc_trcd_cfg           ),
    .mc_trtp_cfg         (mc_trtp_cfg           ),
    .axi_rframe_data     (axi_rframe_data       ),
    .axi_rframe_valid    (axi_rframe_valid      ),
    .axi_rframe_ready    (axi_rframe_ready      ),
    .read_finish         (read_finish           ),
    .array_banksel_n     (array_banksel_n_rd    ),
    .array_raddr_rd      (array_raddr_rd        ),
    .array_cas_rd        (array_cas_rd          ),
    .array_caddr_rd      (array_caddr_rd        ),
    .array_rdata_rdy     (array_rdata_rdy       ),      
    .array_rdata         (array_rdata           ),
    .array_rd_valid      (array_rvalid          ),
    .array_rd_data       (array_rdata_to_axi    )  
);



array_rf_ctrl #(
    .ARRAY_RADDR_WIDTH(RADDR_WIDHT),
    .ARRAY_CADDR_WIDTH(CADDR_WIDTH)
)inst_array_rf_ctrl(
    .clk                     (clk                   ),
    .rstn                    (rstn                  ),
    .mc_rf_start_time_cfg    (mc_rf_start_time_cfg  ),
    .mc_rf_period_time_cfg   (mc_rf_period_time_cfg ),
    .mc_tras_cfg             (mc_tras_cfg           ),
    .mc_trp_cfg              (mc_trp_cfg            ),
    .mc_trc_cfg              (mc_trc_cfg            ),
    .rf_start                (rf_start              ),
    .rf_finish               (rf_finish             ),
    .array_bank_sel_n        (array_banksel_n_rf    ),
    .array_raddr             (array_raddr_rf        )   
);



    
endmodule
