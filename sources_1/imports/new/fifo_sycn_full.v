//----------------------------------------------------
//Time         2021.07.08
//Author:      Li Jianing
//Description: This module is the full function of FIFO
//             with almost full/empty signal. over/under
//             flow is the error signal to help user debug
//             and it's recover by reset the system
//-----------------------------------------------------
module  sync_fifo#(
        //----------------parameter define--------------//
        parameter DATA_WIDTH         = 8,
        parameter FIFO_DEPTH         = 8,
        parameter ADDR_WIDTH         = 3,
        parameter READ_MODE          = 0,
        parameter ALMOST_EMPTY_DEPTH = 1,
        parameter ALMOST_FULL_DEPTH  = FIFO_DEPTH - 1
        )(
        //---------------ports define------------------//
        input                             clk,
        input                             rstn,
        input                             write_en,
        input      [DATA_WIDTH - 1 : 0]   write_data,
        input                             read_en,
        output reg [DATA_WIDTH - 1 : 0]   read_data,
        output                            full,
        output                            almost_full,
        output                            empty,
        output                            almost_empty,
        output reg                        overflow,
        output reg                        underflow
        );

        //-------internal signal define------------------//
        reg [ADDR_WIDTH - 1 : 0]         write_pointer;
        reg [ADDR_WIDTH - 1 : 0]         read_pointer;
        reg [ADDR_WIDTH     : 0]         fifo_counter;
        reg [DATA_WIDTH - 1 : 0]         buffer_mem [FIFO_DEPTH - 1 : 0];

        //-------loop variable define------------------//
        integer II;

        //-----Sequential logic for fifo_counter-------//
        // fifo_counter is count useable space for buffer.   
        // Add one when write one data and minus one for read 
        // Attention: when gave the value, it is a good practice to declear the width.
        //            BE CAREFUL ABOUT THE PIORITY OF IF-ELSE
        always @ (posedge clk or negedge rstn)
        begin
            if(!rstn)
                fifo_counter <= {{ADDR_WIDTH + 1}{1'b0}};
            else if(write_en && !full && read_en && !empty)
                fifo_counter <= fifo_counter;
            else if(write_en && ! full)
                fifo_counter <= fifo_counter + 1'b1;
            else if(read_en && !empty)
                fifo_counter <= fifo_counter - 1'b1;
        end

        //-----Sequential logic for write_pointer-------//
        always @ (posedge clk or negedge rstn)
        begin
            if(!rstn)
                write_pointer<= {{ADDR_WIDTH}{1'b0}};
            else begin
                if(write_pointer == FIFO_DEPTH - 1)
                    write_pointer<= {{ADDR_WIDTH}{1'b0}};
                else if(write_en && ! full)
                    write_pointer<= write_pointer + 1;
            end
        end

        //-----Sequential logic for read_pointer--------//
        always @ (posedge clk or negedge rstn)
        begin
            if(!rstn)
                read_pointer<= {{ADDR_WIDTH}{1'b0}};
            else begin
                if(read_pointer== FIFO_DEPTH - 1)
                    read_pointer<= {{ADDR_WIDTH}{1'b0}};
                else if(read_en && ! empty)
                    read_pointer<= read_pointer+ 1;
            end
        end


        //-----Sequential logic for buffer read--------//
        always @ (posedge clk or negedge rstn)
        begin
            if(!rstn)
                for(II = 0; II < FIFO_DEPTH; II = II + 1)
                    buffer_mem[II] <= {DATA_WIDTH{1'b0}};
            else if(write_en && ! full)
                buffer_mem[write_pointer] <= write_data;
        end

        //-----2 read mode for buffer read------------//
        // use generate to make choice based on parameter
        generate
            if(READ_MODE == 1'b0)
                always @ * 
                read_data = buffer_mem[read_pointer];
            else begin
                always @ (posedge clk or negedge rstn) 
                begin
                    if(!rstn)
                        read_data <= {DATA_WIDTH{1'b0}};
                    else if(read_en && !empty)
                        read_data <= buffer_mem[read_pointer];
                end
            end
        endgenerate

        //-----sequential logic for over/under flow------//
        always @ (posedge clk or negedge rstn)
        begin
            if(!rstn)
                overflow <= 1'b0;
            else if(write_en && full)
                overflow <= 1'b1;
        end

        always @ (posedge clk or negedge rstn)
        begin
            if(!rstn)
                underflow<= 1'b0;
            else if(read_en&& empty)
                underflow<= 1'b1;
        end


        //---------------combinational logic-------------//
        assign full = fifo_counter == FIFO_DEPTH;
        assign empty = fifo_counter == {{ADDR_WIDTH + 1}{1'b0}};
        assign almost_full = fifo_counter  >= ALMOST_FULL_DEPTH  ;
        assign almost_empty = fifo_counter <= ALMOST_EMPTY_DEPTH  ;


endmodule