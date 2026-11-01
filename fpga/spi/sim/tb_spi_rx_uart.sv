`timescale 1ns/1ps

module tb_spi_rx_uart;

    reg clk = 0;
    always #10 clk = ~clk;  // 50 MHz

    reg rst = 1;
    reg sck = 0;
    reg mosi = 0;
    reg cs_n = 1;

    wire uart_txd;
    wire [7:0] led;

    // TB에서만 UART 분주값을 16으로 줄임
    localparam integer UART_BIT_NS = 320;

    lab7_spi_rx_uart #(
        .CLK_HZ(50_000_000),
        .BAUD(3_125_000)
    ) dut (
        .clk_50mhz(clk),
        .rst_p(rst),
        .spi_sck(sck),
        .spi_mosi(mosi),
        .spi_cs_n(cs_n),
        .uart_txd(uart_txd),
        .led(led)
    );

    reg [7:0] test_values [0:3];
    reg [127:0] expected_chars =
    128'h35350D0A41350D0A30300D0A46460D0A;

    integer received_chars = 0;
    integer bit_no;
    reg [7:0] decoded;
    reg [7:0] expected_char;

    // UART 출력선을 직접 읽어서 문자 복원
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

            if (received_chars >= 16)
                $fatal(1, "Unexpected extra UART character");

            expected_char =
                expected_chars[127 - received_chars * 8 -: 8];

            if (decoded !== expected_char)
                $fatal(1, "UART char %0d: expected=%02h got=%02h",
                       received_chars, expected_char, decoded);

            received_chars = received_chars + 1;

            if (received_chars % 4 == 0)
                $display("UART LINE %0d OK: SPI=%02h",
                         received_chars / 4,
                         test_values[received_chars / 4 - 1]);
        end
    end

    task send_byte(input [7:0] value);
        integer b;
        begin
            sck = 0;
            cs_n = 0;

            for (b = 7; b >= 0; b = b - 1) begin
                mosi = value[b];
                #640; sck = 1;
                #640; sck = 0;
            end

            #640; cs_n = 1;
            #640;
        end
    endtask

    integer n;

    initial begin
        $dumpfile("sim/tb_spi_rx_uart.vcd");
        $dumpvars(0, tb_spi_rx_uart);

        test_values[0] = 8'h55;
        test_values[1] = 8'hA5;
        test_values[2] = 8'h00;
        test_values[3] = 8'hFF;

        repeat (5) @(negedge clk);
        rst = 0;
        repeat (5) @(negedge clk);

        for (n = 0; n < 4; n = n + 1) begin
            send_byte(test_values[n]);

            if (led !== test_values[n])
                $fatal(1, "LED mismatch: expected=%02h got=%02h",
                       test_values[n], led);

            wait (received_chars == (n + 1) * 4);
            #1000;
        end

        $display("LAB7_SPI_RX_UART_PASS bytes=4 chars=16");
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "Simulation timeout");
    end

endmodule