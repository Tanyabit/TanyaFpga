`timescale 1ns / 1ps

module axi_stream_insert_header_tb ();

parameter DATA_WD = 32;
parameter DATA_BYTE_WD = DATA_WD / 8;

parameter DATA_DEPTH = 32;
parameter DATA_DEPTH_DATA = DATA_DEPTH / 4;
parameter DATA_ADDR_WD = $clog2(DATA_DEPTH);
parameter DATA_CNT_WD = $clog2(DATA_BYTE_WD);

reg                       clk           = 0;
reg                       rst_n         = 0;

reg                       valid_in      ;
reg [DATA_WD-1 : 0]       data_in       ;
reg [DATA_BYTE_WD-1 : 0]  keep_in       ;
reg                       last_in       ;
wire                      ready_in      ;

wire                      valid_out     ;
wire [DATA_WD-1 : 0]      data_out      ;
wire [DATA_BYTE_WD-1 : 0] keep_out      ;
wire                      last_out      ;
wire                      ready_out     ;

wire                      valid_out_1   ;
wire [DATA_WD-1 : 0]      data_out_1    ;
wire [DATA_BYTE_WD-1 : 0] keep_out_1    ;
wire                      last_out_1    ;
reg                       ready_out_1   ;

reg                       valid_insert  ;
reg [DATA_WD-1 : 0]       header_insert ;
reg [DATA_BYTE_WD-1 : 0]  keep_insert	;
wire                      ready_insert  ;
wire                      ready_insert_1;

parameter PERIOD = 10;

//signal
integer seed;
integer i;
integer clk_random;
integer last_num;

defparam     u_0.DATA_WD = 32;
axi_stream_insert_header u_0 (
    .clk            (clk          ),
    .rst_n          (rst_n        ),
    .valid_in       (valid_in     ),
    .data_in        (data_in      ),
    .keep_in        (keep_in      ),
    .last_in        (last_in      ),
    .ready_in       (ready_in     ),

    .valid_out      (valid_out    ),
    .data_out       (data_out     ),
    .keep_out       (keep_out     ),
    .last_out       (last_out     ),
    .ready_out      (ready_out    ),

    .valid_insert   (valid_insert ),
    .header_insert  (header_insert),
    .keep_insert    (keep_insert  ),
    .ready_insert   (ready_insert )
);

defparam     u_1.DATA_WD = 32;
axi_stream_insert_header u_1 (
    .clk            (clk          ),
    .rst_n          (rst_n        ),

    .valid_in       (valid_out    ),
    .data_in        (data_out     ),
    .keep_in        (keep_out     ),
    .last_in        (last_out     ),
    .ready_in       (ready_out    ),

    .valid_out      (valid_out_1  ),
    .data_out       (data_out_1   ),
    .keep_out       (keep_out_1   ),
    .last_out       (last_out_1   ),
    .ready_out      (ready_out_1  ),

    .valid_insert   (valid_insert ),
    .header_insert  (header_insert),
    .keep_insert    (keep_insert  ),
    .ready_insert   (ready_insert_1)
);

initial
begin
    forever #(PERIOD/2)  clk = ~clk;
end

initial
begin
    seed = $realtime;
    #(PERIOD*2) rst_n = 1;
end
//每个时钟变一次的随机信号
always @(posedge clk or negedge rst_n) begin
    clk_random <= $random(seed);
end
//////////////////////////////////////////////////////////////////////////////////
//产生帧头信号
//////////////////////////////////////////////////////////////////////////////////
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0)
        valid_insert  <= 0;
    else if (ready_insert == 1 || ready_insert_1 == 1)
        valid_insert  <= { $random(seed) } % 2;
        // valid_insert  <= 1;
    else
        valid_insert  <= 0;
end
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0)
        header_insert <= 'h12345678;
    else if (ready_insert == 1 || ready_insert_1 == 1)
        header_insert <= header_insert + 1;
    else
        header_insert <= 'h12345678;
end
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0)
        keep_insert <= 0;
    else if (ready_insert == 1 || ready_insert_1 == 1)
        // for (i = 0; i < DATA_BYTE_WD; i = i + 1) begin
        //     keep_insert[i] <= { $random(seed) } % 2;
        // end
        // keep_insert <= 'b0111;
        keep_insert <= (clk_random % 4 == 0 ? 'b1111 :
                        clk_random % 4 == 1 ? 'b0001 :
                        clk_random % 4 == 2 ? 'b0011 : 'b0111);
    else
        keep_insert <= 0;
end
//////////////////////////////////////////////////////////////////////////////////
//产生数据信号
//////////////////////////////////////////////////////////////////////////////////
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0)
        valid_in  <= 0;
    else if (ready_in == 1)
        valid_in  <= { $random(seed) } % 2;
        // valid_in  <= 1;
    else
        valid_in  <= 0;
end

always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0)
        data_in <= 'habcdef12;
    else if (ready_in == 1)
        data_in <= data_in + 1;
    else
        data_in <= 'habcdef12;
end
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0)
        keep_in <= 0;
    else if (ready_in == 1)
        // for (i = 0; i < DATA_BYTE_WD; i = i + 1) begin
        //     keep_in[i] <= { $random(seed) } % 2;
        // end
        // keep_in <= 'b0000;
        keep_in <= (clk_random % 5 == 0 ? 'b0000 :
                    clk_random % 5 == 1 ? 'b1000 :
                    clk_random % 5 == 2 ? 'b1100 :
                    clk_random % 5 == 3 ? 'b1110 : 'b1111);
    else
        keep_in <= 0;
end

always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0)
        last_num <=  { $random(seed) } % DATA_DEPTH_DATA - 1 ;
    else if (ready_in == 1)
        last_num <= last_num;
    else
        last_num <=  { $random(seed) } % DATA_DEPTH_DATA - 1 ;
end

always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0)
        last_in <= 0;
    else if (ready_in == 1 && data_in == ('habcdef12 + last_num))
        last_in <= 1;
    else
        last_in <= 0;
end
//////////////////////////////////////////////////////////////////////////////////
//接收数据信号
//////////////////////////////////////////////////////////////////////////////////
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0)
        ready_out_1 <= 0;
    else
        ready_out_1 <= { $random(seed) } % 2;
end

endmodule