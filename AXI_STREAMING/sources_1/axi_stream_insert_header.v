`timescale 1ns / 1ps

module axi_stream_insert_header #(
    parameter DATA_WD = 32,
    parameter DATA_BYTE_WD = DATA_WD / 8,

    parameter DATA_DEPTH = 64,
    parameter DATA_ADDR_WD = $clog2(DATA_DEPTH),
    parameter DATA_CNT_WD = $clog2(DATA_BYTE_WD)
    ) (
    input                       clk,
    input                       rst_n,
    // AXI Stream input original data
    input                       valid_in,
    input [DATA_WD-1 : 0]       data_in,
    input [DATA_BYTE_WD-1 : 0]  keep_in,
    input                       last_in,
    output                      ready_in,
    // AXI Stream output with header inserted
    output                      valid_out,
    output [DATA_WD-1 : 0]      data_out,
    output [DATA_BYTE_WD-1 : 0] keep_out,
    output                      last_out,
    input                       ready_out,
    // The header to be inserted to AXI Stream input
    input                       valid_insert,
    input [DATA_WD-1 : 0]       header_insert,
    input [DATA_BYTE_WD-1 : 0]  keep_insert,
    output                      ready_insert
);

reg rec_head_flag; //����֡ͷ��־
reg rec_data_flag; //�������ݱ�־
reg send_data_flag; //�������ݱ�־

reg [DATA_ADDR_WD : 0] head; //������Ч������ʼλ��
reg [DATA_ADDR_WD : 0] tail; //������Ч���ݽ�βλ��

wire [DATA_CNT_WD : 0] head_num;
wire [DATA_CNT_WD : 0] tail_num;

assign head_num = vld_num(keep_insert);
assign tail_num = vld_num(keep_in);

reg [7:0] data_mem [0:DATA_DEPTH-1]; //���ݼĴ���

reg [DATA_WD-1 : 0]      reg_data_out;
reg [DATA_BYTE_WD-1 : 0] reg_keep_out;
reg                      reg_last_out;
reg                      reg_valid_out;

assign ready_insert  = (rec_head_flag == 1 ? 'b1 : 'b0);
assign ready_in      = (rec_data_flag == 1 ? 'b1 : 'b0);

assign valid_out     = send_data_flag && ready_out;
assign data_out      = reg_data_out;
assign keep_out      = reg_keep_out;
assign last_out      = (send_data_flag == 1 && head >= tail ? 'b1 : 'b0);

//����֡ͷ��־ rec_head_flag
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0)
        rec_head_flag <= 0;
    else if (ready_insert == 1 && valid_insert == 1) //���յ�֡ͷ������֡ͷ��־Ϊ0
        rec_head_flag <= 0;
    else if (rec_data_flag == 0 && send_data_flag == 0) //���û�н��շ������ݣ�����֡ͷ��־Ϊ1
        rec_head_flag <= 1;
    else
        rec_head_flag <= rec_head_flag;
end

//�������ݱ�־ rec_data_flag
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0)
        rec_data_flag <= 0;
    else if (ready_insert == 1 && valid_insert == 1) //���յ�֡ͷ���������ݱ�־Ϊ1
        rec_data_flag <= 1;
    else if (ready_in == 1 && valid_in == 1 && last_in == 1) //���յ����һ�����ݣ��������ݱ�־Ϊ0
        rec_data_flag <= 0;
    else
        rec_data_flag <= rec_data_flag;
end

//�������ݱ�־ send_data_flag
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0)
        send_data_flag <= 0;
    else if (ready_in == 1 && valid_in == 1 && last_in == 1) //���յ����һ�����ݣ��������ݱ�־Ϊ1
        send_data_flag <= 1;
    else if (ready_out == 1 && valid_out == 1 && last_out == 1) //�������һ�����ݣ��������ݱ�־Ϊ0
        send_data_flag <= 0;
    else
        send_data_flag <= send_data_flag;
end

//������Ч������ʼλ�� head
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0)
        head <= 0;
    else if (rec_head_flag == 1 && ready_insert == 1 && valid_insert == 1) //���յ�֡ͷ
        head <= DATA_BYTE_WD - head_num;
    else if (rec_data_flag == 1 && valid_in == 1 && ready_in == 1 && last_in == 1)
        head <= head + DATA_BYTE_WD;
    else if (send_data_flag == 1 && ready_out == 1 && valid_out == 1) //��������ʱ��ÿ��һ�ν��и���
        head <= head + DATA_BYTE_WD;
    else
        head <= head;
end

//������Ч���ݽ�βλ�� tail
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0)
        tail <= 0;
    else if (rec_head_flag == 1 && ready_insert == 1 && valid_insert == 1) //���յ�֡ͷ
        tail <= DATA_BYTE_WD;
    else if (rec_data_flag == 1 && ready_in == 1 && valid_in == 1 && last_in != 1) //���յ����ݣ������һ֡
        tail <= tail + DATA_BYTE_WD;
    else if (rec_data_flag == 1 && ready_in == 1 && valid_in == 1 && last_in == 1) //���յ����ݣ����һ֡
        tail <= tail + tail_num;
    else
        tail <= tail;
end

//���ݼĴ������� data_mem
genvar i;
generate for (i = 0; i < DATA_DEPTH; i=i+1) begin : data_mem_blk
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0)
            data_mem[i] <= 0;
        else if (rec_head_flag == 1 && valid_insert == 1 && ready_insert == 1 && i >= tail && i < tail + DATA_BYTE_WD)
            data_mem[i] <= header_insert[DATA_WD - 1 - (i - tail)*8 -: 8];
        else if (rec_data_flag == 1 && valid_in == 1 && ready_in == 1 && i >= tail && i < tail + DATA_BYTE_WD)
            data_mem[i] <= data_in[DATA_WD - 1 - (i - tail)*8 -: 8];
        else
            data_mem[i] <= data_mem[i];
    end
end
endgenerate

//��������
genvar m;
generate for (m = 0; m < DATA_BYTE_WD; m = m + 1) begin : data_send_blk
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0)
            reg_data_out[DATA_WD - 1 - m*8 -: 8] <= 0;
        else if (rec_head_flag == 1)
            reg_data_out[DATA_WD - 1 - m*8 -: 8] <= 0;
        else if (rec_data_flag == 1 && valid_in == 1 && ready_in == 1 && last_in == 1)
            reg_data_out[DATA_WD - 1 - m*8 -: 8] <= data_mem[head + m];
        else if (send_data_flag == 1 && ready_out == 1)
            reg_data_out[DATA_WD - 1 - m*8 -: 8] <= data_mem[head + m];
        else
            reg_data_out[DATA_WD - 1 - m*8 -: 8] <= reg_data_out[DATA_WD - 1 - m*8 -: 8];
    end
end
endgenerate

//���������ֽ���Ч��־
genvar n;
generate for (n = 0; n < DATA_BYTE_WD; n = n + 1) begin : data_send_keep_blk
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0)
            reg_keep_out[n] <= 0;
        else if (rec_head_flag == 1)
            reg_keep_out[n] <= 0;
        else if (send_data_flag == 1 && ready_out == 1)
            reg_keep_out[DATA_BYTE_WD - n - 1] <= head + n < tail ? 1 : 0;
        else
            reg_keep_out[n] <= reg_keep_out[n];
    end
end
endgenerate

//������Ч�ֽڸ���
function [DATA_CNT_WD : 0] vld_num;
    input [DATA_BYTE_WD - 1 : 0]  keep;
    reg [DATA_CNT_WD : 0] j;
    reg [DATA_CNT_WD : 0] cnt;
    begin
        cnt = 0;
        for(j = 0; j < 4; j = j + 1) begin
            if (keep[j])
                cnt = cnt + 1'b1;
            else
                cnt = cnt;
        end
        vld_num = cnt;
    end
endfunction

endmodule