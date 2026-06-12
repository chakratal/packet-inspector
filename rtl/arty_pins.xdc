##not sure what the pin info for the first two lines was bc I can't log into project3 on Vivado again but this is what I added to it

## System Clock (100 MHz)
set_property -dict { PACKAGE_PIN E3   IOSTANDARD LVCMOS33 } [get_ports { sys_clock }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { sys_clock }];

## Reset Button (CK_RST)
set_property -dict { PACKAGE_PIN C2   IOSTANDARD LVCMOS33 } [get_ports { reset }];
