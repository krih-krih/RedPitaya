/**
 * $Id: red_pitaya_asg_ch.v 1271 2014-02-25 12:32:34Z matej.oblak $
 *
 * @brief Red Pitaya ASG submodule. Holds table and FSM for one channel.
 *
 * @Author Matej Oblak
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in Verilog hardware description language (HDL).
 * Please visit http://en.wikipedia.org/wiki/Verilog
 * for more details on the language used herein.
 */



/**
 * GENERAL DESCRIPTION:
 *
 * Arbitrary signal generator takes data stored in buffer and sends them to DAC.
 *
 *
 *                /-----\         /--------\
 *   SW --------> | BUF | ------> | kx + o | ---> DAC DAT
 *          |     \-----/         \--------/
 *          |        ^
 *          |        |
 *          |     /-----\
 *          ----> |     |
 *                | FSM | ------> trigger notification
 *   trigger ---> |     |
 *                \-----/
 *
 *
 * Submodule for ASG which hold buffer data and control registers for one channel.
 * 
 */



module red_pitaya_asg_ch
#(
   parameter RSZ = 14
)
(
   // DAC
   output reg [ 14-1: 0] dac_o           ,  //!< dac data output
   input                 dac_clk_i       ,  //!< dac clock
   input                 dac_rstn_i      ,  //!< dac reset - active low

   // trigger
   input                 trig_sw_i       ,  //!< software trigger
   input                 trig_ext_i      ,  //!< external trigger
   input      [  3-1: 0] trig_src_i      ,  //!< trigger source selector
   output                trig_done_o     ,  //!< trigger event

/* legacy */input buf_we_i,
/* legacy */input [14-1:0] buf_addr_i,
/* legacy */input [14-1:0] buf_wdata_i,
/* legacy */output reg [14-1:0] buf_rdata_o,
/* legacy */output reg [RSZ-1:0] buf_rpnt_o,

   // configuration
   input     [RSZ+15: 0] set_size_i      ,  //!< set table data size
   input     [RSZ+15: 0] set_step_i      ,  //!< set pointer step
   input     [RSZ+15: 0] set_ofs_i       ,  //!< set reset offset
   input                 set_rst_i       ,  //!< set FSM to reset
   input                 set_once_i      ,  //!< set only once
   input                 set_wrap_i      ,  //!< set wrap enable
   input     [  14-1: 0] set_amp_i       ,  //!< set amplitude scale
   input     [  14-1: 0] set_dc_i        ,  //!< set output offset
   input                 set_zero_i      ,  //!< set output to zero

    // DAC data buffer
    input               dacbuf_clk_i    ,   // clock
    input               dacbuf_rstn_i   ,   // reset
    input               dacbuf_select_i ,   // channel buffer select
    output  [    2-1:0] dacbuf_ready_o  ,   // buffer ready [0]: 0k-8k, [1]: 8k-16k
    output  [    2-1:0] dacbuf_close_o  ,   // buffer deready [0]: 0k-8k, [1]: 8k-16k
    input   [   12-1:0] dacbuf_waddr_i  ,   // buffer write address
    input   [   64-1:0] dacbuf_wdata_i  ,   // buffer write data
    input               dacbuf_valid_i  ,   // buffer data valid
    // buffer configuration
    input   [  RSZ-2:0] dacbuf_rdymx_i      // last read address where it's ok to start filling opposite buffer
);



//---------------------------------------------------------------------------------
//
//  DAC buffer RAM

/*
wire  [  16-1: 0] dac_rdat  ;
reg   [RSZ+15: 0] dac_pnt   ; // read pointer

dac_buffer i_dac_buffer (
    .clka   (dacbuf_clk_i       ),
    .ena    (dacbuf_select_i    ),
    .wea    (dacbuf_valid_i     ),
    .addra  (dacbuf_waddr_i     ),
    .dina   (dacbuf_wdata_i     ),
    .clkb   (dac_clk_i          ),
    .rstb   (!dac_rstn_i        ),
    .enb    (1'b1               ),
    .addrb  (dac_pnt[16+:RSZ]   ),
    .doutb  (dac_rdat           )
);

(* ASYNC_REG="true" *)  reg     [2:0]   addr_sync;
(* ASYNC_REG="true" *)  reg     [1:0]   cls0_sync;
(* ASYNC_REG="true" *)  reg     [1:0]   cls8_sync;
wire    read_max    = (dac_pnt[16+:RSZ-1] > dacbuf_rdymx_i);

always @(posedge dacbuf_clk_i) begin
    if (!dacbuf_rstn_i) begin
        addr_sync <= 3'b000;
        cls0_sync <= 2'b00;
        cls8_sync <= 2'b00;
    end else begin
        addr_sync <= {addr_sync[1:0],dac_pnt[RSZ-1+16]};
        cls0_sync <= {cls0_sync[0],!dac_pnt[RSZ-1+16] | read_max};
        cls8_sync <= {cls8_sync[0], dac_pnt[RSZ-1+16] | read_max};
    end
end

assign dacbuf_ready_o[0] = (addr_sync[1] ^ addr_sync[2]) &  addr_sync[1];
assign dacbuf_ready_o[1] = (addr_sync[1] ^ addr_sync[2]) & !addr_sync[1];
assign dacbuf_close_o[0] = cls0_sync[1];
assign dacbuf_close_o[1] = cls8_sync[1];
*/

/* legacy */reg [14-1:0] dac_buf [0:(1<<RSZ)-1];
/* legacy */reg [14-1:0] dac_rd;
/* legacy */reg [14-1:0] dac_rdat;
/* legacy */reg [RSZ-1:0] dac_rp;
/* legacy */reg [RSZ+15:0] dac_pnt;
/* legacy */reg dac_do;
/* legacy */reg dac_trig;
/* legacy */wire [RSZ+16:0] dac_npnt;
/* legacy */always @(posedge dac_clk_i) begin
/* legacy */  buf_rpnt_o <= dac_pnt[RSZ+15:16];
/* legacy */  dac_rp <= dac_pnt[RSZ+15:16];
/* legacy */  dac_rd <= dac_buf[dac_rp];
/* legacy */  dac_rdat <= dac_rd;
/* legacy */end
/* legacy */always @(posedge dac_clk_i) begin
/* legacy */  if (buf_we_i)
/* legacy */    dac_buf[buf_addr_i] <= buf_wdata_i[14-1:0];
/* legacy */end


// scale and offset
reg   [  28-1: 0] dac_mult  ;
reg   [  15-1: 0] dac_sum   ;

always @(posedge dac_clk_i) begin
   dac_mult <= $signed(dac_rdat[14-1:0]) * $signed({1'b0,set_amp_i}) ;
   dac_sum  <= $signed(dac_mult[28-1:13]) + $signed(set_dc_i) ;

   if (set_zero_i)
      dac_o <= 14'h0 ;
   else if ($signed(dac_sum[15-1:0]) > $signed(14'h1FFF)) // positive saturation
      dac_o <= 14'h1FFF ;
   else if ($signed(dac_sum[15-1:0]) < $signed(14'h2000)) // negative saturation
      dac_o <= 14'h2000 ;
   else
      dac_o <= dac_sum[13:0] ;
end




//---------------------------------------------------------------------------------
//
//  read pointer & state machine

/*
reg               dac_do    ;
reg               dac_trig  ;
wire  [RSZ+16: 0] dac_npnt  ; // next read pointer
*/
/* legacy */wire              ext_trig_p       ;
/* legacy */wire              ext_trig_n       ;

always @(posedge dac_clk_i) begin
   if (dac_rstn_i == 1'b0) begin
      dac_do   <= 1'b0 ;
      dac_pnt  <= {RSZ+16{1'b0}} ;
      dac_trig <= 1'h0 ;
   end
   else begin

      case (trig_src_i)
          3'd1 : dac_trig <= trig_sw_i   ; // sw
          3'd2 : dac_trig <= ext_trig_p  ; // external positive edge
          3'd3 : dac_trig <= ext_trig_n  ; // external negative edge
       default : dac_trig <= 1'b0        ;
      endcase


      if (dac_trig && !set_rst_i)
         dac_do <= 1'b1 ;
      else if (set_rst_i || (set_once_i && (dac_npnt >= {1'b0,set_size_i})) )
         dac_do <= 1'b0 ;


      if (set_rst_i || (dac_trig && !dac_do)) // manual reset or start
         dac_pnt <= set_ofs_i ;
      else if (dac_do && !set_once_i && !set_wrap_i && (dac_npnt > {1'b0,set_size_i}) ) //go to start
         dac_pnt <= set_ofs_i ;
      else if (dac_do && !set_once_i &&  set_wrap_i && (dac_npnt > {1'b0,set_size_i}) ) //wrap
         dac_pnt <= dac_npnt - {1'b0,set_size_i} - 'h10000 ; //transfer difference into next cycle
      else if (dac_do) //normal increase
         dac_pnt <= dac_npnt[RSZ+15:0] ;
   end
end

assign dac_npnt = dac_pnt + set_step_i;
assign trig_done_o = dac_trig ;





//---------------------------------------------------------------------------------
//
//  External trigger

reg  [  3-1: 0] ext_trig_in    ;
reg  [  2-1: 0] ext_trig_dp    ;
reg  [  2-1: 0] ext_trig_dn    ;
reg  [ 20-1: 0] ext_trig_debp  ;
reg  [ 20-1: 0] ext_trig_debn  ;

always @(posedge dac_clk_i) begin
   if (dac_rstn_i == 1'b0) begin
      ext_trig_in   <=  3'h0 ;
      ext_trig_dp   <=  2'h0 ;
      ext_trig_dn   <=  2'h0 ;
      ext_trig_debp <= 20'h0 ;
      ext_trig_debn <= 20'h0 ;
   end
   else begin
      //----------- External trigger
      // synchronize FFs
      ext_trig_in <= {ext_trig_in[1:0],trig_ext_i} ;

      // look for input changes
      if ((ext_trig_debp == 20'h0) && (ext_trig_in[1] && !ext_trig_in[2]))
         ext_trig_debp <= 20'd62500 ; // ~0.5ms
      else if (ext_trig_debp != 20'h0)
         ext_trig_debp <= ext_trig_debp - 20'd1 ;

      if ((ext_trig_debn == 20'h0) && (!ext_trig_in[1] && ext_trig_in[2]))
         ext_trig_debn <= 20'd62500 ; // ~0.5ms
      else if (ext_trig_debn != 20'h0)
         ext_trig_debn <= ext_trig_debn - 20'd1 ;

      // update output values
      ext_trig_dp[1] <= ext_trig_dp[0] ;
      if (ext_trig_debp == 20'h0)
         ext_trig_dp[0] <= ext_trig_in[1] ;

      ext_trig_dn[1] <= ext_trig_dn[0] ;
      if (ext_trig_debn == 20'h0)
         ext_trig_dn[0] <= ext_trig_in[1] ;

   end
end

assign ext_trig_p = (ext_trig_dp == 2'b01) ;
assign ext_trig_n = (ext_trig_dn == 2'b10) ;




endmodule

