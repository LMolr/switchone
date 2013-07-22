library ieee;
use ieee.numeric_std.all;

library work;
package switchone_pkg is
end package;
use work.switchone_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



entity SwitchOne is
	generic(
		PARAM_DELTA_ON : integer := 4;
		PARAM_DELTA_ADJ : integer := 4;
		PARAM_MAX_V : integer := 255;
		PARAM_MIN_V : integer := 0;
		PARAM_DEF_ON_V : integer := 127;
		PARAM_ADJ_STEP : integer := 8
	);
	port(
		IN_RST : in std_logic;
		IN_CLK : in std_logic;
		IN_BTN : in std_logic;
		OUT_L : out std_logic;
		OUT_V : out integer range PARAM_MIN_V to PARAM_MAX_V
	);
end entity;


architecture A of SwitchOne is

	type state_type is (SOff, TUp, SOn, TAdj, SAdj, AdjLck);
	signal cur_state, nxt_state : state_type;
	signal cur_t, nxt_t : integer range 0 to (PARAM_DELTA_ON + PARAM_DELTA_ADJ);
	signal cur_v, nxt_v : integer range PARAM_MIN_V to PARAM_MAX_V;
	signal cur_dir, nxt_dir : std_logic; -- 1 up, 0 down

begin

	sync_state_update : process(IN_RST, IN_CLK) is
	begin
		if (IN_RST = '1') then
			cur_state <= SOff;
			cur_t <= 0;
			cur_v <= PARAM_DEF_ON_V;
			cur_dir <= '1';
		elsif (rising_edge(IN_CLK)) then
			cur_state <= nxt_state;
			cur_t <= nxt_t;
			cur_v <= nxt_v;
			cur_dir <= nxt_dir;
		end if;
	end process;
	
	state_fn : process(IN_BTN, cur_state, cur_t, cur_v, cur_dir) is
	begin
		-- defaults
		nxt_state <= cur_state;
		nxt_t <= cur_t;
		nxt_v <= cur_v;
		nxt_dir <= cur_dir;

		case cur_state is
			------------
			when SOff =>
				if (IN_BTN = '1') then
					nxt_state <= TUp;
					nxt_t <= cur_t + 1;
				end if;
			-----------
			when TUp =>
				if (IN_BTN = '1') then
					if (cur_t = PARAM_DELTA_ON + PARAM_DELTA_ADJ) then
						nxt_state <= SAdj;
						nxt_t <= 0;
					else
						nxt_state <= TUp;
						nxt_t <= cur_t + 1;
					end if;
				else
					nxt_state <= SOn;
					nxt_t <= 0;
				end if;
			-----------			
			when SOn =>
				if (IN_BTN = '1') then
					nxt_state <= TAdj;
					nxt_t <= cur_t + 1;
				else
					nxt_state <= SOn;
					nxt_t <= 0;
				end if;
			when TAdj =>
				if (IN_BTN = '1') then
					if (cur_t = PARAM_DELTA_ADJ) then
						nxt_state <= SAdj;
						nxt_t <= 0;
					else
						nxt_state <= TAdj;
						nxt_t <= cur_t + 1;
					end if;
				else
					nxt_state <= SOff;
					nxt_t <= 0;
				end if;
			------------
			when SAdj =>
				if (IN_BTN = '1') then
					nxt_state <= SAdj;
					-- adjust V (brightness)
					if (cur_dir = '1') then
						-- V increase required
						if (cur_v = PARAM_MAX_V) then
							-- max reached : decrease V and invert direction
							nxt_v <= PARAM_MAX_V - PARAM_ADJ_STEP;
							nxt_dir <= '0';
							-- lock adjust on max
							nxt_state <= AdjLck;
						elsif (cur_v >= PARAM_MAX_V - PARAM_ADJ_STEP) then
							-- clamp V to max and invert
							nxt_v <= PARAM_MAX_V;
							nxt_dir <= '0';
							-- lock adjust on max
							nxt_state <= AdjLck;
						else
							-- increase V normally
							nxt_v <= cur_v + PARAM_ADJ_STEP;
						end if;
					else
						-- V decrease required
						if (cur_v = PARAM_MIN_V) then
							-- min reached : increase V and invert direction
							nxt_v <= PARAM_MIN_V + PARAM_ADJ_STEP;
							nxt_dir <= '1';
							-- lock adjust on min
							nxt_state <= AdjLck;
						elsif (cur_v - PARAM_ADJ_STEP <= PARAM_MIN_V) then
							-- clamp V to min and invert
							nxt_v <= PARAM_MIN_V;
							nxt_dir <= '1';
							-- lock adjust on min
							nxt_state <= AdjLck;
						else
							-- decrease V normally
							nxt_v <= cur_v - PARAM_ADJ_STEP;
						end if;
					end if;
				else
					nxt_state <= SOn;
					nxt_t <= 0;
					-- invert V adjustment direction
					nxt_dir <= NOT cur_dir;
				end if;
			--------------
			when AdjLck =>
				if (IN_BTN = '1') then
					if (cur_t = PARAM_DELTA_ADJ) then
						nxt_state <= SAdj;
						nxt_t <= 0;
					else
						nxt_state <= AdjLck;
						nxt_t <= cur_t + 1;
					end if;
				else
					-- unlock
					nxt_state <= SOn;
					nxt_t <= 0;
				end if;
			--------------
			when others =>
				nxt_state <= SOff;
				nxt_t <= 0;
				nxt_v <= PARAM_DEF_ON_V;
		end case;
	end process;

	-- out fns
	out_fn : process(cur_state) is
	begin
		case cur_state is
			when SOff =>
				OUT_L <= '0';
			when TUp =>
				OUT_L <= '1';
			when SOn =>
				OUT_L <= '1';
			when TAdj =>
				OUT_L <= '1';
			when SAdj =>
				OUT_L <= '1';
			when AdjLck =>
				OUT_L <= '1';
			when others =>
				OUT_L <= '0';
		end case;
	end process;
	
	OUT_V <= cur_v;
	
end architecture;