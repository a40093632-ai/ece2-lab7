`timescale 1ns/1ps

module tb_spi_slave_rx;

    reg clk = 0;
    always #10 clk = ~clk;  // 50 MHz

    reg rst = 1;
    reg sck = 0;
    reg mosi = 0;
    reg cs_n = 1;

    wire [7:0] rx_data;
    wire rx_valid;

    spi_slave_rx dut (
        .clk_50mhz(clk),
        .rst_p(rst),
        .spi_sck(sck),
        .spi_mosi(mosi),
        .spi_cs_n(cs_n),
        .rx_data(rx_data),
        .rx_valid(rx_valid)
    );

    reg [7:0] expected [0:4];
    integer received = 0;
    reg previous_valid = 0;

    // 매 수신 완료 시 값과 valid 펄스 길이 검사
    always @(posedge clk) begin
        #1;
        if (rst) begin
            previous_valid = 0;
        end else begin
            if (rx_valid) begin
                if (previous_valid)
                    $fatal(1, "rx_valid longer than one clock");

                if (received >= 5)
                    $fatal(1, "Unexpected extra byte");

                if (rx_data !== expected[received])
                    $fatal(1, "Expected=%02h, received=%02h",
                           expected[received], rx_data);

                $display("RX CHECK %0d: %02h",
                         received + 1, rx_data);
                received = received + 1;
            end
            previous_valid = rx_valid;
        end
    end

    // Mode 0, MSB first, SCK = 781.25 kHz
    task send_byte(input [7:0] value);
        integer bit_no;
        begin
            sck = 0;
            cs_n = 0;

            for (bit_no = 7; bit_no >= 0; bit_no = bit_no - 1) begin
                mosi = value[bit_no];
                #640;
                sck = 1;
                #640;
                sck = 0;
            end

            #640;
            cs_n = 1;
            #640;
        end
    endtask

    integer i;

    initial begin
        $dumpfile("sim/tb_spi_slave_rx.vcd");
        $dumpvars(0, tb_spi_slave_rx);

        expected[0] = 8'h55;
        expected[1] = 8'hA5;
        expected[2] = 8'h00;
        expected[3] = 8'hFF;
        expected[4] = 8'h3C;

        repeat (5) @(negedge clk);
        rst = 0;
        repeat (5) @(negedge clk);

        // CS HIGH일 때 클록이 들어와도 수신하지 않아야 함
        repeat (4) begin
            #640; sck = 1;
            #640; sck = 0;
        end

        if (received != 0)
            $fatal(1, "Received while CS was HIGH");

        send_byte(8'h55);
        send_byte(8'hA5);
        send_byte(8'h00);
        send_byte(8'hFF);

        if (received != 4)
            $fatal(1, "Four-byte reception failed");

        // 3비트만 보낸 뒤 CS 해제: 미완성 바이트 폐기
        cs_n = 0;
        mosi = 1;
        for (i = 0; i < 3; i = i + 1) begin
            #640; sck = 1;
            #640; sck = 0;
        end
        #640; cs_n = 1;
        #640;

        if (received != 4)
            $fatal(1, "Incomplete byte was accepted");

        // CS 재선택 후 새 바이트가 정상 수신되는지 검사
        send_byte(8'h3C);

        if (received != 5)
            $fatal(1, "Recovery after CS release failed");

        $display("LAB7_SPI_SLAVE_RX_PASS checks=5");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Simulation timeout");
    end

endmodule