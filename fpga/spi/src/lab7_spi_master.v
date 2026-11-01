`timescale 1ns/1ps

module lab7_spi_master #(
    parameter integer HALF_CYCLES = 25,
    parameter integer SEND_INTERVAL_CYCLES = 50_000_000,
    parameter [7:0] TX_BYTE = 8'h55
) (
    input  wire       clk_50mhz,
    input  wire       rst_p,
    output wire       spi_sck,
    output wire       spi_mosi,
    output wire       spi_cs_n,
    output reg  [7:0] led
);

    reg [31:0] interval_count;
    reg start;

    wire busy;
    wire done;

    spi_master_tx #(
        .HALF_CYCLES(HALF_CYCLES)
    ) u_spi_tx (
        .clk_50mhz(clk_50mhz),
        .rst_p(rst_p),
        .start(start),
        .tx_data(TX_BYTE),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_cs_n(spi_cs_n),
        .busy(busy),
        .done(done)
    );

    always @(posedge clk_50mhz) begin
        if (rst_p) begin
            interval_count <= 0;
            start <= 1'b0;
            led <= 8'h00;
        end else begin
            start <= 1'b0;

            if (interval_count == SEND_INTERVAL_CYCLES - 1) begin
                interval_count <= 0;

                if (!busy)
                    start <= 1'b1;
            end else begin
                interval_count <= interval_count + 1'b1;
            end

            if (done)
                led <= TX_BYTE;
        end
    end

endmodule