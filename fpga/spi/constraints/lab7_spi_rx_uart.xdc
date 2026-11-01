# Combo II-DLD S75 / xc7s75fgga484-1
# Design Top: lab7_spi_rx_uart
# Pin mapping follows existing LAB5 ADC / LAB6 UART XDC files.
# Check physical BDIO header positions before board connection.

# Main clock: board must supply 50 MHz
set_property PACKAGE_PIN B6 [get_ports clk_50mhz]
create_clock -name clk_50mhz -period 20.000 [get_ports clk_50mhz]

# Active-HIGH reset: same pin as LAB6 UART
set_property PACKAGE_PIN K4 [get_ports rst_p]

# SPI inputs: BDIO 0 / 1 / 2
set_property PACKAGE_PIN F8 [get_ports spi_sck]
set_property PACKAGE_PIN E8 [get_ports spi_mosi]
set_property PACKAGE_PIN A7 [get_ports spi_cs_n]

# Keep slave deselected when CS is disconnected
set_property PULLUP TRUE [get_ports spi_cs_n]

# Board USB-UART TX
set_property PACKAGE_PIN F6 [get_ports uart_txd]

# LEDs: same mapping as LAB6 UART
set_property PACKAGE_PIN N5 [get_ports {led[0]}]
set_property PACKAGE_PIN M1 [get_ports {led[1]}]
set_property PACKAGE_PIN M3 [get_ports {led[2]}]
set_property PACKAGE_PIN M7 [get_ports {led[3]}]
set_property PACKAGE_PIN N7 [get_ports {led[4]}]
set_property PACKAGE_PIN M2 [get_ports {led[5]}]
set_property PACKAGE_PIN M4 [get_ports {led[6]}]
set_property PACKAGE_PIN L4 [get_ports {led[7]}]

set_property IOSTANDARD LVCMOS33 [get_ports *]

# External SPI inputs enter synchronizer registers.
# Physical input timing is asynchronous to the FPGA clock.
set_false_path -from [get_ports {spi_sck spi_mosi spi_cs_n rst_p}]