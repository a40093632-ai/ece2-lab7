`timescale 1ns/1ps

module tb_spi_link;

    reg tx_clk = 0;
    always #10 tx_clk = ~tx_clk;

    reg rx_clk = 0;
    initial begin
        #7;
        forever #10 rx_clk = ~rx_clk;
    end

    reg rst = 1;

    wire sck;
    wire mosi;
    wire cs_n;
    wire uart_txd;
    wire [7:0] tx_led;
    wire [7:0] rx_led;

    // 송신 보드: TB에서만 전송 간격을 6 ms로 축소
    lab7_spi_master #(
        .HALF_CYCLES(25),
        .SEND_INTERVAL_CYCLES(300_000),
        .TX_BYTE(8'h55)
    ) tx_board (
        .clk_50mhz(tx_clk),
        .rst_p(rst),
        .spi_sck(sck),
        .spi_mosi(mosi),
        .spi_cs_n(cs_n),
        .led(tx_led)
    );

    // 수신 보드: 기본 50 MHz / 9600 baud 사용
    lab7_spi_rx_uart rx_board (
        .clk_50mhz(rx_clk),
        .rst_p(rst),
        .spi_sck(sck),
        .spi_mosi(mosi),
        .spi_cs_n(cs_n),
        .uart_txd(uart_txd),
        .led(rx_led)
    );

    localparam integer UART_BIT_NS = 5208 * 20;

    reg [63:0] expected_chars =
        64'h35350D0A35350D0A;

    reg [7:0] decoded;
    reg [7:0] expected_char;

    integer received_chars = 0;
    integer spi_received = 0;
    integer bit_no;

    // SPI 수신 완료 횟수와 데이터 검사
    always @(posedge rx_clk) begin
        #1;
        if (!rst && rx_board.rx_valid) begin
            if (rx_board.rx_data !== 8'h55)
                $fatal(1, "SPI received wrong data");

            spi_received = spi_received + 1;
        end
    end

    // 실제 UART 출력선에서 8N1 프레임 복원
    always begin
        @(negedge uart_txd);

        if (!rst) begin
            #(UART_BIT_NS / 2);

            if (uart_txd !== 1'b0)
                $fatal(1, "UART start bit error");

            for (bit_no = 0; bit_no < 8; bit_no = bit_no + 1) begin
                #(UART_BIT_NS);
                decoded[bit_no] = uart_txd;
            end

            #(UART_BIT_NS);

            if (uart_txd !== 1'b1)
                $fatal(1, "UART stop bit error");

            if (received_chars >= 8)
                $fatal(1, "Unexpected extra UART character");

            expected_char =
                expected_chars[63 - received_chars * 8 -: 8];

            if (decoded !== expected_char)
                $fatal(1, "UART char %0d: expected=%02h got=%02h",
                       received_chars, expected_char, decoded);

            received_chars = received_chars + 1;

            if (received_chars % 4 == 0)
                $display("LINK LINE %0d OK: 55 + CR + LF",
                         received_chars / 4);
        end
    end

    initial begin
        $dumpfile("sim/tb_spi_link.vcd");

        // 긴 UART 검사이므로 고속 내부 클록의 덤프는 생략
        $dumpvars(0, rst, sck, mosi, cs_n, uart_txd,
                     tx_led, rx_led, decoded,
                     received_chars, spi_received,
                     rx_board.rx_data, rx_board.rx_valid,
                     rx_board.tx_data, rx_board.tx_valid,
                     tx_board.start, tx_board.busy, tx_board.done);

        repeat (5) @(negedge tx_clk);
        rst = 0;

        wait (received_chars == 8);
        #(UART_BIT_NS);

        if (spi_received != 2)
            $fatal(1, "Expected two SPI bytes, got %0d",
                   spi_received);

        if (tx_led !== 8'h55 || rx_led !== 8'h55)
            $fatal(1, "TX/RX LED mismatch");

        if (uart_txd !== 1'b1)
            $fatal(1, "UART did not return to idle");

        $display("LAB7_SPI_LINK_PASS bytes=2 chars=8 UART=9600");
        $finish;
    end

    initial begin
        #30000000;
        $fatal(1, "Simulation timeout");
    end

endmodule