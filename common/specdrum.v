`timescale 1ns / 1ps
`default_nettype none

//    This file is part of the ZXUNO Spectrum core. 
//    Creation date is 23:58:32 2017-02-03 by Miguel Angel Rodriguez Jodar
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

module specdrum (
   input wire clk,
   input wire rst_n,
   input wire [15:0] a,
   input wire iorq_n,
   input wire wr_n,
   input wire [7:0] d,
   output reg [7:0] specdrum_left,
   output reg [7:0] specdrum_right
   );

   reg [7:0] regsdrum = 8'h00;
   always @* begin
     specdrum_left = regsdrum;
     specdrum_right = regsdrum;
   end
   always @(posedge clk) begin
      if (rst_n == 1'b0)
         regsdrum <= 8'h00;  // parche para evitar que ESXDOS interfiera |-------------------------|
      //else if (iorq_n == 1'b0 && (a[7:0] == 8'hDF && a[15:8] != 8'h24 || a == 16'h24FD && d == 8'h24 || a[7:0] == 8'hFB) && wr_n == 1'b0)
      else if (iorq_n == 1'b0 && (a[7:0] == 8'hDF || a[7:0] == 8'hFB) && wr_n == 1'b0)
         regsdrum <= d ^ 8'h80;
   end
endmodule

//module specdrum (
//   input wire clk,
//   input wire rst_n,
//   input wire [7:0] a,
//   input wire iorq_n,
//   input wire wr_n,
//   input wire [7:0] d,
//   output reg [7:0] specdrum_left,
//   output reg [7:0] specdrum_right
//   );
//
//   reg [7:0] regsdrum = 8'h00;
//   // pseudo estereo usando un delay de 256 muestras
//   // (alrededor de 10 ms de retraso)
//   reg [7:0] delay[0:255];
//   reg [7:0] dmuestra;
//   reg [7:0] idxwrite = 8'd0;
//   reg [9:0] cnt = 10'd0; // 1 muestra por cada 1024 ciclos de reloj clk (28 MHz / 1024)
//   
//   initial begin
//      specdrum_left = 8'h00;
//      specdrum_right = 8'h00;
//   end
//   
////   reg [7:0] compressor_lut[0:255];
////   initial begin
////      $readmemh ("curva_compresion.hex", compressor_lut);
////   end
//   
//   always @(posedge clk) begin
//      if (rst_n == 1'b0)
//         regsdrum <= 8'h00;
//      else if (iorq_n == 1'b0 && (a == 8'hDF || a == 8'hFB) && wr_n == 1'b0)
//         regsdrum <= d + 8'h80; // compressor_lut[d];
//   end
//   
//   always @(posedge clk) begin
//      cnt <= cnt + 10'd1;
//      case (cnt)
//        10'd0: begin
//                 delay[idxwrite] <= regsdrum;
//                 idxwrite <= idxwrite + 8'd1;
//               end
//        10'd1: dmuestra <= delay[idxwrite];
//        10'd2: begin
//                specdrum_left <= regsdrum;
//                specdrum_right <= dmuestra;
//              end
//      endcase
//   end
//        
//endmodule
