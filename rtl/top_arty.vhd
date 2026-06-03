library ieee;
use ieee.std_logic_1164.all;

library neorv32;
use neorv32.neorv32_package.all;

entity top_arty is
    port (
        CLK100MHZ	: in std_logic;
        ck_rst		: in std_logic;
        uart_txd_in	: in std_logic;
        uart_rxd_out	: out std_logic;
        led0		: out std_logic
    );
end entity;

architecture rtl of top_arty is

    signal xbus_adr: std_ulogic_vector(31 downto 0);
    signal xbus_dat_m2s: std_ulogic_vector(31 downto 0);
    signal xbus_dat_s2m: std_logic_vector(31 downto 0);
    signal xbus_cti: std_ulogic_vector(2 downto 0);
    signal xbus_tag: std_ulogic_vector(2 downto 0);
    signal xbus_we: std_ulogic;
    signal xbus_sel: std_ulogic_vector(3 downto 0);
    signal xbus_stb: std_ulogic;
    signal xbus_cyc: std_ulogic;
    signal xbus_ack: std_ulogic;
    signal xbus_err: std_ulogic;
    signal gpio_unused: std_ulogic_vector(31 downto 0);

    component xbus_miner_wrapper
	port (
	    clk_i	: in std_logic;
	    rstn_i	: in std_logic;
	    xbus_adr_i  : in std_logic_vector(31 downto 0);
	    xbus_dat_i  : in std_logic_vector(31 downto 0);
	    xbus_sel_i  : in std_logic_vector(3 downto 0);
	    xbus_we_i   : in std_logic;
	    xbus_stb_i  : in std_logic;
    	    xbus_cyc_i  : in std_logic;
	    xbus_dat_o  : out std_logic_vector(31 downto 0);
    	    xbus_ack_o  : out std_logic;
    	    xbus_err_o  : out std_logic
	);
    end component;

begin

    neorv32_inst : neorv32_top
        generic map (
	    CLOCK_FREQUENCY		=> 100_000_000,
	    BOOT_MODE_SELECT		=> 2,
	    IMEM_EN			=> true,
	    IMEM_SIZE			=> 16 * 1024,
	    DMEM_EN			=> true,
	    DMEM_SIZE			=> 8 * 1024,
	    IO_GPIO_NUM			=> 8,
	    IO_UART0_EN			=> true,
	    XBUS_EN			=> true
	)
	port map (
            clk_i       		=> CLK100MHZ,
            rstn_i      		=> ck_rst,
	    gpio_o			=> gpio_unused,
	    uart0_txd_o			=> uart_rxd_out,
	    uart0_rxd_i			=> uart_txd_in,
            xbus_adr_o  		=> xbus_adr,
            xbus_dat_o  		=> xbus_dat_m2s,
	    xbus_cti_o			=> xbus_cti,
	    xbus_tag_o			=> xbus_tag,
            xbus_sel_o  		=> xbus_sel,
            xbus_we_o   		=> xbus_we,
            xbus_stb_o  		=> xbus_stb,
            xbus_cyc_o  		=> xbus_cyc,
            xbus_dat_i  		=> std_ulogic_vector(xbus_dat_s2m),
            xbus_ack_i  		=> xbus_ack,
            xbus_err_i  		=> xbus_err
        );

    inpsector_inst : xbus_miner_wrapper
        port map (
            clk_i                       => CLK100MHZ,
            rstn_i                      => ck_rst,
            xbus_adr_i                  => std_logic_vector(xbus_adr),
            xbus_dat_i                  => std_logic_vector(xbus_dat_m2s),
            xbus_sel_i                  => std_logic_vector(xbus_sel),
            xbus_we_i                   => xbus_we,
            xbus_stb_i                  => xbus_stb,
            xbus_cyc_i                  => xbus_cyc,
            xbus_dat_o                  => xbus_dat_s2m,
            xbus_ack_o                  => xbus_ack,
            xbus_err_o                  => xbus_err
        );

    led0 <= '1';
end architecture;
