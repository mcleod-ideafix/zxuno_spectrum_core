`timescale 1ns / 1ps
`default_nettype none

module dma2 (
  input wire clk,
  input wire rst_n,
  input wire [7:0] zxuno_addr,
  input wire regaddr_changed,
  input wire zxuno_regrd,
  input wire zxuno_regwr,
  input wire [7:0] din,
  output reg [7:0] dout,
  output reg oe_n,
  //---- DMA bus -----
  input wire m1_n,
  output reg busrq_n,
  input wire busak_n,
  output reg [15:0] dma_a,
  input wire [7:0] dma_din,
  output reg [7:0] dma_dout,
  output reg dma_mreq_n,
  output reg dma_iorq_n,
  output reg dma_rd_n,
  output reg dma_wr_n   
  );

  parameter
    NODMA      = 3'd0,
    DOBURST    = 3'd1,
    DOTIMED    = 3'd2,
    DOTIMED_2  = 3'd3,
    DOTRANSFER = 3'd4,
    TRANSFER_2 = 3'd5,
    TRANSFER_3 = 3'd6;

  parameter
    DMACTRL = 8'hA0,
    DMASRC  = 8'hA1,
    DMADST  = 8'hA2,
    DMAPRE  = 8'hA3,
    DMALEN  = 8'hA4,
    DMAPROB = 8'hA5,
    DMASTAT = 8'hA6;

  reg [2:0] iocnt = 3'b000;
  reg [1:0] mode = 2'b00;  // 00: apagado, 01: burst sin reinicio, 10: timed, sin reinicio, 11: timed, con reinicio    
  reg [1:0] srcdst = 2'b00; // 00: memoria a memoria, 01: memoria a I/O, 10: I/O a memoria, 11: I/O a I/O
  reg select_addr_to_reach = 1'b0;   // 0: el bit 7 de DMASTAT obedece a la direccion fuente, 1: obedece a la dirección destino
  reg [15:0] src = 16'h0000, dst = 16'h0000;
  reg [15:0] srcidx = 16'h0000, dstidx = 16'h0000;
  reg [15:0] preescaler = 16'h0000;
  reg [15:0] cntpreescaler = 16'h0000;
  reg [15:0] transferlength = 16'h0000;
  reg [15:0] cnttransfers = 16'h0000;
  reg [15:0] addrtoreach = 16'h0000;
  reg [2:0] state = NODMA;
  reg [2:0] returnstate = NODMA;
  reg [7:0] data;
  reg data_received = 1'b0;
  reg addr_is_reached = 1'b0;
  reg hilo = 1'b0;  // flipflop para determinar qué cacho de dato se va a dar en una lectura
  reg read_in_progress = 1'b0;
  initial busrq_n = 1'b1;
  initial dma_mreq_n = 1'b1;
  initial dma_iorq_n = 1'b1;
  initial dma_rd_n = 1'b1;
  initial dma_wr_n = 1'b1;

  // CPU reads DMA registers
  always @* begin
    oe_n = 1'b1;
    dout = 8'hFF;
    if (zxuno_addr == DMACTRL && zxuno_regrd == 1'b1) begin
      dout = {3'b000, select_addr_to_reach, srcdst, mode};
      oe_n = 1'b0;
    end
    else if (zxuno_addr == DMASTAT && zxuno_regrd == 1'b1) begin
      dout = {addr_is_reached,7'b0000000};
      oe_n = 1'b0;
    end
    else if (zxuno_addr == DMASRC && zxuno_regrd == 1'b1) begin
      dout = (hilo)? src[15:8]:src[7:0];
      oe_n = 1'b0;
    end
    else if (zxuno_addr == DMADST && zxuno_regrd == 1'b1) begin
      dout = (hilo)? dst[15:8]:dst[7:0];
      oe_n = 1'b0;
    end
    else if (zxuno_addr == DMAPRE && zxuno_regrd == 1'b1) begin
      dout = (hilo)? preescaler[15:8]:preescaler[7:0];
      oe_n = 1'b0;
    end
    else if (zxuno_addr == DMALEN && zxuno_regrd == 1'b1) begin
      dout = (hilo)? transferlength[15:8]:transferlength[7:0];
      oe_n = 1'b0;
    end    
    else if (zxuno_addr == DMAPROB && zxuno_regrd == 1'b1) begin
      dout = (hilo)? addrtoreach[15:8]:addrtoreach[7:0];
      oe_n = 1'b0;
    end
  end

  // CPU writes DMA registers
  reg nxt_data_received;
  reg [1:0] nxt_mode;
  reg [1:0] nxt_srcdst;      
  reg nxt_select_addr_to_reach;
  reg [15:0] nxt_preescaler, nxt_transferlength, nxt_addrtoreach, nxt_src, nxt_dst, nxt_srcidx, nxt_dstidx, nxt_dma_a;
  reg nxt_hilo;
  reg nxt_read_in_progress;
  reg [2:0] nxt_iocnt;
  reg nxt_addr_is_reached;
  reg [7:0] nxt_data, nxt_dma_dout;
  reg nxt_busrq_n;
  reg nxt_dma_mreq_n;
  reg nxt_dma_iorq_n;
  reg nxt_dma_rd_n;
  reg nxt_dma_wr_n;
  reg [15:0] nxt_cntpreescaler, nxt_cnttransfers;
  reg [2:0] nxt_state;
  reg [2:0] nxt_returnstate;

  always @(posedge clk) begin
    data_received <= nxt_data_received;
    mode <= nxt_mode;
    srcdst <= nxt_srcdst;      
    select_addr_to_reach <= nxt_select_addr_to_reach;
    preescaler <= nxt_preescaler;
    transferlength <= nxt_transferlength;
    addrtoreach <= nxt_addrtoreach;
    src <= nxt_src;
    dst <= nxt_dst;
    srcidx <= nxt_srcidx;
    dstidx <= nxt_dstidx;
    dma_a <= nxt_dma_a;
    hilo <= nxt_hilo;
    read_in_progress <= nxt_read_in_progress;
    iocnt <= nxt_iocnt;
    addr_is_reached <= nxt_addr_is_reached;
    data <= nxt_data;
    dma_dout <= nxt_dma_dout;
    busrq_n <= nxt_busrq_n;
    dma_mreq_n <= nxt_dma_mreq_n;
    dma_iorq_n <= nxt_dma_iorq_n;
    dma_rd_n <= nxt_dma_rd_n;
    dma_wr_n <= nxt_dma_wr_n;
    cntpreescaler <= nxt_cntpreescaler;
    cnttransfers <= nxt_cnttransfers;
    state <= nxt_state;
    returnstate <= nxt_returnstate;
  end
  
  always @* begin
    // defaults
    nxt_data_received = data_received;
    nxt_mode = mode;
    nxt_srcdst = srcdst;      
    nxt_select_addr_to_reach = select_addr_to_reach;
    nxt_preescaler = preescaler;
    nxt_transferlength = transferlength;
    nxt_addrtoreach = addrtoreach;
    nxt_src = src;
    nxt_dst = dst;
    nxt_srcidx = srcidx;
    nxt_dstidx = dstidx;
    nxt_dma_a = dma_a;
    nxt_hilo = hilo;
    nxt_read_in_progress = read_in_progress;
    nxt_iocnt = iocnt;
    nxt_addr_is_reached = addr_is_reached;
    nxt_data = data;
    nxt_dma_dout = dma_dout;
    nxt_busrq_n = busrq_n;
    nxt_dma_mreq_n = dma_mreq_n;
    nxt_dma_iorq_n = dma_iorq_n;
    nxt_dma_rd_n = dma_rd_n;
    nxt_dma_wr_n = dma_wr_n;
    nxt_cntpreescaler = cntpreescaler;
    nxt_cnttransfers = cnttransfers;
    nxt_state = state;
    nxt_returnstate = returnstate;

    nxt_iocnt = iocnt + 3'd1;  // free running 3-bit counter
    if (rst_n == 1'b0) begin
      nxt_data_received = 1'b0;
      nxt_mode = 2'b00;
      nxt_srcdst = 2'b00;      
      nxt_select_addr_to_reach = 1'b0;
      nxt_preescaler = 16'h0000;
      nxt_transferlength = 16'h0000;
      nxt_addrtoreach = 16'h0000;
      nxt_src = 16'h0000;
      nxt_dst = 16'h0000;
      nxt_hilo = 1'b0;
      nxt_read_in_progress = 1'b0;      
    end
    else begin
      if (regaddr_changed == 1'b1) begin
        nxt_hilo = 1'b0;
        nxt_read_in_progress = 1'b0;
      end
      else if (zxuno_regrd == 1'b1 && (zxuno_addr == DMASRC || zxuno_addr == DMADST || zxuno_addr == DMAPRE || zxuno_addr == DMALEN || zxuno_addr == DMAPROB || zxuno_addr == DMASTAT))
        nxt_read_in_progress = 1'b1;
      else if (read_in_progress == 1'b1 && zxuno_regrd == 1'b0) begin
        nxt_hilo = ~hilo;
        nxt_read_in_progress = 1'b0;
        if (zxuno_addr == DMASTAT)
          nxt_addr_is_reached = 1'b0;  // resetear direccion alcanzada después de haber sido leido
      end
      if (zxuno_addr == DMACTRL && zxuno_regwr == 1'b1)
        {nxt_select_addr_to_reach,nxt_srcdst,nxt_mode} = din[4:0];
      else if (zxuno_regwr == 1'b1 && (zxuno_addr == DMASRC || zxuno_addr == DMADST || zxuno_addr == DMAPRE || zxuno_addr == DMALEN || zxuno_addr == DMAPROB)) begin
        nxt_data_received = 1'b1;
        nxt_data = din;
      end
      else if (data_received == 1'b1 && zxuno_regwr == 1'b0) begin  // just after the I/O write operation has finished, 16-bit registers are updated
        case (zxuno_addr)
          DMASRC : nxt_src = {data, src[15:8]};
          DMADST : nxt_dst = {data, dst[15:8]};
          DMAPRE : nxt_preescaler = {data, preescaler[15:8]};
          DMALEN : nxt_transferlength = {data, transferlength[15:8]};
          DMAPROB: nxt_addrtoreach = {data, addrtoreach[15:8]};
        endcase
        nxt_data_received = 1'b0;
      end
    end

    // DMA FSM
    if (rst_n == 1'b0) begin
      nxt_busrq_n = 1'b1;
      nxt_dma_mreq_n = 1'b1;
      nxt_dma_iorq_n = 1'b1;
      nxt_dma_rd_n = 1'b1;
      nxt_dma_wr_n = 1'b1;
      nxt_cntpreescaler = 16'h0000;
      nxt_cnttransfers = 16'h0000;
      nxt_state = NODMA;
    end
    else begin
      if (srcdst == 2'b00 || iocnt == 3'b000) begin  
        if (cntpreescaler == 16'h0000)
          nxt_cntpreescaler = preescaler;
        else
          nxt_cntpreescaler = cntpreescaler + 16'hFFFF ; // -1         
        case (state)
          NODMA:
          begin
            if (mode == 2'b01 && m1_n == 1'b0) begin
              nxt_state = DOBURST;
              nxt_srcidx = src;
              nxt_dstidx = dst;
              nxt_busrq_n = 1'b0;
              nxt_cnttransfers = transferlength;
            end
            else if (mode == 2'b10 || mode == 2'b11) begin
              nxt_state = DOTIMED;
              nxt_srcidx = src;
              nxt_dstidx = dst;
              nxt_cntpreescaler = preescaler;
              nxt_cnttransfers = transferlength;
            end
          end
          
          DOBURST:
          begin
            if (busak_n == 1'b0) begin
              if (cnttransfers == 16'h0000) begin
                nxt_state = NODMA;
                nxt_mode = 2'b00; // clear transfer mode
                nxt_busrq_n = 1'b1;
              end
              else begin
                nxt_state = DOTRANSFER;
                nxt_dma_a = srcidx;
                if (srcdst[1] == 1'b0)
                  nxt_dma_mreq_n = 1'b0;
                else
                  nxt_dma_iorq_n = 1'b0;
                nxt_dma_rd_n = 1'b0;
                nxt_returnstate = DOBURST;
              end
            end
          end
          
          DOTIMED:
          begin
            if (mode == 2'b00) begin
              nxt_state = NODMA;
              nxt_busrq_n = 1'b1;
            end
            else if (cntpreescaler == 16'h0000) begin
              nxt_busrq_n = 1'b0;
              nxt_state = DOTIMED_2;
            end
            else
              nxt_busrq_n = 1'b1;
          end

          DOTIMED_2:
          begin
            if (busak_n == 1'b0) begin
              if (cnttransfers != 16'h0000) begin
                nxt_state = DOTRANSFER;
                nxt_dma_a = srcidx;
                if (srcdst[1] == 1'b0)
                  nxt_dma_mreq_n = 1'b0;
                else
                  nxt_dma_iorq_n = 1'b0;
                nxt_dma_rd_n = 1'b0;
                nxt_returnstate = DOTIMED;
              end
              else if (mode == 2'b11) begin
                nxt_cnttransfers = transferlength;  // reiniciar timed con reinicio
                nxt_srcidx = src;
                nxt_dstidx = dst;
              end
              else begin
                nxt_mode = 2'b00; // fin de timed sin reinicio
                nxt_busrq_n = 1'b1;
                nxt_state = NODMA;
              end
            end
          end
          
          //--- One transfer ---
          DOTRANSFER:
          begin
            nxt_dma_dout = dma_din;
            nxt_dma_rd_n = 1'b1;
            nxt_dma_mreq_n = 1'b1;
            nxt_dma_iorq_n = 1'b1;
            nxt_dma_a = dstidx;
            nxt_state = TRANSFER_2;
            if ((select_addr_to_reach == 1'b0 && srcidx == addrtoreach) || (select_addr_to_reach == 1'b1 && dstidx == addrtoreach))
              nxt_addr_is_reached = 1'b1;
          end
          
          TRANSFER_2:
          begin
            if (srcdst[0] == 1'b0) begin
              nxt_dma_mreq_n = 1'b0;
            end
            else begin
              nxt_dma_iorq_n = 1'b0;
            end
            nxt_dma_wr_n = 1'b0;
            nxt_state = TRANSFER_3;
          end
                  
          TRANSFER_3:
          begin
            nxt_dma_mreq_n = 1'b1;
            nxt_dma_iorq_n = 1'b1;
            nxt_dma_wr_n = 1'b1;
            nxt_cnttransfers = cnttransfers + 16'hFFFF; // -1
            if (srcdst[1] == 1'b0)
                nxt_srcidx = srcidx + 16'd1;
            if (srcdst[0] == 1'b0)
                nxt_dstidx = dstidx + 16'd1;
            nxt_state = returnstate;
          end
        endcase
      end
    end
  end    
endmodule
