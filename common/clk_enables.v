`timescale 1ns / 1ps
`default_nettype none

//    This file is part of the ZXUNO Spectrum core. 
//    Creation date is 01:22:22 2020-02-09 by Miguel Angel Rodriguez Jodar
//    (c)2014-2020 ZXUNO association.
//    ZXUNO official repository: http://svn.zxuno.com/svn/zxuno
//    Username: guest   Password: zxuno
//    Github repository for this core: https://github.com/mcleod-ideafix/zxuno_spectrum_core
//
//    ZXUNO Spectrum core is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    ZXUNO Spectrum core is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with the ZXUNO Spectrum core.  If not, see <https://www.gnu.org/licenses/>.
//
//    Any distributed copy of this file must keep this notice intact.

module clk_enables (
  input wire clk,
	input wire CPUContention,
  input wire [1:0] turbo_option,
	output wire clk14en,
	output wire clk7en,
	output wire clk7nen,
	output wire clk35en,
	output wire clk35en_n,
	output wire clk175en,
	output wire clkcpu_enable
  );

  reg [15:0] divclk = 16'b00000001;
  always @(posedge clk)
    divclk <= {divclk[14:0], divclk[15]};

  assign clk14en   = divclk[0] | divclk[2] | divclk[4] | divclk[6] | divclk[8] | divclk[10] | divclk[12] | divclk[14];
  assign clk7en    = divclk[0] | divclk[4] | divclk[8] | divclk[12];   
  assign clk7nen   = divclk[2] | divclk[6] | divclk[10] | divclk[14];
  assign clk35en   = divclk[0] | divclk[8];
  assign clk35en_n = divclk[7] | divclk[15]; //divclk[4] | divclk[12];  
	assign clk175en  = divclk[0];

  assign clkcpu_enable = (turbo_option == 2'b11)            ||
                         (turbo_option == 2'b10 && clk14en) ||
                         (turbo_option == 2'b01 && clk7en)  ||
                         (turbo_option == 2'b00 && clk35en && !CPUContention);

endmodule
