`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/10/26 15:06:07
// Design Name: 
// Module Name: array_wr_ctrl
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
// latest version: use the common counter to control the FSM
// 
//////////////////////////////////////////////////////////////////////////////////


module array_wr_ctrl #(
    parameter DATA_WIDTH    = 64,
    parameter RADDR_WIDTH   = 14,
    parameter CADDR_WIDTH   = 6,
    parameter FRAME_WIDTH   = DATA_WIDTH + RADDR_WIDTH + CADDR_WIDTH + 3
)(
    //clock and reset
    input                                       clk                 ,
    input                                       rstn                ,

    //configure signal      
    input           [7:0]                       mc_trcd_cfg         ,
    input           [7:0]                       mc_twr_cfg          ,
    input           [7:0]                       mc_trp_cfg          ,
    input           [7:0]                       mc_tras_cfg         ,       

    //fsm ctrl interface    
    input           [FRAME_WIDTH - 1:0]         axi_wframe_data     ,
    input                                       axi_wframe_valid    ,
    output                                      axi_wframe_ready    ,
    output                                      write_finish        ,

    //array interface   
    output reg                                  array_banksel_n     ,
    output reg     [RADDR_WIDTH - 1:0]          array_raddr_wr      ,
    output reg                                  array_cas_wr        ,
    output reg     [CADDR_WIDTH - 1:0]          array_caddr_wr      ,
    output                                      array_wdata_rdy     ,
    output reg     [DATA_WIDTH - 1:0]           array_wdata

);


    localparam IDLE             = 3'd0;
    localparam SRADDR           = 3'd1;
    localparam RCD              = 3'd2;
    localparam WDATA            = 3'd3;
    localparam WLAST            = 3'd4;
    localparam WR               = 3'd5;
    localparam PRE_RP           = 3'd6;
    localparam RP               = 3'd7;

    reg [2:0]       curr_state  ;
    reg [2:0]       next_state  ;

    reg [7:0]       mc_trcd_cfg_cnt    ;
    reg [7:0]       mc_twr_cfg_cnt     ;
    reg [7:0]       mc_trp_cfg_cnt     ;
    reg [7:0]       mc_tras_cfg_cnt    ;


    wire                        eof         ;
    wire                        sof         ;
    wire                        rw_flag     ;
    wire [RADDR_WIDTH - 1:0]    raddr       ;
    wire [CADDR_WIDTH - 1:0]    caddr       ;
    wire [DATA_WIDTH - 1:0]     data        ;

    reg                         eof_flag    ;
    reg [7:0] fsm_cnt;
    reg [7:0] ras_cnt;

    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            curr_state <= IDLE;
        else
            curr_state <= next_state;
    end

    always @(*) begin
        case(curr_state)

        IDLE:begin
            if(sof && axi_wframe_valid)
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
                    next_state = WDATA;
                else
                    next_state = WLAST;
            end
            else
                next_state = RCD;
        end
            
        WDATA:begin
            if(eof && axi_wframe_ready && axi_wframe_valid)
                next_state = WLAST;
            else
                next_state = WDATA;
        end

        WLAST:begin
            next_state = WR;
        end

        WR:begin
            if(fsm_cnt == 8'd0 && ras_cnt == 8'd0)
                next_state = PRE_RP;
            else
                next_state = WR;
        end

        PRE_RP:begin
            next_state = RP;
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


    //counters ctrl
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
    //         mc_twr_cfg_cnt <= 3'd0;
    //     else if(curr_state == WR)begin
    //         if(mc_twr_cfg_cnt == mc_twr_cfg - 1)
    //             mc_twr_cfg_cnt <= 3'd0;
    //         else
    //             mc_twr_cfg_cnt <= mc_twr_cfg_cnt + 1'b1;
    //     end
    // end

    // always @(posedge clk or negedge rstn) begin
    //     if(!rstn)
    //         mc_tras_cfg_cnt <= 8'd0;
    //     else if(curr_state == RP || curr_state == WDATA || curr_state == WLAST || curr_state == WR)
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
                WLAST   : fsm_cnt <= mc_twr_cfg - 1'b1  ;
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


    // assign sof = axi_wframe_data[86];
    // assign eof = axi_wframe_data[85];
    assign {sof, eof, rw_flag, raddr, caddr, data} = axi_wframe_data;

    
    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            eof_flag <= 1'b0;
        else if(curr_state == IDLE && axi_wframe_ready && axi_wframe_valid)
            eof_flag <= eof;
    end

    //some outputs
    assign write_finish = (curr_state == RP) && (fsm_cnt == 8'd0);

    assign axi_wframe_ready = (curr_state == IDLE) || (curr_state == WDATA && ~array_cas_wr);   //for one data?

    assign array_wdata_rdy =  ~ array_cas_wr;

    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            array_banksel_n <= 1'b1;
        else if(curr_state == SRADDR)
            array_banksel_n <= 1'b0;
        else if(curr_state == WR && fsm_cnt == 8'd0)
            array_banksel_n <= 1'b1;
    end

    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            array_cas_wr <= 1'b0;
        else if((curr_state == RCD && fsm_cnt == 8'd0) || (curr_state == WDATA && axi_wframe_ready && axi_wframe_valid))
            array_cas_wr <= 1'b1;
        else if(array_cas_wr)
            array_cas_wr <= 1'b0;
    end

    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            array_wdata <= 64'd0;
        else if(axi_wframe_ready && axi_wframe_valid)
            array_wdata <= data;
    end

    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            array_caddr_wr <= 6'd0;
        else if(axi_wframe_ready && axi_wframe_valid)
            array_caddr_wr <= caddr;
    end

    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            array_raddr_wr <= 8'd0;
        else if(curr_state == IDLE && axi_wframe_ready && axi_wframe_valid)
            array_raddr_wr <= raddr;
    end
        
endmodule
