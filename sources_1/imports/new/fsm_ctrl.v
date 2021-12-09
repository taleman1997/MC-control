module fsm_ctrl #(
    parameter FRAME_WIDTH = 87
)(
    //global signal
    input                               clk                     ,
    input                               rstn                    ,
    input                               mc_en                   ,
    input   [27:0]                      mc_rf_start_time_cfg    ,
    input   [27:0]                      mc_rf_period_time_cfg   ,

    //axi_slave_interface
    input   [86:0]                      axi_frame_data          ,
    input                               axi_frame_valid         ,
    output                              axi_frame_ready         ,

    //write ctrl interface
    output   [FRAME_WIDTH - 1:0]        axi_wframe_data         ,
    output                              axi_wframe_valid        ,
    input                               axi_wframe_ready        ,
    input                               write_finish_i          ,

    //write ctrl interface
    output   [FRAME_WIDTH - 1:0]        axi_rframe_data         ,
    output                              axi_rframe_valid        ,
    input                               axi_rframe_ready        ,
    input                               read_finish_i           ,

    //refresh interface
    input                               refresh_finish_i        ,
    output                              refresh_start_o         ,
    output   [1:0]                      curr_state_output
);
    localparam  IDLE    = 2'd0;
    localparam  READ    = 2'd1;
    localparam  WRITE   = 2'd2;
    localparam  REFRESH = 2'd3;;

    reg [1:0]       curr_state;
    reg [1:0]       next_state;
    reg             rf_req;
    reg [27:0]      rf_cnt;
    //reg             rf_wait;
    wire             wr_req;
    wire             rd_req;

    assign curr_state_output = curr_state;       

    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            curr_state <= 2'd0;
        else
            curr_state <= next_state;
    end

    always @(*) begin
        case(curr_state)
            IDLE:begin
                if(~mc_en)
                    next_state = IDLE;
                else if(rf_req)
                    next_state = REFRESH;
                //else if(wr_req && ~rf_req)        // if-else has the priority
                else if(wr_req)
                    next_state = WRITE;
                //else if(rd_req && ~rf_req)
                else if(rd_req)
                    next_state = READ;
                else
                    next_state = IDLE;
            end

            WRITE:begin
                if(write_finish_i)begin
                    if (rf_req) 
                        next_state = REFRESH;
                    else
                        next_state = IDLE;
                end
                else
                    next_state = WRITE;
            end

            READ:begin
                if(read_finish_i)begin
                    if(rf_req)
                        next_state = REFRESH;
                    else
                        next_state = IDLE;
                end
                else
                    next_state = READ;
            end

            REFRESH:begin
                if(refresh_finish_i)begin
                    if(wr_req)
                        next_state = WRITE;
                    else if(rd_req)
                        next_state = READ;
                    else
                        next_state = IDLE;
                end
                    
                else
                    next_state = REFRESH;
            end


            default: next_state = IDLE;

        endcase
    end

    //rf cnt
    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            rf_cnt <= 28'd0;
        else if(mc_en)begin
            if(rf_cnt == mc_rf_period_time_cfg)
                rf_cnt <= 28'd0;
            else
                rf_cnt <= rf_cnt + 1'b1;
        end
        else
            rf_cnt <= 28'd0;
    end

    always @(posedge clk or negedge rstn) begin
        if(!rstn)
            rf_req <= 1'b0;
        else if(mc_en)begin
            if(rf_cnt == mc_rf_start_time_cfg)
                rf_req <= 1'b1;
            else if(curr_state == REFRESH)
                rf_req <= 1'b0;
        end
        // else
        //     rf_req <= 1'b0;
    end

    assign refresh_start_o = rf_req && curr_state == REFRESH;

    assign wr_req = axi_frame_valid && axi_frame_data[84];
    assign rd_req = axi_frame_valid && ~axi_frame_data[84];

    assign axi_wframe_data = axi_frame_data;
    assign axi_wframe_valid = curr_state == WRITE && axi_frame_valid;

    assign axi_rframe_data = axi_frame_data;
    assign axi_rframe_valid = curr_state == READ && axi_frame_valid;

    assign axi_frame_ready = (curr_state == READ && axi_rframe_ready)||(curr_state == WRITE && axi_wframe_ready);


    
endmodule