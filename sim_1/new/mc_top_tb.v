`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.11.2021 18:10:01
// Design Name: 
// Module Name: mc_top_tb
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


module mc_top_tb (
    
);
    parameter LEN_WIDTH             = 6 ;
    parameter ADDR_WIDTH            = 20;
    parameter RADDR_WIDTN           = 14;
    parameter CADDR_WIDTH           = 6 ;
    parameter DATA_WIDTH            = 64;
    parameter APB_ADDR_WIDTH        = 32;
    parameter APB_DATA_WIDTH        = 32;

    reg                           clk                 ;
    reg                           rstn                ; 
    reg                           axi_awvalid         ;
    wire                          axi_awready         ;
    reg   [LEN_WIDTH - 1:0]       axi_awlen           ;
    reg   [ADDR_WIDTH - 1:0]      axi_awaddr          ;
    reg                           axi_wvalid          ;
    wire                          axi_wready          ;
    reg                           axi_wlast           ;
    reg   [DATA_WIDTH - 1:0]      axi_wdata           ;
    reg                           axi_arvalid         ;
    wire                          axi_arready         ;
    reg   [LEN_WIDTH - 1:0]       axi_arlen           ;
    reg   [ADDR_WIDTH - 1:0]      axi_araddr          ;
    wire                          axi_rvalid          ;
    wire                          axi_rlast           ;
    wire  [DATA_WIDTH - 1:0]      axi_rdata           ;     
    reg                           apb_pclk            ;
    reg                           apb_prst_n          ;
    reg                           apb_psel            ;
    reg                           apb_pwrite          ;
    reg                           apb_penable         ;
    reg   [APB_ADDR_WIDTH - 1:0]  apb_paddr           ;
    reg   [APB_DATA_WIDTH - 1:0]  apb_pwdata          ;
    wire                          apb_pready          ; 
    wire  [APB_DATA_WIDTH - 1:0]  apb_prdata          ;
    wire                          array_banksel_n     ;    
    wire  [RADDR_WIDTN - 1:0]     array_raddr         ;
    wire                          array_cas_wr        ;    
    wire  [CADDR_WIDTH - 1:0]     array_caddr_wr      ;    
    wire                          array_cas_rd        ;    
    wire  [CADDR_WIDTH - 1:0]     array_caddr_rd      ;    
    wire                          array_wdata_rdy     ;    
    wire  [DATA_WIDTH - 1:0]      array_wdata         ;
    reg                           array_rdata_rdy     ;    
    reg   [DATA_WIDTH - 1:0]      array_rdata         ;

mc_top #(
    .LEN_WIDTH          (LEN_WIDTH          ),
    .ADDR_WIDTH         (ADDR_WIDTH         ),
    .RADDR_WIDTN        (RADDR_WIDTN        ),
    .CADDR_WIDTH        (CADDR_WIDTH        ),
    .DATA_WIDTH         (DATA_WIDTH         ),
    .APB_ADDR_WIDTH     (APB_ADDR_WIDTH     ),
    .APB_DATA_WIDTH     (APB_DATA_WIDTH     )
)inst_mc_top(
    .clk                 (clk                 ),
    .rstn                (rstn                ),
    .axi_awvalid         (axi_awvalid         ),
    .axi_awready         (axi_awready         ),
    .axi_awlen           (axi_awlen           ),
    .axi_awaddr          (axi_awaddr          ),
    .axi_wvalid          (axi_wvalid          ),
    .axi_wready          (axi_wready          ),
    .axi_wlast           (axi_wlast           ),
    .axi_wdata           (axi_wdata           ),
    .axi_arvalid         (axi_arvalid         ),
    .axi_arready         (axi_arready         ),
    .axi_arlen           (axi_arlen           ),
    .axi_araddr          (axi_araddr          ),
    .axi_rvalid          (axi_rvalid          ),
    .axi_rlast           (axi_rlast           ),
    .axi_rdata           (axi_rdata           ),  
    .apb_pclk            (apb_pclk            ),
    .apb_prst_n          (apb_prst_n          ),
    .apb_psel            (apb_psel            ),
    .apb_pwrite          (apb_pwrite          ),
    .apb_penable         (apb_penable         ),
    .apb_paddr           (apb_paddr           ),
    .apb_pwdata          (apb_pwdata          ),
    .apb_pready          (apb_pready          ), 
    .apb_prdata          (apb_prdata          ),
    .array_banksel_n     (array_banksel_n     ),    
    .array_raddr         (array_raddr         ),
    .array_cas_wr        (array_cas_wr        ),    
    .array_caddr_wr      (array_caddr_wr      ),    
    .array_cas_rd        (array_cas_rd        ),    
    .array_caddr_rd      (array_caddr_rd      ),    
    .array_wdata_rdy     (array_wdata_rdy     ),    
    .array_wdata         (array_wdata         ),
    .array_rdata_rdy     (array_rdata_rdy     ),    
    .array_rdata         (array_rdata         )
);
    always #5 clk = ~clk;
    always #5 apb_pclk = ~apb_pclk;

    initial begin
        axi_awvalid         = 1'd0;
        axi_awlen           = 6'd0;
        axi_awaddr          = 20'd0;
        axi_wvalid          = 1'd0;
        axi_wlast           = 1'd0;
        axi_wdata           = 64'd0;
        axi_arvalid         = 1'd0;
        axi_arlen           = 6'd0;
        axi_araddr          = 20'd0;    
        apb_psel            = 1'd0;
        apb_pwrite          = 1'd0;
        apb_penable         = 1'd0;
        apb_paddr           = 32'd0;
        apb_pwdata          = 32'd0;
        array_rdata_rdy     = 1'd0;    
        array_rdata         = 64'd0; 
    end

    initial begin
        #0;
        clk                 = 1'd0;
        apb_pclk            = 1'b0;
        rstn                = 1'd0;
        apb_prst_n          = 1'd0;
        #20;
        rstn                = 1'd1;
        apb_prst_n          = 1'd1;
    end

    initial begin
        #50;
        mc_cfg;
        #10;
        send_aw;
        #10;
        send_w;
        #4000;
        $finish;
    end


    
    task send_aw;
    begin
        @(posedge clk)begin
            axi_awvalid <= 1'b1;
            axi_awlen <= 6'd3;
            axi_awaddr <= 20'd1010;
        end
        wait(axi_awready)
        @(posedge clk)begin
            axi_awvalid <= 1'b0;
        end
    end
    endtask


    task send_w;
    begin        
        @(posedge clk)begin
            axi_wvalid <= 1'b1;
            axi_wdata <= 64'd1010;
        end
        #1;
        wait(axi_wready);
        
        @(posedge clk)begin
            axi_wvalid <= 1'b1;
            axi_wdata <= 64'd1011;
        end
        #1;
        wait(axi_wready);

        @(posedge clk)begin
            axi_wvalid <= 1'b1;
            axi_wdata <= 64'd1012;
        end
        #1;
        wait(axi_wready);

        // @(posedge clk)begin
        //     axi_wvalid = 1'b0;
        // end

        // repeat(10) @(posedge clk);

        @(posedge clk)begin
            axi_wvalid <= 1'b1;
            axi_wdata <= 64'd1013;
            axi_wlast <= 1'b1;
        end
        #1;
        wait(axi_wready);
        @(posedge clk)begin
            axi_wvalid <= 1'b0;
            axi_wlast <= 1'b0;
        end
        
    end
    endtask



    task mc_cfg;
    begin
        apb_write_data(32'h0000_0004, {8'd7, 8'd6, 8'd16, 8'd22});
        @(posedge clk);
        apb_write_data(32'h0000_0008, {16'd0, 8'd16, 8'd6});
        @(posedge clk);
        apb_write_data(32'h0000_000C, {4'd0, 28'd0});
        @(posedge clk);
        apb_write_data(32'h0000_0010, {4'd0, 28'h16E3600});
        @(posedge clk);
        apb_write_data(32'h0000_0000, {31'd0, 1'b1});
    end
    endtask


    task apb_write_data;
        input [31:0] addr;
        input [31:0] data;
        begin            
            @(posedge clk) begin
                apb_psel    <= 1'b1;
                apb_pwrite  <= 1'b1;
                apb_paddr   <= addr;
                apb_pwdata  <= data;
            end
            @(posedge clk)
                apb_penable <= 1'b1;
            @(posedge clk) begin
                apb_penable <= 1'b0;
                apb_psel    <= 1'b0;
            end
        end
    endtask

endmodule
