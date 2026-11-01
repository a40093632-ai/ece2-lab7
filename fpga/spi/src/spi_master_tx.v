`timescale 1ns/1ps

module spi_master_tx #(
    parameter integer HALF_CYCLES = 25
) (
    input  wire       clk_50mhz,
    input  wire       rst_p,
    input  wire       start,
    input  wire [7:0] tx_data,
    output reg        spi_sck,
    output reg        spi_mosi,
    output reg        spi_cs_n,
    output reg        busy,
    output reg        done
);

    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] TRANSFER = 2'd1;
    localparam [1:0] CS_HOLD  = 2'd2;

    reg [1:0] state;
    reg [31:0] half_count;
    reg [2:0] bit_index;
    reg [7:0] tx_latched;

    always @(posedge clk_50mhz) begin
        if (rst_p) begin
            state      <= IDLE;
            half_count <= 0;
            bit_index  <= 3'd7;
            tx_latched <= 8'h00;
            spi_sck    <= 1'b0;
            spi_mosi   <= 1'b0;
            spi_cs_n   <= 1'b1;
            busy       <= 1'b0;
            done       <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    spi_sck  <= 1'b0;
                    spi_cs_n <= 1'b1;
                    busy     <= 1'b0;

                    if (start) begin
                        tx_latched <= tx_data;
                        bit_index  <= 3'd7;
                        half_count <= 0;
                        spi_mosi   <= tx_data[7];
                        spi_cs_n   <= 1'b0;
                        busy       <= 1'b1;
                        state      <= TRANSFER;
                    end
                end

                TRANSFER: begin
                    if (half_count == HALF_CYCLES - 1) begin
                        half_count <= 0;

                        if (!spi_sck) begin
                            // 상승 에지: 수신 측이 현재 비트를 읽음
                            spi_sck <= 1'b1;
                        end else begin
                            // 하강 에지: 다음 비트를 준비
                            spi_sck <= 1'b0;

                            if (bit_index == 3'd0) begin
                                state <= CS_HOLD;
                            end else begin
                                bit_index <= bit_index - 1'b1;
                                spi_mosi <=
                                    tx_latched[bit_index - 1'b1];
                            end
                        end
                    end else begin
                        half_count <= half_count + 1'b1;
                    end
                end

                CS_HOLD: begin
                    // 마지막 하강 에지 뒤에도 CS를 잠시 유지
                    if (half_count == HALF_CYCLES - 1) begin
                        half_count <= 0;
                        spi_cs_n   <= 1'b1;
                        busy       <= 1'b0;
                        done       <= 1'b1;
                        state      <= IDLE;
                    end else begin
                        half_count <= half_count + 1'b1;
                    end
                end

                default: begin
                    state      <= IDLE;
                    half_count <= 0;
                    spi_sck    <= 1'b0;
                    spi_cs_n   <= 1'b1;
                    busy       <= 1'b0;
                end
            endcase
        end
    end

endmodule