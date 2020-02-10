`timescale 1ns / 1ps
`default_nettype none

//    This file is part of the ZXUNO Spectrum core. 
//    Creation date is 11:33:13 2014-04-27 by Miguel Angel Rodriguez Jodar
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

module turbosound (
    input wire clk,
		input wire clk35en,
    input wire reset_n,
    input wire disable_ay,
    input wire disable_turboay,
    input wire bdir,
    input wire bc1,
    input wire [7:0] din,
    output wire [7:0] dout,
    output wire oe_n,
    output reg midi_out,
    output wire [7:0] audio_out_ay1,
    output wire [7:0] audio_out_ay2,
    output wire [23:0] audio_out_ay1_splitted,
    output wire [23:0] audio_out_ay2_splitted
    );

	reg ay_select = 1'b1;
	always @(posedge clk) begin
		if (reset_n==1'b0)
			ay_select <= 1'b1;
		else if (disable_ay == 1'b0 && disable_turboay == 1'b0 && bdir && bc1 && din[7:1]==7'b1111111)
			ay_select <= din[0];  // 1: select first AY, 0: select second AY
	end

	wire oe_n_ay1, oe_n_ay2;
	wire [7:0] dout_ay1, dout_ay2;
	assign dout = (ay_select)? dout_ay1 : dout_ay2;
	assign oe_n = (ay_select && !disable_ay)? oe_n_ay1 : 
                (!ay_select && !disable_ay && !disable_turboay)? oe_n_ay2 :
                 1'b1;

  wire [7:0] port_a_ay1, port_a_ay2;
  wire port_a_ay1_oe_n, port_a_ay2_oe_n;
  
  always @* begin
    case (ay_select)
      1'b0: 
        begin
          if (port_a_ay2_oe_n == 1'b0)
            midi_out = port_a_ay2[2];
          else
            midi_out = 1'b0;
        end
      default:
        begin
          if (port_a_ay1_oe_n == 1'b0)
            midi_out = port_a_ay1[2];
          else
            midi_out = 1'b0;
        end
    endcase
  end

YM2149 ay1 (
  .I_DA(din),
  .O_DA(dout_ay1),
  .O_DA_OE_L(oe_n_ay1),
  .I_A9_L(1'b0),
  .I_A8(ay_select),
  .I_BDIR(bdir),
  .I_BC2(1'b1),
  .I_BC1(bc1),
  .I_SEL_L(1'b0),
  .O_AUDIO(audio_out_ay1),
  .O_AUDIO_A(audio_out_ay1_splitted[23:16]),
  .O_AUDIO_B(audio_out_ay1_splitted[15:8]),
  .O_AUDIO_C(audio_out_ay1_splitted[7:0]),
  .I_IOA(8'h00),
  .O_IOA(port_a_ay1),
  .O_IOA_OE_L(port_a_ay1_oe_n),
  .I_IOB(8'h00),
  .O_IOB(),
  .O_IOB_OE_L(),
  .ENA(~disable_ay & clk35en),
  .RESET_L(reset_n),
  .CLK(clk),
  .clkreg(clk)
  );

YM2149 ay2 (
  .I_DA(din),
  .O_DA(dout_ay2),
  .O_DA_OE_L(oe_n_ay2),
  .I_A9_L(1'b0),
  .I_A8(~ay_select),
  .I_BDIR(bdir),
  .I_BC2(1'b1),
  .I_BC1(bc1),
  .I_SEL_L(1'b0),
  .O_AUDIO(audio_out_ay2),
  .O_AUDIO_A(audio_out_ay2_splitted[23:16]),
  .O_AUDIO_B(audio_out_ay2_splitted[15:8]),
  .O_AUDIO_C(audio_out_ay2_splitted[7:0]),
  .I_IOA(8'h00),
  .O_IOA(port_a_ay2),
  .O_IOA_OE_L(port_a_ay2_oe_n),
  .I_IOB(8'h00),
  .O_IOB(),
  .O_IOB_OE_L(),
  .ENA(~disable_ay & ~disable_turboay & clk35en),
  .RESET_L(reset_n),
  .CLK(clk),
  .clkreg(clk)
  );

endmodule
