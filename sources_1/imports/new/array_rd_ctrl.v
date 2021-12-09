`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.10.2021 16:08:34
// Design Name: 
// Module Name: array_rd_ctrl
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


module array_rd_ctrl #(
    parameter DATA_WIDTH    = 64,
    parameter RADDR_WIDTH   = 14,
    parameter CADDR_WIDTH   = 6,
    parameter FRAME_WIDTH   = DATA_WIDTH + RADDR_WIDTH + CADDR_WIDTH + 3
)(
    //global signal ports
    input                                   clk                 ,
    input                                   rstn                ,
                
    //mc config             
    input       [7:0]                       mc_tras_cfg                ,
    input       [7:0]                       mc_trp_cfg                 ,
    input       [7:0]                       mc_trcd_cfg                ,
    input       [7:0]                       mc_trtp_cfg                ,

    //fsm ctrl interface
    input       [FRAME_WIDTH - 1:0]         axi_rframe_data     ,
    input                                   axi_rframe_valid    ,
    output                                  axi_rframe_ready    ,
    output                                  read_finish         ,

    //array interface
    output reg                              array_banksel_n     ,
    output reg     [RADDR_WIDTH - 1:0]      array_raddr_rd      ,
    output reg                              array_cas_rd        ,
    output reg     [CADDR_WIDTH - 1:0]      array_caddr_rd      ,
    input                                   array_rdata_rdy     ,      
    input          [DATA_WIDTH - 1:0]       array_rdata         ,

    //array data back
    output                                  array_rd_valid      ,
    output         [DATA_WIDTH - 1:0]       array_rd_data         
);


    //fsm design
    localparam IDLE             = 3'd0;
    localparam SRADDR           = 3'd1;
    localparam RCD              = 3'd2;
    localparam READ_DATA_SEND   = 3'd3;
    localparam RLAST            = 3'd4;
    localparam RTP              = 3'd5;
    localparam PRE_RP           = 3'd6;
    localparam RP               = 3'd7;

    reg [2:0]       curr_state  ;
    reg [2:0]       next_state  ;

    reg [7:0]       mc_trcd_cfg_cnt    ;
    reg [7:0]       mc_trtp_cfg_cnt    ;
    reg [7:0]       mc_trp_cfg_cnt     ;
    reg [7:0]       mc_tras_cfg_cnt    ;

    wire                        eof         ;
    wire                        sof         ;
    wire                        rw_flag     ;
    wire [RADDR_WIDTH - 1:0]    raddr       ;
    wire [CADDR_WIDTH - 1:0]    caddr       ;
    wire [DATA_WIDTH - 1:0]     data        ;

    reg             eof_flag    ;

    wire async_fifo_rd_en;
    wire async_fifo_wr_en;
    wire async_fifo_full;
    wire async_fifo_empty;
    
    reg [7:0] fsm_cnt;
    reg [7:0] ras_cnt;

    //fsm design
    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            curr_state <= IDLE;
        else
            curr_state <= next_state;
    end

    always @(*) begin
        case(curr_state)

        IDLE:begin
            if(sof && axi_rframe_valid)
                next_state = SRADDR;
            else
                next_state = IDLE;
        end 

        SRADDR:begin
            next_state = RCD;
        end

        RCD:begin
            if(fsm_cnt == 8'd0)begin
                if(eof_flag == 0)
                    next_state = READ_DATA_SEND;
                else
                    next_state = RLAST;
            end
            else
                next_state = RCD;
        end

        READ_DATA_SEND:begin
            if(eof && axi_rframe_ready)
                next_state = RLAST;
            else
                next_state = READ_DATA_SEND;
        end

        RLAST:begin
            next_state = RTP;
        end

        RTP:begin
            if(fsm_cnt == 8'd0 && ras_cnt == 8'd0)
                next_state = RP;
            else
                next_state = RTP;
        end
                   
        RP:begin
            if(fsm_cnt == 8'd0)
                next_state = IDLE;
            else
                next_state = RP;
        end            

        default: next_state = IDLE;
        endcase
    end


    // //counters ctrl
    // always @(posedge clk or negedge rstn) begin
    //     if(!rstn)
    //         mc_trcd_cfg_cnt <= 3'd0;
    //     else if(curr_state == RCD)begin
    //         if(mc_trcd_cfg_cnt == mc_trcd_cfg - 1)
    //             mc_trcd_cfg_cnt <= 3'd0;
    //         else
    //             mc_trcd_cfg_cnt <= mc_trcd_cfg_cnt + 1'b1;
    //     end
    // end

    // always @(posedge clk or negedge rstn) begin
    //     if(!rstn)
    //         mc_trtp_cfg_cnt <= 8'd0;
    //     else if(curr_state == RTP)begin
    //         if(mc_trtp_cfg_cnt == mc_trtp_cfg - 1)
    //             mc_trtp_cfg_cnt <= 8'd0;
    //         else
    //             mc_trtp_cfg_cnt <= mc_trtp_cfg_cnt + 1'b1;
    //     end
    // end

    // always @(posedge clk or negedge rstn) begin
    //     if(!rstn)
    //         mc_tras_cfg_cnt <= 8'd0;
    //     else if(curr_state == RCD || curr_state == READ_DATA_SEND || curr_state == RLAST || curr_state == RTP)
    //         mc_tras_cfg_cnt <= mc_tras_cfg_cnt + 1'b1;
    //     else
    //         mc_tras_cfg_cnt <= 8'd0;
    // end

    // always @(posedge clk or negedge rstn) begin
    //     if(!rstn)
    //         mc_trp_cfg_cnt <= 8'd0;
    //     else if(curr_state == RP)begin
    //         if(mc_trp_cfg_cnt == mc_trp_cfg - 1)
    //             mc_trp_cfg_cnt <= 8'd0;
    //         else
    //             mc_trp_cfg_cnt <=  mc_trp_cfg_cnt + 1'b1;
    //     end
    // end



    //对于固定延时的delay需要一个自减的计数器。
    //在三个计数前的状态，加一个pre状态。


    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            fsm_cnt <= 8'd0;

        else begin
            case(curr_state)
                SRADDR  : fsm_cnt <= mc_trcd_cfg - 1'b1 ;
                RLAST   : fsm_cnt <= mc_trtp_cfg - 1'b1  ;
                PRE_RP  : fsm_cnt <= mc_trp_cfg - 1'b1  ;
                default : fsm_cnt <= (fsm_cnt == 8'd0) ? fsm_cnt : fsm_cnt - 1'b1;
            endcase
        end 
    end

    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            ras_cnt <= 8'd0;
        else if(curr_state == SRADDR)
            ras_cnt <= mc_tras_cfg - 1'b1;
        else
            ras_cnt <= (ras_cnt == 8'd0) ? ras_cnt : ras_cnt - 1'b1;
    end

    // assign sof = axi_rframe_data[86];
    // assign eof = axi_rframe_data[85];
    assign {sof, eof, wr_flag, raddr, caddr, data} = axi_rframe_data;

    
    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            eof_flag <= 1'b0;
        else if(curr_state == IDLE && axi_rframe_ready && axi_rframe_valid)
            eof_flag <= eof;
    end

    //some outputs
    assign read_finish = (curr_state == RP) && (fsm_cnt == 8'd0);

    assign axi_rframe_ready = (curr_state == IDLE) || (curr_state == READ_DATA_SEND && ~array_cas_rd);   //for one data?

    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            array_banksel_n <= 1'b1;
        else if(curr_state == SRADDR)
            array_banksel_n <= 1'b0;
        else if(curr_state == RTP && fsm_cnt == 8'd0)
            array_banksel_n <= 1'b1;
    end

    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            array_cas_rd <= 1'b0;
        else if((curr_state == RCD && fsm_cnt == 8'd0) || (curr_state == READ_DATA_SEND && axi_rframe_ready && axi_rframe_valid))
            array_cas_rd <= 1'b1;
        else if(array_cas_rd)
            array_cas_rd <= 1'b0;
    end

    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            array_caddr_rd <= 6'd0;
        else if(axi_rframe_ready && axi_rframe_valid)
            array_caddr_rd <= caddr;
    end

    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            array_raddr_rd <= 8'd0;
        else if(curr_state == IDLE && axi_rframe_ready && axi_rframe_valid)
            array_raddr_rd <= raddr;
    end


    //async fifo

    assign async_fifo_rd_en = !async_fifo_empty;
    assign async_fifo_wr_en = !async_fifo_full;
    assign array_rd_valid = !async_fifo_empty;

    async_fifo #(
		.DATA_WIDTH          (64),
		.FIFO_DEPTH          (8),
		.FIFO_ALMOST_FULL    (7),
		.FIFO_ALMOST_EMPTY   (1)
    )inst_async_fifo(
		.write_clk       (array_rdata_rdy),                   
		.write_rst_n     (rstn),                     
		.write_en        (async_fifo_wr_en),         
		.write_data      (array_rdata),              
		.read_clk        (clk),                      
		.read_rst_n      (rstn),                     
		.read_en         (async_fifo_rd_en),         
		.read_data       (array_rd_data),            
		.full            (async_fifo_full),          
		.almost_full     (),                         
        .empty           (async_fifo_empty),         
		.almost_empty    ()                          
	);    
endmodule
