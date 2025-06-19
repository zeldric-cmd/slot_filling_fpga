library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity slot_filling_temp is
    Port (
        clk       : in std_logic;   -- 50 MHz
        reset     : in std_logic;
        ALE       : out std_logic;
        START     : out std_logic;
        OE        : out std_logic;
        EOC       : in std_logic;
        ADDR      : out std_logic_vector(2 downto 0);
        DATA_ADC  : in std_logic_vector(7 downto 0);
        LEDR      : out std_logic_vector(2 downto 0)
    );
end slot_filling_temp;

architecture Behavioral of slot_filling_temp is

type state_type is (addr_set, start_conv, wait_eoc, read_adc);
signal state : state_type := addr_set;
signal clk_div : integer range 0 to 49 := 0;  -- divisor para generar 1 MHz
signal slow_clk : std_logic := '0';
signal temp_C : integer := 0;

begin

ADDR <= "000";  -- Canal fijo a IN0

-- Divisor de reloj simple (50 MHz → ~1 MHz)
process(clk, reset)
begin
    if reset = '1' then
        clk_div <= 0;
        slow_clk <= '0';
    elsif rising_edge(clk) then
        if clk_div = 24 then  -- 50 MHz / 25 ≈ 2 MHz ciclos altos-bajos (1 MHz efectivo)
            clk_div <= 0;
            slow_clk <= not slow_clk;
        else
            clk_div <= clk_div + 1;
        end if;
    end if;
end process;

-- Máquina de estados ADC (más rápida)
process(slow_clk, reset)
begin
    if reset = '1' then
        ALE <= '0'; START <= '0'; OE <= '0';
        LEDR <= "000";
        state <= addr_set;

    elsif rising_edge(slow_clk) then
        case state is
            when addr_set =>
                ALE <= '1'; OE <= '0';
                START <= '0';
                state <= start_conv;

            when start_conv =>
                ALE <= '0';
                START <= '1';
                state <= wait_eoc;

            when wait_eoc =>
                START <= '0';
                if EOC = '1' then
                    OE <= '1';
                    state <= read_adc;
                end if;

            when read_adc =>
                temp_C <= (to_integer(unsigned(DATA_ADC)) * 100) / 255;
                OE <= '0';
                state <= addr_set;

                -- Actualización instantánea del Slot Filling
                if temp_C <= 30 then
                    LEDR <= "001"; -- Frío
                elsif temp_C <= 60 then
                    LEDR <= "010"; -- Normal
                else
                    LEDR <= "100"; -- Caliente
                end if;

            when others =>
                state <= addr_set;
        end case;
    end if;
end process;

end Behavioral;
