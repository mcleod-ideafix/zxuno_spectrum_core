`timescale 1ns / 1ps
`default_nettype none

//    This file is part of the ZXUNO Spectrum core. 
//    Creation date is 01:22:53 2015-06-15 by Miguel Angel Rodriguez Jodar
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

module scandoubler_ctrl (
    input wire clk,
    input wire [15:0] a,
    input wire kbd_change_video_output,
    input wire kbd_turbo_boost,
    input wire turbo_boost_allowed,
    input wire iorq_n,
    input wire wr_n,
    input wire [7:0] zxuno_addr,
    input wire zxuno_regrd,
    input wire zxuno_regwr,
    input wire [7:0] din,
    output reg [7:0] dout,
    output wire oe_n,
    output wire vga_enable,
    output wire scanlines_enable,
    output wire [2:0] freq_option,
    output wire [1:0] turbo_enable,
    output wire csync_option
    );

`include "config.vh"
    
    assign oe_n = ~(zxuno_addr == SCANDBLCTRL && zxuno_regrd == 1'b1);
    
    reg [7:0] scandblctrl = 8'h00;  // initial value
    reg [1:0] kbd_change_video_edge_detect = 2'b00;
    reg [1:0] kbd_turbo_boost_edge_detect = 2'b00;
    reg [1:0] backup_speed_settings = 2'b00;

    assign vga_enable = scandblctrl[0];
    assign scanlines_enable = scandblctrl[1];
    assign freq_option = scandblctrl[4:2];
    assign turbo_enable = scandblctrl[7:6];
    assign csync_option = scandblctrl[5];
    
    reg kbd_turbo_boost_processed = 1'b0;
    always @(posedge clk) begin
      if (turbo_boost_allowed == 1'b1)
        kbd_turbo_boost_processed <= kbd_turbo_boost;
    end
    
    always @(posedge clk) begin
        kbd_change_video_edge_detect <= {kbd_change_video_edge_detect[0], kbd_change_video_output};
        kbd_turbo_boost_edge_detect <= {kbd_turbo_boost_edge_detect[0], kbd_turbo_boost_processed};
        if (zxuno_addr == SCANDBLCTRL && zxuno_regwr == 1'b1)
            scandblctrl <= din;
        else if (iorq_n == 1'b0 && wr_n == 1'b0 && a == PRISMSPEEDCTRL)
            scandblctrl <= {din[1:0], scandblctrl[5:0]};
        else if (kbd_change_video_edge_detect == 2'b01)
            scandblctrl <= {scandblctrl[7:5], ((scandblctrl[0] == 1'b0)? 3'b111 : 3'b000), scandblctrl[1], ~scandblctrl[0]};
        else if (kbd_turbo_boost_edge_detect == 2'b01) begin
            backup_speed_settings <= scandblctrl[7:6];
            scandblctrl <= {2'b11, scandblctrl[5:0]};
        end
        else if (kbd_turbo_boost_edge_detect == 2'b10)
            scandblctrl <= {backup_speed_settings, scandblctrl[5:0]};
        dout <= scandblctrl;
    end
endmodule
