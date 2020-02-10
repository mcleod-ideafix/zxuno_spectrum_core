`timescale 1ns / 1ps
`default_nettype none

//    This file is part of the ZXUNO Spectrum core. 
//    Creation date is 19:56:26 2015-10-17 by Miguel Angel Rodriguez Jodar
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

module uart (
    // CPU interface
    input wire clk,  // 28 MHz
    input wire [7:0] txdata,
    input wire txbegin,
    output wire txbusy,
    output wire [7:0] rxdata,
    output wire rxrecv,
    input wire data_read,
    // RS232 interface
    input wire rx,
    output wire tx,
    output wire rts
    );

    uart_tx transmitter (
        .clk(clk),
        .txdata(txdata),
        .txbegin(txbegin),
        .txbusy(txbusy),
        .tx(tx)
    );

    uart_rx receiver (
        .clk(clk),
        .rxdata(rxdata),
        .rxrecv(rxrecv),
        .data_read(data_read),
        .rx(rx),
        .rts(rts)
    );
endmodule

module uart_tx (
    // CPU interface
    input wire clk,  // 28 MHz
    input wire [7:0] txdata,
    input wire txbegin,
    output wire txbusy,
    // RS232 interface
    output reg tx
    );

    initial tx = 1'b1;

    parameter CLK = 28000000;
    parameter BPS = 115200;
    parameter PERIOD = CLK / BPS;

    parameter
        IDLE  = 2'd0,
        START = 2'd1,
        BIT   = 2'd2,
        STOP  = 2'd3;

    reg [7:0] txdata_reg;
    reg [1:0] state = IDLE;
    reg [15:0] bpscounter;
    reg [2:0] bitcnt;
    reg txbusy_ff = 1'b0;
    assign txbusy = txbusy_ff;

    always @(posedge clk) begin
        if (txbegin == 1'b1 && txbusy_ff == 1'b0 && state == IDLE) begin
            txdata_reg <= txdata;
            txbusy_ff <= 1'b1;
            state <= START;
            bpscounter <= PERIOD;
        end
        if (txbegin == 1'b0 && txbusy_ff == 1'b1) begin
            case (state)
                START:
                    begin
                        tx <= 1'b0;
                        bpscounter <= bpscounter - 16'd1;
                        if (bpscounter == 16'h0000) begin
                            bpscounter <= PERIOD;
                            bitcnt <= 3'd7;
                            state <= BIT;
                        end
                    end
                BIT:
                    begin
                        tx <= txdata_reg[0];
                        bpscounter <= bpscounter - 16'd1;
                        if (bpscounter == 16'h0000) begin
                            txdata_reg <= {1'b0, txdata_reg[7:1]};
                            bpscounter <= PERIOD;
                            bitcnt <= bitcnt - 3'd1;
                            if (bitcnt == 3'd0) begin
                                state <= STOP;
                            end
                        end
                    end
                STOP:
                    begin
                        tx <= 1'b1;
                        bpscounter <= bpscounter - 16'd1;
                        if (bpscounter == 16'h0000) begin
                            bpscounter <= PERIOD;
                            txbusy_ff <= 1'b0;
                            state <= IDLE;
                        end
                    end
                default:
                    begin
                        state <= IDLE;
                        txbusy_ff <= 1'b0;
                    end
            endcase
        end
    end
endmodule

module uart_rx (
    // CPU interface
    input wire clk,  // 28 MHz
    output reg [7:0] rxdata,
    output reg rxrecv,
    input wire data_read,
    // RS232 interface
    input wire rx,
    output reg rts
    );

    initial rxrecv = 1'b0;
     initial rts = 1'b0;

    parameter CLK = 28000000;
    parameter BPS = 115200;
    parameter PERIOD = CLK / BPS;
    parameter HALFPERIOD = PERIOD / 2;

    parameter
        IDLE  = 3'd0,
        START = 3'd1,
        BIT   = 3'd2,
        STOP  = 3'd3,
        WAIT  = 3'd4;

    // Sincronizacin de seales externas
    reg [1:0] rx_ff = 2'b00;
    always @(posedge clk) begin
        rx_ff[1] <= rx_ff[0];
        rx_ff[0] <= rx;
    end
    wire rx_int = rx_ff[1];

    reg [7:0] rxvalues = 8'h00;
    always @(posedge clk) begin
        rxvalues <= {rxvalues[6:0], rx_int};
    end
    wire rx_is_1    = (rxvalues==8'hFF)? 1'b1: 1'b0;
    wire rx_is_0    = (rxvalues==8'h00)? 1'b1: 1'b0;
    wire rx_negedge = (rxvalues==8'hF0)? 1'b1: 1'b0;

    reg [15:0] bpscounter;
    reg [2:0] state = IDLE;
    reg [2:0] bitcnt;

    reg [7:0] rxshiftreg;

    always @(posedge clk) begin
        case (state)
            IDLE:
                begin
                    rxrecv <= 1'b0;
                    if (rx_negedge == 1'b1) begin
                        bpscounter <= PERIOD - 4;  // porque ya hemos perdido 4 ciclos detectando el flanco negativo
                        rts <= 1'b1;
                        state <= START;
                    end
                    else begin
                        rts <= 1'b0;
                    end
                end
            START:
                begin
                    bpscounter <= bpscounter - 8'd1;
                    if (bpscounter == HALFPERIOD) begin
                        if (!rx_is_0) begin  // si no era una seal de START de verdad
                            state <= IDLE;
  //                          rts <= 1'b0;
                        end
                    end
                    else if (bpscounter == 16'h0000) begin
                        bpscounter <= PERIOD;
                        rxshiftreg <= 8'h00;
                        bitcnt <= 3'd7;
                        rxrecv <= 1'b0;
                        state <= BIT;
                    end
                end
            BIT:
                begin
                    bpscounter <= bpscounter - 16'd1;
                    if (bpscounter == HALFPERIOD) begin
                        if (rx_is_1) begin
                            rxshiftreg <= {1'b1, rxshiftreg[7:1]};
                        end
                        else if (rx_is_0) begin
                            rxshiftreg <= {1'b0, rxshiftreg[7:1]};
                        end
                        else begin
                            state <= IDLE;
//                            rts <= 1'b0;
                        end
                    end
                    else if (bpscounter == 16'h0000) begin
                        bitcnt <= bitcnt - 3'd1;
                        bpscounter <= PERIOD;
                        if (bitcnt == 3'd0) begin
                            state <= STOP;
                        end
                    end
                end

//rts en stop: se come 1 de cada dos chars
//rts a mitad de stop o antes: en vez de ok recibo "-" pero hace eco bien
            STOP:
                begin
                    bpscounter <= bpscounter - 16'd1;
                    if (bpscounter == HALFPERIOD) begin
                        if (!rx_is_1) begin  // si no era una seal de STOP de verdad
                            state <= IDLE;
//                            rts <= 1'b0;
                        end
                        else begin
                            rxrecv <= 1'b1;
                            rxdata <= rxshiftreg;
                            state <= WAIT;
                        end
/*
                        else begin
                            rts <= 1'b1;
                        end
*/
                    end
                end
            WAIT:
                begin
                    rxrecv <= 1'b0;
                    if (data_read == 1'b1) begin
                        state <= IDLE;
                    end
                end
            default: state <= IDLE;
        endcase
    end
endmodule
