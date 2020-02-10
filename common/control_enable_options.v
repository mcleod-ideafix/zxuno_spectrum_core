`timescale 1ns / 1ps
`default_nettype none

//    This file is part of the ZXUNO Spectrum core. 
//    Creation date is 00:24:56 2016-05-08 by Miguel Angel Rodriguez Jodar
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

module control_enable_options(
    input wire clk,
    input wire rst_n,
    input wire [7:0] zxuno_addr,
    input wire zxuno_regrd,
    input wire zxuno_regwr,
    input wire [7:0] din,
    output reg [7:0] dout,
    output reg oe_n,
    output wire disable_ay,
    output wire disable_turboay,
    output wire disable_7ffd,
    output wire disable_1ffd,
    output wire disable_romsel7f,
    output wire disable_romsel1f,
    output wire enable_timexmmu,
    output wire disable_spisd,
    output wire disable_timexscr,
    output wire disable_ulaplus,
    output wire disable_radas,
    output wire disable_specdrum,
    output wire disable_mixer
    );

`include "config.vh"
    
    reg [7:0] devoptions = 8'h00;  // initial value
    reg [7:0] devopts2 = 8'h00;    // initial value
    assign disable_ay = devoptions[0];
    assign disable_turboay = devoptions[1];
    assign disable_7ffd = devoptions[2];
    assign disable_1ffd = devoptions[3];
    assign disable_romsel7f = devoptions[4];
    assign disable_romsel1f = devoptions[5];
    assign enable_timexmmu = devoptions[6];
    assign disable_spisd = devoptions[7];
    assign disable_ulaplus = devopts2[0];
    assign disable_timexscr = devopts2[1];
    assign disable_radas = devopts2[2];
    assign disable_specdrum = devopts2[3];
    assign disable_mixer = devopts2[4];
    
    always @(posedge clk) begin
        if (rst_n == 1'b0) begin
            devoptions <= 8'h00;  // or after a hardware reset (not implemented yet)
            devopts2 <= 8'h00;
        end
        else if (zxuno_addr == DEVOPTIONS && zxuno_regwr == 1'b1)
            devoptions <= din;
        else if (zxuno_addr == DEVOPTS2 && zxuno_regwr == 1'b1)
            devopts2 <= din;
    end
    
    always @* begin
        oe_n = 1'b1;
        dout = 8'hFF;
        if (zxuno_regrd == 1'b1)            
            if (zxuno_addr == DEVOPTIONS) begin
                oe_n = 1'b0;
                dout = devoptions;
            end
            else if (zxuno_addr == DEVOPTS2) begin
                oe_n = 1'b0;
                dout = devopts2;
            end
        end
endmodule
