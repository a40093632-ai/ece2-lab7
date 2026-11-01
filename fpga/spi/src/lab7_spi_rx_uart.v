`timescale 1ns/1ps

module lab7_spi_rx_uart #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer BAUD = 9_600
) (
    input  wire       clk_50mhz,
    input  wire       rst_p,
    input  wire       spi_sck,
    input  wire       spi_mosi,
    input  wire       spi_cs_n,
    output wire       uart_txd,
    output reg  [7:0] led
);

    localparam integer UART_DIV =
        (CLK_HZ + BAUD/2) / BAUD;

    wire [7:0] rx_data;
    wire rx_valid;
    wire tx_ready;

    reg tx_valid;
    reg [7:0] tx_data;
    reg [7:0] saved_data;
    reg [1:0] char_index;
    reg sending;

    spi_slave_rx u_spi_rx (
        .clk_50mhz(clk_50mhz),
        .rst_p(rst_p),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_cs_n(spi_cs_n),
        .rx_data(rx_data),
        .rx_valid(rx_valid)
    );

    uart_tx #(.DIV(UART_DIV)) u_uart_tx (
        .clk(clk_50mhz),
        .rst_p(rst_p),
        .valid(tx_valid),
        .data(tx_data),
        .ready(tx_ready),
        .tx(uart_txd)
    );

    function [7:0] hex_ascii;
        input [3:0] value;
        begin
            if (value < 4'd10)
                hex_ascii = 8'h30 + {4'b0000, value};
            else
                hex_ascii = 8'h37 + {4'b0000, value};
        end
    endfunction

    always @(posedge clk_50mhz) begin
        if (rst_p) begin
            tx_valid   <= 1'b0;
            tx_data    <= 8'h00;
            saved_data <= 8'h00;
            char_index <= 2'd0;
            sending    <= 1'b0;
            led        <= 8'h00;
        end else begin
            tx_valid <= 1'b0;

            if (rx_valid) begin
                led <= rx_data;

                if (!sending && !tx_valid) begin
                    saved_data <= rx_data;
                    char_index <= 2'd0;
                    sending    <= 1'b1;
                end
            end

            if (sending && tx_ready && !tx_valid) begin
                case (char_index)
                    2'd0: tx_data <= hex_ascii(saved_data[7:4]);
                    2'd1: tx_data <= hex_ascii(saved_data[3:0]);
                    2'd2: tx_data <= 8'h0D;
                    2'd3: tx_data <= 8'h0A;
                endcase

                tx_valid <= 1'b1;

                if (char_index == 2'd3)
                    sending <= 1'b0;
                else
                    char_index <= char_index + 1'b1;
            end
        end
    end

endmodule