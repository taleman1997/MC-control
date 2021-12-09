`timescale 1ns / 1ps
module mc_top #(
    parameter LEN_WIDTH     = 6 ,
    parameter ADDR_WIDTH    = 20,
    parameter RADDR_WIDTN   = 14,
    parameter CADDR_WIDTH   = 6 ,
    parameter DATA_WIDTH    = 64,
    parameter APB_ADDR_WIDTH= 16,
    parameter APB_DATA_WIDTH= 32
)(
    input                           clk                 ,
    input                           rstn                ,

    //axi bus   
    input                           axi_awvalid         ,
    output                          axi_awready         ,
    input   [LEN_WIDTH - 1:0]       axi_awlen           ,
    input   [ADDR_WIDTH - 1:0]      axi_awaddr          ,
    
    input                           axi_wvalid          ,
    output                          axi_wready          ,
    input                           axi_wlast           ,
    input   [DATA_WIDTH - 1:0]      axi_wdata           ,
    
    input                           axi_arvalid         ,
    output                          axi_arready         ,
    input   [LEN_WIDTH - 1:0]       axi_arlen           ,
    input   [ADDR_WIDTH - 1:0]      axi_araddr          ,
    
    output                          axi_rvalid          ,
    output                          axi_rlast           ,
    output  [DATA_WIDTH - 1:0]      axi_rdata           ,
    
    //APB BUS       
    input                           apb_pclk            ,
    input                           apb_prst_n          ,
    input                           apb_psel            ,
    input                           apb_pwrite          ,
    input                           apb_penable         ,
    input   [APB_ADDR_WIDTH - 1:0]  apb_paddr           ,
    input   [APB_DATA_WIDTH - 1:0]  apb_pwdata          ,
    output                          apb_pready          , 
    output  [APB_DATA_WIDTH - 1:0]  apb_prdata          ,

    //array interface
    output                          array_banksel_n     ,    
    output  [RADDR_WIDTN - 1:0]     array_raddr         ,
    output                          array_cas_wr        ,    
    output  [CADDR_WIDTH - 1:0]     array_caddr_wr      ,    
    output                          array_cas_rd        ,    
    output  [CADDR_WIDTH - 1:0]     array_caddr_rd      ,    
    output                          array_wdata_rdy     ,    
    output  [DATA_WIDTH - 1:0]      array_wdata         ,
    input                           array_rdata_rdy     ,    
    input   [DATA_WIDTH - 1:0]      array_rdata         
);

    localparam FRAME_WIDTH = ADDR_WIDTH + DATA_WIDTH + 3;

    wire              mc_en                ;
    wire [7:0]        mc_trc_cfg           ;
    wire [7:0]        mc_tras_cfg          ;
    wire [7:0]        mc_trp_cfg           ;
    wire [7:0]        mc_trcd_cfg         ;
    wire [7:0]        mc_twr_cfg           ;
    wire [7:0]        mc_trtp_cfg          ;
    wire [27:0]       mc_rf_start_time_cfg ;
    wire [27:0]       mc_rf_period_time_cfg;

    wire [FRAME_WIDTH -1:0] axi_frame_data ;
    wire                    axi_frame_valid;
    wire                    axi_frame_ready;

    wire [DATA_WIDTH - 1:0] array_rdata_to_axi;
    wire                    array_rvalid      ;

    reg mc_en_d1;
    reg mc_en_d2;

    //sycn mc_en 
    always @(posedge clk or negedge rstn) begin
        if(!rstn)begin
            mc_en_d1 <= 1'b0;
            mc_en_d2 <= 1'b0;
        end
        else begin
            mc_en_d1 <= mc_en;
            mc_en_d2 <= mc_en_d1;
        end
    end




mc_apb_cfg inst_mc_apb_cfg(
    .apb_pclk                   (apb_pclk               ),
    .apb_prstn                  (apb_prst_n             ),
    .apb_psel                   (apb_psel               ),
    .apb_pwrite                 (apb_pwrite             ),    
    .apb_penable                (apb_penable            ),
    .apb_addr                   (apb_paddr              ),
    .apb_pwdata                 (apb_pwdata             ),
    .apb_pready                 (apb_pready             ),    
    .apb_prdata                 (apb_prdata             ),
    .mc_en                      (mc_en                  ),
    .mc_trc_cfg                 (mc_trc_cfg             ),
    .mc_tras_cfg                (mc_tras_cfg            ),
    .mc_trp_cfg                 (mc_trp_cfg             ),
    .mc_trcd_cfg                (mc_trcd_cfg            ),
    .mc_twr_cfg                 (mc_twr_cfg             ),
    .mc_trtp_cfg                (mc_trtp_cfg            ),
    .mc_rf_start_time_cfg       (mc_rf_start_time_cfg   ),
    .mc_rf_period_time_cfg      (mc_rf_period_time_cfg  ) 
);



axi_slave#(
    .AXI_ADDR_WIDTH (ADDR_WIDTH ),
    .AXI_DATA_WIDTH (DATA_WIDTH ),
    .AXI_LEN_WIDTH  (LEN_WIDTH  )
)inst_axi_slave(

    .mc_work_en      (mc_en_d2            ),
    .rstn            (rstn                ),
    .clk             (clk                 ),

    .axi_awvalid     (axi_awvalid         ),
    .axi_awready     (axi_awready         ),
    .axi_awlen       (axi_awlen           ),
    .axi_awaddr      (axi_awaddr          ),

    .axi_wvalid      (axi_wvalid          ),
    .axi_wready      (axi_wready          ),
    .axi_wlast       (axi_wlast           ),
    .axi_wdata       (axi_wdata           ),

    .axi_arvalid     (axi_arvalid         ),
    .axi_arready     (axi_arready         ),
    .axi_arlen       (axi_arlen           ),
    .axi_araddr      (axi_araddr          ),

    .axi_rvalid      (axi_rvalid          ),
    .axi_rlast       (axi_rlast           ),
    .axi_rdata       (axi_rdata           ),

    .axi_frame_data  (axi_frame_data      ),
    .axi_frame_valid (axi_frame_valid     ),
    .axi_frame_ready (axi_frame_ready     ),

    .array_rdata     (array_rdata_to_axi  ),
    .array_rvalid    (array_rvalid        )
    
);


array_ctrl #(
    .DATA_WIDTH  (DATA_WIDTH),
    .RADDR_WIDHT (RADDR_WIDTN),
    .CADDR_WIDTH (CADDR_WIDTH)
)inst_array_ctrl(
    .clk                     (clk),
    .rstn                    (rstn),
    .mc_en                   (mc_en_d2),

    .axi_frame_data          (axi_frame_data      ),
    .axi_frame_valid         (axi_frame_valid     ),
    .axi_frame_ready         (axi_frame_ready     ),
    .array_rdata_to_axi      (array_rdata_to_axi  ),
    .array_rvalid            (array_rvalid        ),

    .array_banksel_n         (array_banksel_n     ),
    .array_raddr             (array_raddr         ),
    .array_cas_wr            (array_cas_wr        ),
    .array_caddr_wr          (array_caddr_wr      ),
    .array_cas_rd            (array_cas_rd        ),
    .array_caddr_rd          (array_caddr_rd      ),
    .array_wdata_rdy         (array_wdata_rdy     ),
    .array_wdata             (array_wdata         ),
    .array_rdata_rdy         (array_rdata_rdy     ),
    .array_rdata             (array_rdata         ),

    .mc_trc_cfg              (mc_trc_cfg            ),
    .mc_tras_cfg             (mc_tras_cfg           ),
    .mc_trp_cfg              (mc_trp_cfg            ),
    .mc_trcd_cfg             (mc_trcd_cfg           ),
    .mc_twr_cfg              (mc_twr_cfg            ),
    .mc_trtp_cfg             (mc_trtp_cfg           ),
    .mc_rf_start_time_cfg    (mc_rf_start_time_cfg  ),
    .mc_rf_period_time_cfg   (mc_rf_period_time_cfg )

);



    
endmodule