//    This file is part of the ZXUNO Spectrum core. 
//    Creation date is UNKNOWN by Miguel Angel Rodriguez Jodar
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

module multiboot (
    input wire clk,
    //input wire clk_icap,   // WARNING: this clock must not be greater than 20MHz (50ns period)
    input wire rst_n,
    input wire [7:0] zxuno_addr,
    input wire regaddr_changed,
    input wire zxuno_regrd,
    input wire zxuno_regwr,
    input wire [7:0] din,
    output reg [7:0] dout,
    output reg oe_n
    );
    
`include "../common/config.vh"
              
    reg [23:0] spi_addr = 24'h058000;  // default value
    reg writting_to_spi_addr = 1'b0;
    reg writting_to_bootcore = 1'b0;
    reg boot_core = 1'b0;

    reg reading_from_spi_addr = 1'b0;
    reg [1:0] spi_addr_chunk = 2'b00; // which part of COREADDR to output
    reg [7:0] addrout = 8'h00;
    
    always @* begin
      dout = 8'hFF;
      oe_n = 1'b1;
      if (zxuno_addr == ADDR_COREADDR && zxuno_regrd ==1'b1) begin
        dout = addrout;
        oe_n = 1'b0;
      end
    end  

    always @(posedge clk) begin
        if (rst_n == 1'b0 || (regaddr_changed && zxuno_addr == ADDR_COREADDR)) begin
          writting_to_spi_addr <= 1'b0;
          writting_to_bootcore <= 1'b0;
          reading_from_spi_addr <= 1'b0;
          spi_addr_chunk <= 2'b00;
          boot_core <= 1'b0;
        end
        else begin
            if (zxuno_addr == ADDR_COREADDR) begin
              if (zxuno_regwr == 1'b1 && writting_to_spi_addr == 1'b0) begin
                  spi_addr <= {spi_addr[15:0], din};
                  writting_to_spi_addr <= 1'b1;
              end
              if (zxuno_regwr == 1'b0) begin
                  writting_to_spi_addr <= 1'b0;
              end
              if (zxuno_regrd == 1'b1 && reading_from_spi_addr == 1'b0) begin
                addrout <= (spi_addr_chunk == 2'b00)? spi_addr[23:16] :
                           (spi_addr_chunk == 2'b01)? spi_addr[15:8] :
                                                      spi_addr[7:0];
                spi_addr_chunk <= (spi_addr_chunk == 2'b10)? 2'b00 : spi_addr_chunk + 2'b01;
                reading_from_spi_addr <= 1'b1;
              end   
              if (zxuno_regrd == 1'b0) begin
                reading_from_spi_addr <= 1'b0;
              end                  
            end
            else begin
              writting_to_spi_addr <= 1'b0;
              reading_from_spi_addr <= 1'b0;
            end
            
            if (zxuno_addr == ADDR_COREBOOT) begin
                if (zxuno_regwr == 1'b1 && din[0] == 1'b1 && writting_to_bootcore == 1'b0) begin
                    boot_core <= 1'b1;
                    writting_to_bootcore <= 1'b1;
                end
//                if (writting_to_bootcore == 1'b1) begin
//                    boot_core <= 1'b0;
//                end
                if (zxuno_regwr == 1'b0) begin
                    writting_to_bootcore <= 1'b0;
                    boot_core <= 1'b0;                    
                end
            end
            else begin
                boot_core <= 1'b0;
                writting_to_bootcore <= 1'b0;
            end
        end
    end

    reg regclkicap = 1'b0;
	 wire clkicap;
	 always @(posedge clk)
	   regclkicap <= ~regclkicap;
	 BUFG bufclkicap (.I(regclkicap), .O(clkicap) );

    reg [4:0] q = 5'b00000;
    always @(posedge clkicap)
      q <= {q[3:0], boot_core};
    wire reboot_ff = (q == 5'b10000);

    multiboot_spartan6 hacer_multiboot (
        .CLK(clkicap),
        .MBT_RESET(1'b0),
        .MBT_REBOOT(reboot_ff),
        .spi_addr(spi_addr)
    );
endmodule            


// This module is not covered by the GPL license.    
module multiboot_spartan6 (
    input wire CLK,
    input wire MBT_RESET,
    input wire MBT_REBOOT,
    input wire [23:0] spi_addr
  );

reg  [15:0] icap_din;
reg         icap_ce;
reg         icap_wr;

reg  [15:0] ff_icap_din_reversed;
reg         ff_icap_ce;
reg         ff_icap_wr;


  ICAP_SPARTAN6 ICAP_SPARTAN6_inst (
  
    .CE        (ff_icap_ce),   // Clock enable input
    .CLK       (CLK),         // Clock input
    .I         (ff_icap_din_reversed),  // 16-bit data input
    .WRITE     (ff_icap_wr)    // Write input
  );


//  -------------------------------------------------
//  --  State Machine for ICAP_SPARTAN6 MultiBoot  --
//  -------------------------------------------------


parameter         IDLE     = 0, 
                  SYNC_H   = 1, 
                  SYNC_L   = 2, 
                  
                  CWD_H    = 3,  
                  CWD_L    = 4,  
                                 
                  GEN1_H   = 5,  
                  GEN1_L   = 6,  
                                 
                  GEN2_H   = 7,  
                  GEN2_L   = 8,  
                                 
                  GEN3_H   = 9,  
                  GEN3_L   = 10, 
                                 
                  GEN4_H   = 11, 
                  GEN4_L   = 12, 
                                 
                  GEN5_H   = 13, 
                  GEN5_L   = 14, 
                                 
                  NUL_H    = 15, 
                  NUL_L    = 16, 
                                 
                  MOD_H    = 17, 
                  MOD_L    = 18, 
                                 
                  HCO_H    = 19, 
                  HCO_L    = 20, 
                                 
                  RBT_H    = 21, 
                  RBT_L    = 22, 
                  
                  NOOP_0   = 23, 
                  NOOP_1   = 24,
                  NOOP_2   = 25,
                  NOOP_3   = 26;
                  
                   
reg [4:0]     state;
reg [4:0]     next_state;


always @*
   begin: COMB

      case (state)
      
         IDLE:
            begin
               if (MBT_REBOOT)
                  begin
                     next_state  = SYNC_H;
                     icap_ce     = 0;
                     icap_wr     = 0;
                     icap_din    = 16'hAA99;  // Sync word 1 
                  end
               else
                  begin
                     next_state  = IDLE;
                     icap_ce     = 1;
                     icap_wr     = 1;
                     icap_din    = 16'hFFFF;  // Null 
                  end
            end
            
         SYNC_H:
            begin
               next_state  = SYNC_L;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h5566;    // Sync word 2
            end

         SYNC_L:
            begin
               next_state  = NUL_H;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h30A1;    //  Write to Command Register....
            end

        NUL_H:
            begin
              // next_state  = NUL_L;
	       next_state  = GEN1_H;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h0000;   //  Null Command issued....  value = 0x0000
            end

//Q

         GEN1_H:
            begin
               next_state  = GEN1_L;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h3261;    //  Escritura a reg GENERAL_1 (bit boot en caliente)
            end

        GEN1_L:
            begin
               next_state  = GEN2_H;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = spi_addr[15:0]; //16'hC000;   //  dreccion SPI BAJA
            end

         GEN2_H:
            begin
               next_state  = GEN2_L;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h3281;   //  Escritura a reg GENERAL_2
            end

        GEN2_L:
            begin
               next_state  = MOD_H;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = {8'h6B, spi_addr[23:16]}; // 16'h030A;   //  03 lectura SPI opcode + direccion SPI ALTA (03 = 1x, 6B = 4x)
            end
	
///////	Registro MODE (para carga a 4x tras reboot)

        MOD_H:
            begin
               next_state  = MOD_L;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h3301;   //  Escritura a reg MODE
            end

        MOD_L:
            begin
               next_state  = NUL_L;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h3100; // Activamos bit de lectura a modo 4x en el proceso de Config
            end				
/////

        NUL_L:
            begin
               next_state  = RBT_H;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h30A1;    //  Write to Command Register....
            end

        RBT_H:
            begin
               next_state  = RBT_L;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h000E;    // REBOOT Command 0x000E
            end

//--------------------

        RBT_L:
            begin
               next_state  = NOOP_0;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h2000;    //  NOOP
            end

        NOOP_0:
            begin
               next_state  = NOOP_1;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h2000;    // NOOP
            end

        NOOP_1:
            begin
               next_state  = NOOP_2;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h2000;    // NOOP
            end

        NOOP_2:
            begin
               next_state  = NOOP_3;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h2000;    // NOOP
            end

//--------------------

        NOOP_3:
            begin
               next_state  = IDLE;
               icap_ce     = 1;
               icap_wr     = 1;
               icap_din    = 16'h1111;    // NULL value
            end
          
        default:
            begin
               next_state  = IDLE;
               icap_ce     = 1;
               icap_wr     = 1;
               icap_din    = 16'h1111;    //  16'h1111"
            end

      endcase
   end

always @(posedge CLK)

   begin:   SEQ
      if (MBT_RESET)
         state <= IDLE;
      else
         state <= next_state;
   end


always @(posedge CLK)

   begin:   ICAP_FF
   
        ff_icap_din_reversed[0]  <= icap_din[7];   //need to reverse bits to ICAP module since D0 bit is read first
        ff_icap_din_reversed[1]  <= icap_din[6]; 
        ff_icap_din_reversed[2]  <= icap_din[5]; 
        ff_icap_din_reversed[3]  <= icap_din[4]; 
        ff_icap_din_reversed[4]  <= icap_din[3]; 
        ff_icap_din_reversed[5]  <= icap_din[2]; 
        ff_icap_din_reversed[6]  <= icap_din[1]; 
        ff_icap_din_reversed[7]  <= icap_din[0]; 
        ff_icap_din_reversed[8]  <= icap_din[15];
        ff_icap_din_reversed[9]  <= icap_din[14];
        ff_icap_din_reversed[10] <= icap_din[13];
        ff_icap_din_reversed[11] <= icap_din[12];
        ff_icap_din_reversed[12] <= icap_din[11];
        ff_icap_din_reversed[13] <= icap_din[10];
        ff_icap_din_reversed[14] <= icap_din[9]; 
        ff_icap_din_reversed[15] <= icap_din[8]; 
        
        ff_icap_ce  <= icap_ce;
        ff_icap_wr  <= icap_wr;
   end  
        
        
endmodule
