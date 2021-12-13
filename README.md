# **Memory Controller Design Specification**

## 1. **Overview**
### 1.1 **Function Description**

memory controller实现了对array read/write/refresh的控制，其接口完成了axi bus到array interface之间的转换。

### 1.2 **Feature List**
- 支持array时序可配置
- 支持array刷新周期可配置
- 支持axi bus 跨行
- array 工作频率为 $200MHz$
  
### 1.3 **Block Diagram**

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/top_module_block.png)

### 1.4 **Interface Description**

|**signal name**|**width**|**direction**|**description**|
| - | - | - | - |
|**global signal**|
|clk|1|input|system clk, 400MHz|
|rst\_n|1|input|system reset|
|**axi bus**|
|axi\_awvalid|input|1|axi aw channel valid|
|axi\_awready|output|1|axi aw channel ready|
|axi\_awlen|input|6|axi aw channel len|
|axi\_awaddr|input|20|axi aw channel address|
|axi\_wvalid|input |1|axi w channel valid|
|axi\_wready|output|1|axi w channel ready|
|axi\_wlast|input|1|axi w channel last|
|axi\_wdata|input|64|axi w channel data|
|axi\_arvalid|input|1|axi ar channel valid|
|axi\_arready|output|1|axi ar channel ready|
|axi\_arlen|input|6|axi ar channel len|
|axi\_araddr|input|20|axi ar channel address|
|axi\_rvalid|output|1|axi r channel valid|
|axi\_rlast|output|1|axi r channel last|
|axi\_rdata|output|64|axi r channel data|
|**apb bus**|
|||||
|apb\_pclk|input|1|apb clock|
|apb\_prst\_n|input|1|apb reset|
|apb\_psel|input|1|apb select|
|apb\_pwrite|input|1|apb read/write indication|
|apb\_penable|input|1|apb enable|
|apb\_paddr|Input|16|apb addr|
|apb\_pwdata|input|32|apb write data|
|apb\_pready|output|1|apb ready|
|apb\_prdata|output|32|apb read data|
|**array interface**|
|array\_banksel\_n|output|1|array select|
|array\_raddr|output|14|array row address|
|array\_cas\_wr|output|1|array column address strobe for write|
|array\_caddr\_wr|output|6|array column address for write|
|array\_cas\_rd|output|1|array column address strobe for read|
|array\_caddr\_rd|output|6|array column address for read|
|array\_wdata\_rdy|output|1|array write data indication|
|array\_wdata|output|64|array write data |
|array\_rdata\_rdy|input|1|array read data indication |
|array\_rdata|input|64|array read data|

### 1.5 **Timing**

Write without cross row

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/top_wr_ncross.png)

Write with cross row

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/top_wr_cross.png)

Read without cross row

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/top_rd_ncross.png)

Read with cross row

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/top_rd_ncross.png)

## 2. **axi\_slave**
### 2.1 **Function Description**

本模块用于接受和处理AXI总线数据，将数据存储到fifo中并整合为frame输出给array controller模块。同时该模块也接收array controller模块发送的读数据，并将读数据发送到AXI总线上。

### 2.2. **Feature List**
- 支持burst跨行

### 2.3 **Interface Description**

|**signal name**|**width**|**direction**|**description**|
| - | - | - | - |
|**axi\_slave interface**|
|axi\_awvalid|input|1|axi aw channel valid|
|axi\_awready|output|1|axi aw channel ready|
|axi\_awlen|input|6|axi aw channel len|
|axi\_awaddr|input|20|axi aw channel address|
|axi\_wvalid|input |1|axi w channel valid|
|axi\_wready|output|1|axi w channel ready|
|axi\_wlast|input|1|axi w channel last|
|axi\_wdata|input|64|axi w channel data|
|axi\_arvalid|input|1|axi ar channel valid|
|axi\_arready|output|1|axi ar channel ready|
|axi\_arlen|input|6|axi ar channel len|
|axi\_araddr|input|20|axi ar channel address|
|axi\_rvalid|output|1|axi r channel valid|
|axi\_rlast|output|1|axi r channel last|
|axi\_rdata|output|64|axi r channel data|
|**Internal frame**|
|axi\_frame\_data|output|87|frame data |
|axi\_frame\_valid|output|1|handshake valid signal|
|axi\_frame\_ready|input|1|handshake ready signal|
|array\_rdata|input|64|handshake read data|
|array\_rvalid|input|1|handshake read data valid signal|
|**Configure interface**|
|mc\_work\_en|input|1|mc\_en control|
注：一个frame位宽为87bits, 组成如下：

|index|description|
| :-: | :-: |
|[86]|start of frame(sof)|
|[85]|end of frame(eof)|
|[84]|wr\_flag|
|[70:83]|row\_addr|
|[64:69]|col\_addr|
|[63:0]|wdata|

### 2.4 **FSM Diagram**

axi\_slave模块通过状态机来实现读写状态的仲裁。从IDLE状态跳出，通过aw,ar通道fifo的空信号控制。Idle\_ctrl\_sig = {arfifo\_empty,awfifo\_empty}。写入读取轮次进行，由prio\_flag信号控制。状态机图如下。



![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/axi_slave_fsm.png)

axi\_slave 含有五个状态，具体描述如下：

1. **IDLE**: 当ar，aw的fifo均为空时，IDLE状态保持。当ar，aw的fifo均不为空时，状态跳转收信号prio\_flag控制。当prio\_flag为高时，跳转WADDR状态，反之跳转到RADDR状态。当ar通道对应fifo为空时，且aw通道对应非空时，跳转WADDR状态，反之，跳转RADDR状态。

2. **WADDR**: 在此状态，读取aw通道fifo数据，包含base address 和len。之后跳转到WDATA。

3. **WDATA**: 在此状态，读取w通道fifo数据，整合成frame并发送。在此状态需要完成的任务有，通过counter确定当下数据为burst中的第几个数据；计算当下数据对应的地址；计算eof，sof；整合成frame发送。当一个burst发送结束，跳转到IDLE状态。

4. **RADDR**: 在此状态，读取ar通道fifo数据，包含base address 和len。之后跳转到RADDR\_SEND。

5. **RADDR\_SEND**：将读地址整合成frame，发送给array controller模块，burst发送结束后，等待接受读数据，接受完全部读数据后，跳转到IDLE.

### 2.5 **Timing**

write with no cross row (len = 4)

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/axi_slave_wr_nc.png)

Write with cross row (len = 4)

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/axi_slave_wr_c.png)

Read with no cross row (len = 4)

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/axi_slave_rd_nc.png)

Read with cross row 

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/axi_slave_rd_c.png)

## 3. **array\_ctrl**
### 3.1 **Function Description**

此模块接受axi\_slave 的frame数据，实现memory读写，刷新操作。

### 3.2 **Feature List**
- 支持array接口时序可配置
- 支持刷新周期可配置
- array 工作频率200MHz
  
### 3.3 **Block Diagram**

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/array_ctrl_fsm.png)

模块array\_ctrl含有五个子模块。各子模块功能如下：

- fsm\_ctrl：实现状态跳转和frame的分发
- array\_wr\_ctrl：输出写控制信号给array\_if\_sel模块。
- array\_rd\_ctrl：输出读控制信号给array\_if\_sel模块。
- array\_rf\_ctrl：输出刷新控制信号给array\_if\_sel模块。
- array\_if\_sel：接收读写，刷新控制信号，并根据sel信号进行选择输出。

### 3.4 **Interface Description**

|**signal name**|**direction**|**width**|**Description**|
| :- | :- | :- | :- |
|**global signal**|
|clk|input|1|input clk signal 400MHz|
|rstn|input|1|reset signal negative|
|cm\_en|input|1|mc enable signal|
|**axi\_slave\_interface**|
|axi\_frame\_data|input|87|axi frame data|
|axi\_frame\_valid|input|1|axi frame valid|
|axi\_frame\_ready|output|1|axi frame ready|
|array\_rdata|output|64|array read data to axi\_slave|
|array\_rvalid|output|1|array read valid to axi\_slave|
|**memory array interface**|
|array\_banksel\_n|output|1|array bank select|
|array\_raddr|output|14|array row address|
|array\_cas\_wr|output|1|array column address strobe for write|
|array\_caddr\_wr|output|6|array column address for write|
|array\_cas\_rd|output|1|array column address strobe for read|
|array\_caddr\_rd|output|6|array column address for read|
|array\_wdata\_rdy|output|1|array write data indication|
|array\_wdata|output|64|array write data |
|array\_rdata\_rdy|input|1|array read data indication |
|array\_rdata|input|64|array read data|
|**apb configure interface**|
|mc\_trc\_cfg|input|8|mc array interface tRC configure|
|mc\_tras\_cfg|input|8|mc array interface tRAS configure|
|mc\_trp\_cfg|input|8|mc array interface tRP configure|
|mc\_trcd\_cfg|input|8|mc array interface tRCD configure|
|mc\_twr\_cfg|input|8|mc array interface tWR configure|
|mc\_trtp\_cfg|input|8|mc array interface tRTP configure|
|mc\_rf\_start\_time\_cfg|input|28|mc array interface refresh start time configure|
|mc\_rf\_period\_time\_cfg|input|28|mc array interface refresh duration configure|

## 3.5 **fsm\_ctrl submodule**

### 3.5.1 *Function description**

实现了axi frame数据分发和状态控制。

### 3.5.2 **Feature List**

- fifo 缓存frame数据

### 3.5.3 **Interface Description**

|**signal name**|**direction**|**width**|**Description**|
| :- | :- | :- | :- |
|**global signal**|
|clk|input|1|input clk signal 400MHz|
|rstn|input|1|reset signal negative|
|mc\_en|input|1|mc enable signal|
|mc\_rf\_start\_time\_cfg|input|28|mc array interface refresh duration configure|
|mc\_rf\_period\_time\_cfg|input|28|mc array interface refresh start time configure|
|**axi\_slave\_interface**|
|axi\_frame\_data|input|87|axi frame data|
|axi\_frame\_valid|input|1|axi frame valid|
|axi\_frame\_ready|output|1|axi frame ready|
|array\_rdata|output|64|array read data to axi\_slave|
|array\_rvalid|output|1|array read valid to axi\_slave|
|**write ctrl interface**|
|axi\_wframe\_data|input|87|axi wframe data|
|axi\_wframe\_valid|input|1|axi wframe valid|
|axi\_wframe\_ready|output|1|axi wframe ready|
| |input|1|write\_finish\_sig|
|**read ctrl interface**|
|axi\_rframe\_data|input|87|axi rframe data|
|axi\_rframe\_valid|input|1|axi rframe valid|
|axi\_rframe\_ready|output|1|axi rframe ready|
|read\_finish\_sig|input|1|read\_finish\_sig|
|**refresh interface**|
|refresh\_finish\_sig|input|1|refresh\_finish\_sig|
|refresh\_start\_sig|output|87|refresh\_start\_sig|

### 3.5.4**FSM Diagram**

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/fsm_fsm.png)

本模块状态机含有五个状态。再IDLE状态下，刷新请求优先级最高。读操作请求（rd\_req）和写操作请求（wr\_req）取决于fifo中读取frame的读写标志。具体状态说明如下：

- IDLE：在此状态时，刷新请求拥有最高优先级。rf\_req 为高是，跳转REFRESH状态。如果刷新请求为低，则根据fifo中frame的读写只是，产生读写请求信号，分别跳转对应读写状态。
- WRITE：在此状态，执行写操作，写操作进行时，如果刷新计数器达到刷新请求值，则rf\_req\_wait为高，在WRITE执行结束后，进入REFRESH状态，否则进入IDLE状态。
- READ：在此状态，执行写操作，读操作进行时，如果刷新计数器达到刷新请求值，则rf\_req\_wait为高，在WRITE执行结束后，进入REFRESH状态，否则进入IDLE状态。
- REFRESH：在此状态进行刷新操作，操作结束后，返回IDLE状态。

刷新时，时序图如下：

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/rf_timging0.png)

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/rf_timging.png)

## 3.6 **array\_wr\_ctrl submodule**

### **3.6.1 Function Description**

此模块根据apb时序配置，完成写操作

### **3.6.2 Feature List**

- array 时序接口可配置

### **3.6.3 Interface Description**

|**signal name**|**direction**|**width**|**Description**|
| :- | :- | :- | :- |
|**global signal**|
|clk|input|1|input clk signal 400MHz|
|rstn|input|1|reset signal negative|
|**fsm ctrl interface**|
|axi\_wframe\_data|input|87|axi wframe data|
|axi\_wframe\_valid|input|1|axi wframe valid|
|axi\_wframe\_ready|output|1|axi wframe ready|
|write\_finish\_sig|input|1|write\_finish\_sig|
|**array interface**|
|frame\_data|input|64|frame data|
|array\_banksel\_n|output|1|bank select (negative)|
|array\_raddr|output|8|row address|
|array\_cas\_wr|output|1|write column address strobe|
|array\_caddr\_rd|output|6|write column address |
|array\_wdata\_rdy|output|1|write data inidcate |
|array\_wdata|input|64|write data|
|**configure signal**|
|tSRADDR|input|8|tSRADDR counter maximum|
|tRCD|input|3|tRCD counter maximum|
|tWR|input|3|tWR counter maximum|
|tRP|input|3|tRP counter maximum|

### **3.6.4 FSM Diagram**

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/array_wr_ctrl_fsm.png)

本模块含有七个状态，具体说明如下

- IDLE：当接受到sof和valid信号时，跳转到SRADDR状态 
- SRADDR：此状态结束后，banksel信号拉低。 
- RCD：rol-col-delay状态。当计时器达到mc\_trcd\_cfg-1时，判断是否为eof，如果eof为高，跳入WLAST状态，否则跳入WRITE\_DATA\_SEND状态 
- WRITE\_DATA\_SEND：在此状态，发送列地址和对应写数据。当eof和ready信号为高时，此时应该发送最后一个数据，跳转到WLAST状态。
- WLAST: 在此状态，发送最后一个数据，然后跳转到WR 状态。
- WR：判断是否满足tWR和tRAS的最小保持时间。如果满足，跳到RP状态。
- RP：当tRP\_cnt达到mc\_trp\_cfg-1时，跳回IDLE状态。

### **3.6.5 Timing**

**One data frame**

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/array_wr_ctrl_timing_1.png)

**Continuous Frame**

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/array_wr_ctrl_timing_2.png)


**Valid Discontinuous**

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/array_wr_ctrl_timing_3.png)

**Cross Row**

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/array_wr_ctrl_timing_4.png)

## 3.7**array\_rd\_ctrl submodule**

### **3.7.1 Function Description**

此模块根据apb时序配置，完成读操作

### **3.7.2 Feature List**

- array 时序接口可配置

### **3.7.3 Interface Description**

|**signal name**|**direction**|**width**|**Description**|
| :- | :- | :- | :- |
|**global signal**|
|clk|input|1|input clk signal 400MHz|
|rstn|input|1|reset signal negative|
|**fsm ctrl interface**|
|axi\_wframe\_data|input|87|axi wframe data|
|axi\_wframe\_valid|input|1|axi wframe valid|
|axi\_wframe\_ready|output|1|axi wframe ready|
|read\_finish\_sig|input|1|read\_finish\_sig|
|read\_data|output|64||
|**array interface**|
|array\_banksel\_n|output|1|bank select (negative)|
|array\_raddr|output|8|row address|
|array\_cas\_rd|output|1|read column address strobe|
|array\_caddr\_rd|output|6|read column address |
|array\_rdata\_rdy|output|1|read data inidcate |
|rdata|input|64|read data|
|**configure signal**|
|mc\_trc\_cfg|input|8|mc array interface tRC configure|
|mc\_tras\_cfg|input|8|mc array interface tRAS configure|
|mc\_trp\_cfg|input|8|mc array interface tRP configure|
|mc\_trcd\_cfg|input|8|mc array interface tRCD configure|
|mc\_twr\_cfg|input|8|mc array interface tWR configure|
|mc\_trtp\_cfg|input|8|mc array interface tRTP configure|

### **3.1.4 FSM Diagram**

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/array_rd_ctrl_fsm.png)

本模块含有七个状态，具体说明如下

1. IDLE：当接受到sof和valid信号时，跳转到SRADDR状态 
2. SRADDR：此状态结束后，banksel信号拉低。 
3. RCD：rol-col-delay状态。当计时器达到mc\_trcd\_cfg-1时，判断是否为eof，如果eof为高，跳入WLAST状态，否则跳入WRITE\_DATA\_SEND状态 
4. READ\_DATA\_SEND：在此状态，发送列地址和对应写数据。当eof和ready信号为高时，此时应该发送最后一个数据，跳转到WLAST状态。
5. RLAST: 在此状态，发送最后一个数据，然后跳转到WR 状态。
6. RTP：判断是否满足tWR和tRAS的最小保持时间。如果满足，跳到RP状态。
7. RP：当tRP\_cnt达到mc\_trp\_cfg-1时，跳回IDLE状态。






**3.1.5 Timing**

No cross row

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/array_rd_ctrl_timg1.png)

4 data frame with cross row

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/array_rd_ctrl_timg2.png)

1 data frame

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/array_rd_ctrl_timg3.png)

## 3.8**refresh\_task submodule**

### **3.8.1 Function Description**

此模块根据apb时序配置，完成刷新操作

### **3.8.2 Feature List**

- 根据apb的时序配置，完成刷新操作

### **3.8.3 Interface Description**

|**signal name**|**direction**|**width**|**Description**|
| :- | :- | :- | :- |
|**refresh task**| | | |
|clk|input|1|system clk 400MHz|
|rstn|input|1|system reset|
|mc\_rf\_start\_time\_cfg|input|28|refresh start time|
|mc\_rf\_period\_time\_cfg|input|28|refresh period time|
|mc\_trc\_cfg|input|8|trc config|
|mc\_trp\_cfg|input|8|trp config|
|rf\_start|input|1|start signal |
|rf\_finish|input|1|refresh finish signal|
|array\_banksel\_n|output|1|assay select signal|
|array\_raddr|output|14|array row address|

**3.8.4 FSM Diagram**

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/rf_fsm.png)

此模块状态机含有三个状态。

- IDLE: 当收到刷新开始信号时，跳入UP\_ADDR状态.
- UP\_ADDR: 无条件跳转到REFRESH状态
- REFRESH:当收到刷新结束信号跳回idle。

**3.8.5 Timing**

![](https://github.com/taleman1997/MC-control/blob/main/mc_figures/rf_timing_x.png)

1. **mc\_apb\_cfg**

mc apb 寄存器配置如下：

|**offset address**|**register type**|**field**|**register signal name**|**default**|
| :-: | :-: | :-: | :-: | :-: |
|0x00|mc\_work\_ctrl|[0]|mc\_en|1'b0|
|||[31:1]|reserved|31'h0|
|0x04|mc\_timing\_ctrl0|[7:0]|mc\_trc\_cfg|8'd0|
|||[15:8]|mc\_tras\_cfg|8'd0|
|||[23:16]|mc\_trp\_cfg|8'd0|
|||[31:24]|mc\_trcd\_cfg|8'd0|
|0x08|mc\_timing\_ctrl1|[7:0]|mc\_twr\_cfg|8'd0|
|||[15:8]|mc\_trtp\_cfg|8'd0|
|||[31:16]|reserved|8'd0|
|0x0C|mc\_timing\_ctrl2|[27:0]|mc\_rf\_start\_time\_cfg|28'h0000000|
|||[31:28]|reserved|4'd0|
|0x10|mc\_timing\_ctrl3|[27:0]|mc\_rf\_period\_time\_cfg|28'h16E3600|
|||[31:28]|reserved|4'd0|

1. **Summary**

**以下是MC之后的一些总结：**

1. **在数字芯片设计的时候，流程的最开始，也是最重要的是需求分析。我目前将这个过程理解为开发文档的建立。文档是之后rtl代码的指导。我认为建立文档问一下四步：**
   1) **功能分解：将整个芯片的功能分解成若干小模块。我理解的是，这里是设计顶层wrapper下的子模块。确定不同模块负责实现的功能。**
   1) **确定interface：分解出子模块之后，要根据功能设计，确定子模块的interface和顶层wrapper的输入输出。子模块的interface需要考虑各模块之间如何通信，接线，以及和顶层端口的关系。顶层模块的interface，需要根据顶层模块的功能来确定。**
   1) **确定Timing：每个模块，在文档中都应该有不同情况的时序图。我目前的理解是：时序图是设计模块的行为模型（设计模块如何实现功能）。当模块设计使用状态机时，那么状态机的定义和跳转应该记录在文档对应章节和时序图中。此外，在画不同模块的时序图的时候，应该尽量考虑各种可能的情况。时序图要清晰，case情况要完备。时序图是rtl编码的思路。**
   1) **和其他人讨论，检查文档**
1. **在MC实训过程中，也学习了很多编码技巧和编码规范。**
   1) **了解了寄存器配置的设计流程。这种配置适用于准静态信号。如果需要动态配置的话，可以使用配置一个选择信号，打两拍进行同步。**
   1) **当设计中使用了多个counter，如果可以，采用复用的方式，减小面积和代码量。比如在状态机中，不同状态都是用了counter，可以通过在每一个使用counter状态之前，设置一个配置counter的状态。此时的counter往往是递减的（不需要清零设置）。状态机多加一个状态往往没有使用多少资源。**
   1) **状态机的设计可以简化内部逻辑设计，添加看似多余的状态，又是可以简化逻辑。**
   1) **有时候，不同的代码综合出来电路结果相同。那么就要采用更加直白明了的代码方式，增加代码的可读性。**
   1) **Fifo的深度，是根据模块具体行为确定。一开始可以先给的大一点，但是最后一定要分析模块数据流的大小。尽量减少fifo占用的资源。**
