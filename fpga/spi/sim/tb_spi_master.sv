`timescale 1ns/1ps

module tb_spi_master;

    reg clk = 0;
    always #10 clk = ~clk;  // 50 MHz

    reg rst = 1;

    wire sck;
    wire mosi;
    wire cs_n;
    wire [7:0] led;

    lab7_spi_master #(
        .HALF_CYCLES(25),
        .SEND_INTERVAL_CYCLES(2000),
        .TX_BYTE(8'h55)
    ) dut (
        .clk_50mhz(clk),
        .rst_p(rst),
        .spi_sck(sck),
        .spi_mosi(mosi),
        .spi_cs_n(cs_n),
        .led(led)
    );

    integer bits = 0;
    integer frames = 0;

    reg active = 0;
    reg [7:0] decoded = 0;

    time cs_started = 0;
    time last_cs_started = 0;
    time last_edge = 0;
    time last_mosi_change = 0;

    // MOSI는 CS 시작 시 또는 SCK LOW 구간에만 변경
    always @(mosi) begin
        last_mosi_change = $time;

        if (!rst && active && $time != cs_started)
            if (sck !== 1'b0)
                $fatal(1, "MOSI changed while SCK was HIGH");
    end

    // 프레임 시작과 반복 간격 검사
    always @(negedge cs_n) begin
        if (!rst) begin
            if (active)
                $fatal(1, "Overlapping frame");

            active = 1;
            bits = 0;
            decoded = 0;
            cs_started = $time;
            last_edge = $time;

            if (frames > 0)
                if ($time - last_cs_started != 40000)
                    $fatal(1, "Frame interval is not 40000 ns");

            last_cs_started = $time;
        end
    end

    // 반주기 500 ns 및 상승 에지의 데이터 검사
    always @(posedge sck or negedge sck) begin
        if (!rst && active) begin
            if ($time - last_edge != 500)
                $fatal(1, "SCK half-period is not 500 ns");

            last_edge = $time;

            if (sck) begin
                if (cs_n !== 1'b0)
                    $fatal(1, "SCK rising while CS is HIGH");

                if ($time - last_mosi_change < 500)
                    $fatal(1, "Insufficient MOSI setup time");

                decoded = {decoded[6:0], mosi};
                bits = bits + 1;

                if (bits > 8)
                    $fatal(1, "More than eight rising edges");
            end
        end else if (!rst && sck) begin
            $fatal(1, "SCK rising outside a frame");
        end
    end

    // 프레임 종료 시 수신한 바이트와 CS 유지 시간 검사
    always @(posedge cs_n) begin
        if (!rst && active) begin
            if (sck !== 1'b0)
                $fatal(1, "SCK is not LOW at frame end");

            if (bits != 8 || decoded !== 8'h55)
                $fatal(1, "Frame error: bits=%0d data=%02h",
                       bits, decoded);

            if ($time - last_edge != 500)
                $fatal(1, "CS hold time is not 500 ns");

            active = 0;
            frames = frames + 1;

            $display("MASTER FRAME %0d OK: data=%02h bits=%0d",
                     frames, decoded, bits);
        end
    end

    initial begin
        $dumpfile("sim/tb_spi_master.vcd");
        $dumpvars(0, tb_spi_master);

        repeat (5) @(negedge clk);

        if (sck !== 0 || cs_n !== 1 || led !== 0)
            $fatal(1, "Initial reset state error");

        rst = 0;

        wait (frames == 3);
        repeat (3) @(negedge clk);

        if (led !== 8'h55)
            $fatal(1, "LED did not update after transmission");

        rst = 1;
        repeat (3) @(negedge clk);

        if (sck !== 0 || cs_n !== 1 ||
            dut.busy !== 0 || dut.done !== 0 || led !== 0)
            $fatal(1, "Reset after transmission failed");

        $display("LAB7_SPI_MASTER_PASS frames=3");
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "Simulation timeout");
    end

endmodule