`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/10/11 13:00:42
// Design Name: 
// Module Name: mc_apb_cfg
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


module mc_apb_cfg (
    //apb bus interace
    input                   apb_pclk                    ,
    input                   apb_prstn                   ,
    input                   apb_psel                    ,
    input                   apb_penable                 ,
    input                   apb_pwrite                  ,
    input       [31:0]      apb_addr                    ,
    input       [31:0]      apb_pwdata                  ,
    output reg  [31:0]      apb_prdata                  ,
    output                  apb_pready                  ,
    output reg              mc_en                       ,
    output reg [7:0]        mc_trc_cfg                  ,
    output reg [7:0]        mc_tras_cfg                 ,
    output reg [7:0]        mc_trp_cfg                  ,
    output reg [7:0]        mc_trcd_cfg                ,
    output reg [7:0]        mc_twr_cfg                  ,
    output reg [7:0]        mc_trtp_cfg                 ,
    output reg [27:0]       mc_rf_start_time_cfg        ,
    output reg [27:0]       mc_rf_period_time_cfg        

);

    //set apb_pready as default 1'b1
    assign apb_pready = 1'b1;

    //output regs


    //write logic
    //put the write data on bus at posedge of psel before the enable
    always @(posedge apb_pclk or negedge apb_prstn) begin
        if (!apb_prstn) begin
            mc_en                 <= 1'b0;
            mc_trc_cfg            <= 8'd20;
            mc_tras_cfg           <= 8'd14;
            mc_trp_cfg            <= 8'd6;
            mc_trcd_cfg           <= 8'd7;
            mc_twr_cfg            <= 8'd6;
            mc_trtp_cfg           <= 8'd2;
            mc_rf_start_time_cfg  <= 28'hfffffff;   //then the rf is closed as default
            mc_rf_period_time_cfg <= 28'd25600000;
        end

        else if(apb_penable && apb_pwrite)begin 
            case(apb_addr)
                32'h0000_0000:begin
                                mc_en                 <= apb_pwdata[0];
                end
                32'h0000_0004:begin
                                mc_trc_cfg            <= apb_pwdata[7:0];
                                mc_tras_cfg           <= apb_pwdata[15:8];
                                mc_trp_cfg            <= apb_pwdata[23:16];
                                mc_trcd_cfg          <= apb_pwdata[31:24];                    
                end            
                32'h0000_0008:begin
                                mc_twr_cfg            <= apb_pwdata[7:0];
                                mc_trtp_cfg           <= apb_pwdata[15:8];
                end
                32'h0000_000C:begin
                                mc_rf_start_time_cfg  <= apb_pwdata[27:0];
                end
                32'h0000_0010:begin
                                mc_rf_period_time_cfg <= apb_pwdata[27:0];
                end
                default: ;
            endcase
        end  

    end


    //read logic
    //note: the read data and enable valid at the same time
    always @(posedge apb_pclk or negedge apb_prstn) begin
        if (!apb_prstn) begin
            apb_prdata <= 32'd0;
        end

        else if(!apb_pwrite && !apb_penable && apb_psel)begin
            case (apb_addr)
                32'h0000_0000:begin
                                apb_prdata  <= {31'd0,mc_en};
                end
                32'h0000_0004:begin
                                apb_prdata  <= {mc_trcd_cfg, mc_trp_cfg, mc_tras_cfg, mc_trc_cfg};                  
                end            
                32'h0000_0008:begin
                                apb_prdata  <= {16'd0, mc_trtp_cfg, mc_twr_cfg};
                end
                32'h0000_000C:begin
                                apb_prdata  <= {4'b000, mc_rf_start_time_cfg};
                end
                32'h0000_000D:begin
                                apb_prdata  <= {4'b000, mc_rf_period_time_cfg};
                end
                default: ;
            endcase
        end
    end
    
endmodule
