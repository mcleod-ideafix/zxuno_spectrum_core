`timescale 1ns / 1ps
`default_nettype none

//    This file is part of the ZXUNO Spectrum core. 
//    Creation date is 15:52:26 2015-06-07 by Miguel Angel Rodriguez Jodar
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

module joystick_protocols(
    input wire clk,
    //-- cpu interface
    input wire [15:0] a,
    input wire iorq_n,
    input wire rd_n,
    input wire [7:0] din,
    output reg [7:0] dout,
    output reg oe_n,
    //-- interface with ZXUNO reg bank
    input wire [7:0] zxuno_addr,
    input wire zxuno_regrd,
    input wire zxuno_regwr,
    //-- actual joystick and keyboard signals
    input wire [4:0] kbdjoy_in,
    input wire [5:0] db9joy_in,
    input wire [4:0] kbdcol_in,
    output reg [4:0] kbdcol_out,
    input wire vertical_retrace_int_n // this is used as base clock for autofire
    );

`include "config.vh"

    localparam
      SINCLAIRP1ADDR  = 12,
      SINCLAIRP2ADDR  = 11,
      SINCLAIRADDRE 	= 8, 	//sinclair extendido, semifila ZXCV	  
      DISABLED        = 3'h0,
      KEMPSTON        = 3'h1,
      SINCLAIRP1      = 3'h2,
      SINCLAIRP2      = 3'h3,
      CURSOR          = 3'h4,
      FULLER          = 3'h5,
      // Protocolo OPQASPACEM
  		KMAPOPQA        = 3'h6,		  
      KMAPOP		      = 13,
      KMAPQ			      = 10,
      KMAPA			      = 9,
      KMAPSPACEM	    = 15;	  

    // Input format: FUDLR . 0=pressed, 1=released
    reg db9joyup = 1'b0;
    reg db9joydown = 1'b0;
    reg db9joyleft = 1'b0;
    reg db9joyright = 1'b0;
    reg db9joyfire = 1'b0;
    reg db9joybtn2 = 1'b0;
    reg kbdjoyup = 1'b0;
    reg kbdjoydown = 1'b0;
    reg kbdjoyleft = 1'b0;
    reg kbdjoyright = 1'b0;
    reg kbdjoyfire = 1'b0;
    always @(posedge clk) begin
        {db9joybtn2,db9joyfire,db9joyup,db9joydown,db9joyleft,db9joyright} <= ~db9joy_in;
        {kbdjoyfire,kbdjoyup,kbdjoydown,kbdjoyleft,kbdjoyright} <= kbdjoy_in;
    end
    
    // Update JOYCONF from CPU
    reg [7:0] joyconf = {1'b0,SINCLAIRP1, 1'b0,KEMPSTON};
    always @(posedge clk) begin
        if (zxuno_addr==JOYCONFADDR && zxuno_regwr==1'b1)
            joyconf <= din;
    end
    
    // Autofire stuff
    reg [2:0] cont_autofire = 3'b000;
    reg [3:0] edge_detect = 4'b0000;
    wire autofire = cont_autofire[2];
    always @(posedge clk) begin
        edge_detect <= {edge_detect[2:0], vertical_retrace_int_n};
        if (edge_detect == 4'b0011)
            cont_autofire <= cont_autofire + 1;  // count only on raising edge of vertical retrace int
    end    
    wire kbdjoyfire_processed = (joyconf[3]==1'b0)? kbdjoyfire : kbdjoyfire & autofire;
    wire db9joyfire_processed = (joyconf[7]==1'b0)? db9joyfire : db9joyfire & autofire;
    
    always @* begin
        oe_n = 1'b1;
        dout = 8'hZZ;
        kbdcol_out = kbdcol_in;
        if (zxuno_addr==JOYCONFADDR && zxuno_regrd==1'b1) begin
            oe_n = 1'b0;
            dout = joyconf;
        end
        else if (iorq_n == 1'b0 && a[7:0]==KEMPSTONADDR && rd_n==1'b0) begin
            dout = 8'h00;
            oe_n = 1'b0;
            if (joyconf[2:0]==KEMPSTON)
                dout = dout | {3'b000, kbdjoyfire_processed, kbdjoyup, kbdjoydown, kbdjoyleft, kbdjoyright};
            if (joyconf[6:4]==KEMPSTON)
                dout = dout | {2'b00, db9joybtn2, db9joyfire_processed, db9joyup, db9joydown, db9joyleft, db9joyright};
        end
        else if (iorq_n == 1'b0 && a[7:0]==FULLERADDR && rd_n==1'b0) begin
            dout = 8'hFF;
            oe_n = 1'b0;
            if (joyconf[2:0]==FULLER)
                dout = dout & {~kbdjoyfire_processed, 3'b111, ~kbdjoyright, ~kbdjoyleft, ~kbdjoydown, ~kbdjoyup};
            if (joyconf[6:4]==FULLER)
                dout = dout & {~db9joyfire_processed, ~db9joybtn2, 2'b11, ~db9joyright, ~db9joyleft, ~db9joydown, ~db9joyup};
        end
//        else 
		  if (iorq_n==1'b0 && a[SINCLAIRP1ADDR]==1'b0 && a[0]==1'b0 && rd_n==1'b0) begin
            if (joyconf[2:0]==SINCLAIRP1)
                kbdcol_out = kbdcol_out & {~kbdjoyleft,~kbdjoyright,~kbdjoydown,~kbdjoyup,~kbdjoyfire_processed};
            if (joyconf[6:4]==SINCLAIRP1)
                kbdcol_out = kbdcol_out & {~db9joyleft,~db9joyright,~db9joydown,~db9joyup,~db9joyfire_processed};
            if (joyconf[2:0]==CURSOR)
                kbdcol_out = kbdcol_out & {~kbdjoydown,~kbdjoyup,~kbdjoyright,1'b1,~kbdjoyfire_processed};
            if (joyconf[6:4]==CURSOR)
                kbdcol_out = kbdcol_out & {~db9joydown,~db9joyup,~db9joyright,~db9joybtn2,~db9joyfire_processed};
        end
//        else 
		  if (iorq_n==1'b0 && a[SINCLAIRP2ADDR]==1'b0 && a[0]==1'b0 && rd_n==1'b0) begin
            if (joyconf[2:0]==SINCLAIRP2)
                kbdcol_out = kbdcol_out & {~kbdjoyfire_processed,~kbdjoyup,~kbdjoydown,~kbdjoyright,~kbdjoyleft};
            if (joyconf[6:4]==SINCLAIRP2)
                kbdcol_out = kbdcol_out & {~db9joyfire_processed,~db9joyup,~db9joydown,~db9joyright,~db9joyleft};
            if (joyconf[2:0]==CURSOR)
                kbdcol_out = kbdcol_out & {~kbdjoyleft,4'b1111};
            if (joyconf[6:4]==CURSOR)
                kbdcol_out = kbdcol_out & {~db9joyleft,4'b1111};
        end
		  //Sinclair extendido,Z-X
		  if (iorq_n==1'b0 && a[SINCLAIRADDRE]==1'b0 && a[0]==1'b0 && rd_n==1'b0) begin
				if (joyconf[6:4]==SINCLAIRP1)
                kbdcol_out = kbdcol_out & {2'b11, ~db9joybtn2, 2'b11};               
				if (joyconf[6:4]==SINCLAIRP2)
					 kbdcol_out = kbdcol_out & {3'b111, ~db9joybtn2, 1'b1};
		  end
		  //
		  //Protocolo OPQASPACEM
		  if (iorq_n==1'b0 && a[KMAPOP]==1'b0 && a[0]==1'b0 && rd_n==1'b0) begin
				if (joyconf[6:4]==KMAPOPQA)    
					 kbdcol_out = kbdcol_out & {3'b111,  ~db9joyleft, ~db9joyright};
		  end	
		  if (iorq_n==1'b0 && a[KMAPQ]==1'b0 && a[0]==1'b0 && rd_n==1'b0) begin
				if (joyconf[6:4]==KMAPOPQA)    
					 kbdcol_out = kbdcol_out & {4'b1111, ~db9joyup};
		  end	  	
		  if (iorq_n==1'b0 && a[KMAPA]==1'b0 && a[0]==1'b0 && rd_n==1'b0) begin
				if (joyconf[6:4]==KMAPOPQA)    
					 kbdcol_out = kbdcol_out & {4'b1111,  ~db9joydown};
		  end	 
		  if (iorq_n==1'b0 && a[KMAPSPACEM]==1'b0 && a[0]==1'b0 && rd_n==1'b0) begin
				if (joyconf[6:4]==KMAPOPQA)    
					 kbdcol_out = kbdcol_out & {2'b11, ~db9joybtn2,  1'b1, ~db9joyfire};
		  end	  
		  //
    end
endmodule
