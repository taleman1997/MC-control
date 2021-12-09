`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.11.2021 19:44:08
// Design Name: 
// Module Name: axi_slave
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


// index	description
// [86]	start of frame(sof)
// [85]	end of frame(eof)
// [84]	wr_flag
// [70:83]	row_addr
// [64:69]	col_addr
// [63:0]	wdata
// 3 fifo need for w aw ar channel


module axi_slave#(
    parameter AXI_ADDR_WIDTH = 20,
    parameter AXI_DATA_WIDTH = 64,
    parameter AXI_LEN_WIDTH  = 6 ,
    parameter FRAME_WIDTH    = AXI_ADDR_WIDTH + AXI_DATA_WIDTH + 3
    )(

    //configure signal
    input                                       mc_work_en      ,
    input                                       rstn            ,
    input                                       clk             ,
    //------------axi slave interface-------------
    //aw channel
    input                                       axi_awvalid     ,
    output                                      axi_awready     ,
    input       [AXI_LEN_WIDTH - 1 : 0]         axi_awlen       ,
    input       [AXI_ADDR_WIDTH - 1 : 0]        axi_awaddr      ,
    
    //w channel 
    input                                       axi_wvalid      ,
    output                                      axi_wready      ,
    input                                       axi_wlast       ,
    input       [AXI_DATA_WIDTH - 1 : 0]        axi_wdata       ,
    
    //ar channel    
    input                                       axi_arvalid     ,
    output                                      axi_arready     ,
    input       [AXI_LEN_WIDTH - 1 : 0]         axi_arlen       ,
    input       [AXI_ADDR_WIDTH - 1 : 0]        axi_araddr      ,
    
    //r chanel  
    output                                      axi_rvalid      ,
    output                                      axi_rlast       ,
    output      [AXI_DATA_WIDTH - 1 : 0]        axi_rdata       ,
    
    //internal frame interface
    output      [FRAME_WIDTH - 1:0]             axi_frame_data  ,
    output                                      axi_frame_valid ,
    input                                       axi_frame_ready ,
    
    //array back signal
    input       [AXI_DATA_WIDTH - 1 : 0]        array_rdata     ,
    input                                       array_rvalid    
    
);

    //states define
    localparam IDLE          = 3'd0;
    localparam WADDR         = 3'd1;
    localparam WDATA         = 3'd2;
    localparam RADDR         = 3'd3;
    localparam RADDR_SEND    = 3'd4;

    reg [2:0] curr_state;
    reg [2:0] next_state;
    reg prio_flag;              //W/R prior flag




    //fifo design
    //fifo parameter 
    localparam FIFO_DEPTH = 8;
	localparam FIFO_AFULL = FIFO_DEPTH - 1;
    localparam FIFO_ADDR_WIDTH = 3;
	localparam FIFO_AEMPTY = 1;
	localparam FIFO_WR_ADDR_WIDTH = 26;     //base_addr + len = 20 + 6
	localparam FIFO_W_DATA_WIDTH = 64;      //data + last = 64 

    wire                                            aw_write_en;
    wire                                            aw_read_en;
    wire                                            aw_full;
    wire                                            aw_empty;
    wire [AXI_DATA_WIDTH + AXI_LEN_WIDTH - 1 : 0]   aw_read_data;
    wire [AXI_DATA_WIDTH + AXI_LEN_WIDTH - 1 : 0]   aw_write_data;

    wire                                            ar_write_en;
    wire                                            ar_read_en;
    wire                                            ar_full;
    wire                                            ar_empty;
    wire [AXI_DATA_WIDTH + AXI_LEN_WIDTH - 1 : 0]   ar_read_data;
    wire [AXI_DATA_WIDTH + AXI_LEN_WIDTH - 1 : 0]   ar_write_data;


    wire                                            w_write_en;
    wire                                            w_read_en;
    wire                                            w_full;
    wire                                            w_empty;
    wire [AXI_DATA_WIDTH - 1 : 0]                   w_read_data;
    wire [AXI_DATA_WIDTH - 1 : 0]                   w_write_data;

    wire                                            eof_write_en;
    wire                                            eof_read_en;
    wire                                            eof_full;
    wire                                            eof_empty;
    wire                                            eof_read_data;
    wire                                            eof_write_data;


    //state machine output
    reg [5:0]    burst_len;
    reg [19:0]  curr_addr;
    wire         rw_flag;
    
    wire         sof;
    wire         eof;
    reg [5:0]    data_cnt;




    //----------------------------------FSM DESIGN-----------------------------------
    always@(posedge clk or negedge rstn)begin
        if(!rstn)
            curr_state <= IDLE;
        else
            curr_state <= next_state;
    end

    always@(*)begin
        case(curr_state)
            IDLE:begin
                if({!aw_empty ,!ar_empty} == 2'b10)
                    next_state = WADDR;
                else if({!aw_empty ,!ar_empty} == 2'b01)
                    next_state = RADDR;
                else if({!aw_empty ,!ar_empty} == 2'b11)
                    next_state = prio_flag ? WADDR : RADDR;
                else 
                    next_state = IDLE;
            end

            WADDR:begin
                next_state = WDATA;
            end

            WDATA:begin
                if(data_cnt == burst_len && axi_frame_ready && axi_frame_valid)
                    next_state = IDLE;
                else
                    next_state = WDATA;
            end

            RADDR:begin
                next_state = RADDR_SEND;
            end

            RADDR_SEND:begin
                if(data_cnt == burst_len && axi_frame_ready && axi_frame_valid)
                    next_state = IDLE;
                else
                    next_state = RADDR_SEND; 
            end

            default: next_state = IDLE;

        endcase
    end

    // ctrl of read write prio_flag
    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            prio_flag = 1'b0;
        else if({!aw_empty ,!ar_empty} == 2'b11 && curr_state == IDLE)
            prio_flag = ~prio_flag;
    end



    //------------------------fifo signal control-------------------------------------
    // 4 fifo needed: wdata waddr raddr eof
    //---------------------------------FIFO SIGNAL DESIGN----------------------------
    //control of aw fifo
    assign aw_write_en = axi_awvalid && axi_awready;
    assign aw_read_en  = curr_state == WADDR;
    assign aw_write_data = {axi_awlen, axi_awaddr};

    //control of ar fifo
    assign ar_write_en = axi_arvalid && axi_arready;
    assign ar_read_en  = curr_state == RADDR;
    assign ar_write_data = {axi_arlen, axi_araddr};

    //control of w fifo
    assign w_write_en = axi_wvalid && axi_wready;
    assign w_read_en  = axi_frame_ready && axi_frame_valid && (curr_state == WDATA);
    assign w_write_data = axi_wdata;

    //control of eof fifo
    assign eof_write_en = axi_frame_ready && axi_frame_valid && !rw_flag;
    assign eof_read_en  = array_rvalid;               //the fifo is not empty can confirm
    assign eof_write_data = data_cnt == burst_len;

    //fifo data number base addr read out
    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            burst_len  <= 6'd0;
        else if(curr_state == WADDR)
            burst_len  <= aw_read_data[25:20];
        else if (curr_state == RADDR)
            burst_len  <= ar_read_data[25:20];
    end

    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            curr_addr       <= 20'd0;
        else if(curr_state == WADDR)
            curr_addr       <= aw_read_data[19:0];
        else if (curr_state == RADDR) 
            curr_addr       <= ar_read_data[19:0];
        else if (axi_frame_ready && axi_frame_valid && (curr_state == WDATA || curr_state == RADDR_SEND) ) 
            curr_addr       <= curr_addr + 1'b1;
    end


    
    
    //----------------------some internal signals----------------------------
    //data cnt control
    always@(posedge clk or negedge rstn)begin
        if(!rstn)
            data_cnt <= 6'd0;
        else if (data_cnt == burst_len && axi_frame_ready && axi_frame_valid) 
            data_cnt <= 6'd0;
        else if((curr_state == WDATA || curr_state == RADDR_SEND)&& axi_frame_ready && axi_frame_valid)
            data_cnt <= data_cnt + 1'b1;
    end


    //design of sof and eof
    assign sof = (curr_state == WDATA || curr_state == RADDR_SEND) && ((data_cnt == 6'd0) || (curr_addr[5:0] == 6'd0));
    assign eof = (curr_state == WDATA || curr_state == RADDR_SEND) && ((data_cnt == burst_len) || (curr_addr[5:0] == 6'd63));

    assign rw_flag = (curr_state == WDATA) ? 1'b1 : 1'b0;
    
    //-----------------------some output signal------------------------------
    assign axi_awready = !aw_full;

    assign axi_arready = !ar_full;

    assign axi_wready  = !w_full;

    assign axi_frame_data = {sof, eof, wr_flag, curr_addr, w_read_data};

    assign axi_frame_valid = (!w_empty && curr_state == WDATA) || (curr_state == RADDR_SEND);

    assign axi_rdata = array_rdata;

    assign axi_rvalid = array_rvalid;

    assign axi_rlast = eof_read_data;   //from the eof fifo






        //-------------------------inst of fifo---------------------------------------------
        sync_fifo #(
            .DATA_WIDTH             (26),
            .FIFO_DEPTH             (8),
            .ADDR_WIDTH             (3),
            .READ_MODE              (0),
            .ALMOST_EMPTY_DEPTH     (1),
            .ALMOST_FULL_DEPTH      (7)
        )sync_fifo_aw_inst(    
            .clk                    (clk                    ),
            .rstn                   (rstn                   ),
            .write_en               (aw_write_en            ),
            .write_data             (aw_write_data          ),
            .read_en                (aw_read_en             ),
            .read_data              (aw_read_data           ),
            .full                   (aw_full                ),
            .empty                  (aw_empty               )
        );
    
    
        sync_fifo #(
            .DATA_WIDTH             (26),
            .FIFO_DEPTH             (8),
            .ADDR_WIDTH             (3),
            .READ_MODE              (0),
            .ALMOST_EMPTY_DEPTH     (1),
            .ALMOST_FULL_DEPTH      (7)
        )sync_fifo_ar_inst(    
            .clk                    (clk                    ),
            .rstn                   (rstn                   ),
            .write_en               (ar_write_en            ),
            .write_data             (ar_write_data          ),
            .read_en                (ar_read_en             ),
            .read_data              (ar_read_data           ),
            .full                   (ar_full                ),
            .empty                  (ar_empty               )
        );
    
    
        sync_fifo #(
            .DATA_WIDTH             (64),
            .FIFO_DEPTH             (8),
            .ADDR_WIDTH             (3),
            .READ_MODE              (0),
            .ALMOST_EMPTY_DEPTH     (1),
            .ALMOST_FULL_DEPTH      (7)
        )sync_fifo_w_inst(    
            .clk                    (clk                    ),
            .rstn                   (rstn                   ),
            .write_en               (w_write_en             ),
            .write_data             (w_write_data           ),
            .read_en                (w_read_en              ),
            .read_data              (w_read_data            ),
            .full                   (w_full                 ),
            .empty                  (w_empty                )
        );
    
        sync_fifo #(
            .DATA_WIDTH             (1),
            .FIFO_DEPTH             (8),
            .ADDR_WIDTH             (3),
            .READ_MODE              (0),
            .ALMOST_EMPTY_DEPTH     (1),
            .ALMOST_FULL_DEPTH      (7)
        )sync_fifo_eof_inst(    
            .clk                    (clk                    ),
            .rstn                   (rstn                   ),
            .write_en               (eof_write_en           ),
            .write_data             (eof_write_data         ),
            .read_en                (eof_read_en            ),
            .read_data              (eof_read_data          ),
            .full                   (eof_full               ),
            .empty                  (eof_empty              )
        );

    
endmodule
