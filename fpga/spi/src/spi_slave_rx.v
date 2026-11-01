`timescale 1ns/1ps

module spi_slave_rx (
    input  wire       clk_50mhz,
    input  wire       rst_p,
    input  wire       spi_sck,
    input  wire       spi_mosi,
    input  wire       spi_cs_n,
    output reg  [7:0] rx_data,
    output reg        rx_valid
);

    // 외부 입력을 FPGA 내부 클록에 동기화
    (* ASYNC_REG = "TRUE" *) reg [1:0] sck_sync;
    (* ASYNC_REG = "TRUE" *) reg [1:0] mosi_sync;
    (* ASYNC_REG = "TRUE" *) reg [1:0] cs_sync;

    reg       sck_previous;
    reg [7:0] shift_reg;
    reg [2:0] bit_count;

    wire sck_rising;
    assign sck_rising = sck_sync[1] && !sck_previous;

    always @(posedge clk_50mhz) begin
        if (rst_p) begin
            sck_sync     <= 2'b00;
            mosi_sync    <= 2'b00;
            cs_sync      <= 2'b11;
            sck_previous <= 1'b0;
            shift_reg    <= 8'h00;
            bit_count    <= 3'd0;
            rx_data      <= 8'h00;
            rx_valid     <= 1'b0;
        end else begin
            sck_sync     <= {sck_sync[0], spi_sck};
            mosi_sync    <= {mosi_sync[0], spi_mosi};
            cs_sync      <= {cs_sync[0], spi_cs_n};
            sck_previous <= sck_sync[1];

            // 수신 완료 신호는 한 클록 동안만 출력
            rx_valid <= 1'b0;

            if (cs_sync[1]) begin
                // CS 해제 시 미완성 바이트를 폐기
                shift_reg <= 8'h00;
                bit_count <= 3'd0;
            end else if (sck_rising) begin
                shift_reg <= {shift_reg[6:0], mosi_sync[1]};

                if (bit_count == 3'd7) begin
                    rx_data <= {shift_reg[6:0], mosi_sync[1]};
                    rx_valid <= 1'b1;
                    bit_count <= 3'd0;
                end else begin
                    bit_count <= bit_count + 1'b1;
                end
            end
        end
    end

endmodule