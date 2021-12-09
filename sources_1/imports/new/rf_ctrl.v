`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.11.2021 21:15:08
// Design Name: 
// Module Name: rf_ctrl
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


module array_rf_ctrl #(
    parameter ARRAY_RADDR_WIDTH = 14,
    parameter ARRAY_CADDR_WIDTH = 6 
)(
    input                               clk                     ,
    input                               rstn                    ,

    input [27:0]                        mc_rf_start_time_cfg    ,
    input [27:0]                        mc_rf_period_time_cfg   ,
    input [7:0]                         mc_tras_cfg             ,
    input [7:0]                         mc_trp_cfg              ,
    input [7:0]                         mc_trc_cfg              ,

    input                               rf_start                ,
    output                              rf_finish               ,

    output                              array_bank_sel_n        ,
    output [ARRAY_RADDR_WIDTH - 1 : 0]  array_raddr
);


    localparam IDLE     = 3'd0;
    localparam SADDR    = 3'd1;
    localparam TRAS     = 3'd2;
    localparam PRE_TRP  = 3'd3;
    localparam TRP      = 3'd4;

    reg [2:0] curr_state;
    reg [2:0] next_state;

    reg [7:0] fsm_cnt;
    reg [7:0] rc_cnt;

    reg [ARRAY_RADDR_WIDTH - 1 : 0] array_r_cnt;

    //FSM design
    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            curr_state <= IDLE;
        else
            curr_state <= next_state;
    end

    always @(*) begin
        case(curr_state)
        IDLE:begin
            if(rf_start)
                next_state = SADDR;
            else    
                next_state = IDLE;
        end 

        SADDR:begin
            next_state = TRAS;
        end

        TRAS:begin
            if(fsm_cnt == 8'd0)
                next_state = PRE_TRP;
            else
                next_state = TRAS;
        end

        PRE_TRP:begin
            next_state = TRP;
        end

        TRP:begin
            if(fsm_cnt == 8'd0)begin
                if(array_r_cnt == {ARRAY_RADDR_WIDTH{1'b1}})
                    next_state = IDLE;
                else
                    next_state = SADDR;
            end
            else
                next_state = TRP;
        end       

        default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            fsm_cnt <= 8'd0;
        else begin
            case(curr_state)
            SADDR  : fsm_cnt <= mc_tras_cfg - 1'b1 ;
            PRE_TRP : fsm_cnt <= mc_trp_cfg - 1'b1 ;
            default : fsm_cnt <= (fsm_cnt == 8'd0) ? fsm_cnt : fsm_cnt - 1'b1;
            endcase
        end
    end

    // always @(posedge clk or negedge rstn) begin
    //     if(!rstn)
    //         rc_cnt <= 8'd0;
    //     else if(curr_state == SADDR)
    //         rc_cnt <= mc_trc_cfg - 1'b1;
    //     else
    //         rc_cnt <= (rc_cnt == 8'd0) ? rc_cnt : rc_cnt - 1'b1;
    // end

    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            array_r_cnt <= 14'd0;
        else if (curr_state == TRP && fsm_cnt == 8'd1) begin
            // auto add to zero
            // if(&array_r_cnt)
            //     array_r_cnt <= 14'd0;
            // else
            array_r_cnt <= array_r_cnt + 1'b1;
        end
    end

    //assign output
    //assign rf_finish = ((curr_state == TRP) && (fsm_cnt == 8'd0) && (&array_r_cnt));
    //for shorter rf process 
    assign rf_finish = ((curr_state == TRP) && (~|fsm_cnt) && (array_r_cnt == 8'd10));
    
    assign array_bank_sel_n = ~(curr_state == TRAS);

    assign array_raddr = array_r_cnt;


    
endmodule
