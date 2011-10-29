//-----------------------------------------------------------------------------
// iic_init.v   
//-----------------------------------------------------------------------------
//  ***************************************************************************
//  ** DISCLAIMER OF LIABILITY                                               **
//  **                                                                       **
//  **  This file contains proprietary and confidential information of       **
//  **  Xilinx, Inc. ("Xilinx"), that is distributed under a license         **
//  **  from Xilinx, and may be used, copied and/or disclosed only           **
//  **  pursuant to the terms of a valid license agreement with Xilinx.      **
//  **                                                                       **
//  **  XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION                **
//  **  ("MATERIALS") "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER           **
//  **  EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING WITHOUT                  **
//  **  LIMITATION, ANY WARRANTY WITH RESPECT TO NONINFRINGEMENT,            **
//  **  MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. Xilinx        **
//  **  does not warrant that functions included in the Materials will       **
//  **  meet the requirements of Licensee, or that the operation of the      **
//  **  Materials will be uninterrupted or error-free, or that defects       **
//  **  in the Materials will be corrected. Furthermore, Xilinx does         **
//  **  not warrant or make any representations regarding use, or the        **
//  **  results of the use, of the Materials in terms of correctness,        **
//  **  accuracy, reliability or otherwise.                                  **
//  **                                                                       **
//  **  Xilinx products are not designed or intended to be fail-safe,        **
//  **  or for use in any application requiring fail-safe performance,       **
//  **  such as life-support or safety devices or systems, Class III         **
//  **  medical devices, nuclear facilities, applications related to         **
//  **  the deployment of airbags, or any other applications that could      **
//  **  lead to death, personal injury or severe property or                 **
//  **  environmental damage (individually and collectively, "critical       **
//  **  applications"). Customer assumes the sole risk and liability         **
//  **  of any use of Xilinx products in critical applications,              **
//  **  subject only to applicable laws and regulations governing            **
//  **  limitations on product liability.                                    **
//  **                                                                       **
//  **  Copyright 2008, 2009 Xilinx, Inc.                                    **
//  **  All rights reserved.                                                 **
//  **                                                                       **
//  **  This disclaimer and copyright notice must be retained as part        **
//  **  of this file at all times.                                           **
//  ***************************************************************************
//-----------------------------------------------------------------------------
// Filename:        iic_init.v
// Version:         v2.01a
// Description:     This module consists of logic to configur the Chrontel 
//                  CH-7301 DVI transmitter chip through I2C interface.
//
// Verilog-Standard: Verilog'2001
//-----------------------------------------------------------------------------
// Structure:   
//                  xps_tft.vhd
//                     -- plbv46_master_burst.vhd               
//                     -- plbv46_slave_single.vhd
//                     -- tft_controller.v
//                            -- tft_control.v
//                            -- line_buffer.v
//                            -- v_sync.v
//                            -- h_sync.v
//                            -- slave_register.v
//                            -- tft_interface.v
//                                -- iic_init.v
//-----------------------------------------------------------------------------
// Author:          PVK
// History:
//   PVK           06/10/08    First Version
// ^^^^^^
//    This module is included in the design only if DVI interface is selected.    
// ~~~~~~~~
//  PVK             07/01/09    v2.00.a
// ^^^^^^^
//  Added new interrupt port (IP2INTC_Irpt) for the Vsync pulse. Core latches 
//  video memory address from the address register (AR) on every back porch.
//  Changed the DDR alignment for ODDR2 for Spartan6 DVI mode.
// ~~~~~~~~~
//  PVK             09/15/09    v2.01.a
// ^^^^^^^
//  Added flexibilty for Chrontel Chip configuration through register 
//  interface.
// ~~~~~~~~~
//-----------------------------------------------------------------------------
// Naming Conventions:
//      active low signals:                     "*_n"
//      clock signals:                          "clk", "clk_div#", "clk_#x" 
//      reset signals:                          "rst", "rst_n" 
//      parameters:                             "C_*" 
//      user defined types:                     "*_TYPE" 
//      state machine next state:               "*_ns" 
//      state machine current state:            "*_cs" 
//      combinatorial signals:                  "*_com" 
//      pipelined or register delay signals:    "*_d#" 
//      counter signals:                        "*cnt*"
//      clock enable signals:                   "*_ce" 
//      internal version of output port         "*_i"
//      device pins:                            "*_pin" 
//      ports:                                  - Names begin with Uppercase 
//      component instantiations:               "<MODULE>I_<#|FUNC>
//-----------------------------------------------------------------------------

///////////////////////////////////////////////////////////////////////////////
// Module Declaration
///////////////////////////////////////////////////////////////////////////////
 `timescale 1 ps / 1 ps
module iic_init( 
  Clk,                          // Clock input
  Reset_n,                      // Reset input
  SDA,                          // I2C data
  SCL,                          // I2C clock
  Done,                         // I2C configuration done
  IIC_xfer_done,                // IIC configuration done
  TFT_iic_xfer,                 // IIC configuration request
  TFT_iic_reg_addr,             // IIC register address
  TFT_iic_reg_data              // IIC register data
  );

///////////////////////////////////////////////////////////////////////////////
// Parameter Declarations
///////////////////////////////////////////////////////////////////////////////
                 
parameter C_I2C_SLAVE_ADDR = 7'b1110110;

parameter CLK_RATE_MHZ = 100,  
          SCK_PERIOD_US = 30, 
          TRANSITION_CYCLE = (CLK_RATE_MHZ * SCK_PERIOD_US) / 2,
          TRANSITION_CYCLE_MSB = 11;  



input          Clk;
input          Reset_n;
inout          SDA;
inout          SCL;
output         Done;
output         IIC_xfer_done;
input          TFT_iic_xfer;
input [0:7]    TFT_iic_reg_addr;
input [0:7]    TFT_iic_reg_data;

  
          
localparam    IDLE           = 3'd0,
              INIT           = 3'd1,
              START          = 3'd2,
              CLK_FALL       = 3'd3,
              SETUP          = 3'd4,
              CLK_RISE       = 3'd5,
              WAIT_IIC       = 3'd6,
              XFER_DONE      = 3'd7,
              START_BIT      = 1'b1,
              ACK            = 1'b1,
              WRITE          = 1'b0,
              REG_ADDR0      = 8'h49,
              REG_ADDR1      = 8'h21,
              REG_ADDR2      = 8'h33,
              REG_ADDR3      = 8'h34,
              REG_ADDR4      = 8'h36,
              DATA0          = 8'hC0,
              DATA1          = 8'h09,
              DATA2a         = 8'h06,
              DATA3a         = 8'h26,
              DATA4a         = 8'hA0,
              DATA2b         = 8'h08,
              DATA3b         = 8'h16,
              DATA4b         = 8'h60,
              STOP_BIT       = 1'b0,            
              SDA_BUFFER_MSB = 27; 
          
wire [6:0]    SLAVE_ADDR = C_I2C_SLAVE_ADDR ;
          

reg                          SDA_out; 
reg                          SCL_out;  
reg [TRANSITION_CYCLE_MSB:0] cycle_count;
reg [2:0]                    c_state;
reg [2:0]                    n_state;
reg                          Done;   
reg [2:0]                    write_count;
reg [31:0]                   bit_count;
reg [SDA_BUFFER_MSB:0]       SDA_BUFFER;
wire                         transition; 
reg                          IIC_xfer_done;


// Generate I2C clock and data 
always @ (posedge Clk) 
begin : I2C_CLK_DATA
    if (~Reset_n || c_state == IDLE )
      begin
        SDA_out <= 1'b1;
        SCL_out <= 1'b1;
      end
    else if (c_state == INIT && transition) 
      begin 
        SDA_out <= 1'b0;
      end
    else if (c_state == SETUP) 
      begin
        SDA_out <= SDA_BUFFER[SDA_BUFFER_MSB];
      end
    else if (c_state == CLK_RISE && cycle_count == TRANSITION_CYCLE/2 
                                 && bit_count == SDA_BUFFER_MSB) 
      begin
        SDA_out <= 1'b1;
      end
    else if (c_state == CLK_FALL) 
      begin
        SCL_out <= 1'b0;
      end
    
    else if (c_state == CLK_RISE) 
      begin
        SCL_out <= 1'b1;
      end
end

assign SDA = SDA_out;
assign SCL = SCL_out;
                        

// Fill the SDA buffer 
always @ (posedge Clk) 
begin : SDA_BUF
    //reset or end condition
    if(~Reset_n) 
      begin
        SDA_BUFFER  <= {SLAVE_ADDR,WRITE,ACK,REG_ADDR0,ACK,DATA0,ACK,STOP_BIT};
        cycle_count <= 0;
      end
    //setup sda for sck rise
    else if ( c_state==SETUP && cycle_count==TRANSITION_CYCLE)
      begin
        SDA_BUFFER <= {SDA_BUFFER[SDA_BUFFER_MSB-1:0],1'b0};
        cycle_count <= 0; 
      end
    //reset count at end of state
    else if ( cycle_count==TRANSITION_CYCLE)
       cycle_count <= 0; 
    //reset sda_buffer   
    else if (c_state==INIT && TFT_iic_xfer==1'b1) 
      begin
       SDA_BUFFER <= {SLAVE_ADDR,WRITE,ACK,TFT_iic_reg_addr,
                                       ACK,TFT_iic_reg_data, ACK,STOP_BIT};
       cycle_count <= cycle_count+1;
      end   
    else if (c_state==WAIT_IIC )
      begin
        case(write_count)
          0:SDA_BUFFER <= {SLAVE_ADDR,WRITE,ACK,REG_ADDR1,ACK,DATA1, 
                                                          ACK,STOP_BIT};
          1:SDA_BUFFER <= {SLAVE_ADDR,WRITE,ACK,REG_ADDR2,ACK,DATA2b,
                                                          ACK,STOP_BIT};
          2:SDA_BUFFER <= {SLAVE_ADDR,WRITE,ACK,REG_ADDR3,ACK,DATA3b,
                                                          ACK,STOP_BIT};
          3:SDA_BUFFER <= {SLAVE_ADDR,WRITE,ACK,REG_ADDR4,ACK,DATA4b,
                                                          ACK,STOP_BIT};
        default: SDA_BUFFER <=28'dx;
        endcase 
        cycle_count <= cycle_count+1;
      end
    else
      cycle_count <= cycle_count+1;
end


// Generate write_count signal
always @ (posedge Clk)
begin : GEN_WRITE_CNT
 if(~Reset_n)
   write_count<=3'd0;
 else if (c_state == WAIT_IIC && cycle_count == TRANSITION_CYCLE && IIC_xfer_done==1'b0 )
   write_count <= write_count+1;
end    

// Transaction done signal                        
always @ (posedge Clk) 
begin : TRANS_DONE
    if(~Reset_n)
      Done <= 1'b0;
    else if (c_state == IDLE)
      Done <= 1'b1;
end
 
       
// Generate bit_count signal
always @ (posedge Clk) 
begin : BIT_CNT
    if(~Reset_n || (c_state == WAIT_IIC)) 
       bit_count <= 0;
    else if ( c_state == CLK_RISE && cycle_count == TRANSITION_CYCLE)
       bit_count <= bit_count+1;
end    

// Next state block
always @ (posedge Clk) 
begin : NEXT_STATE
    if(~Reset_n)
       c_state <= INIT;
    else 
       c_state <= n_state;
end    

// generate transition for I2C
assign transition = (cycle_count == TRANSITION_CYCLE); 
              
//Next state              
//always @ (*) 
always @ (Reset_n, TFT_iic_xfer, transition, bit_count, write_count,
          c_state) 
begin : I2C_SM_CMB
   case(c_state) 
       //////////////////////////////////////////////////////////////
       //  IDLE STATE
       //////////////////////////////////////////////////////////////
       IDLE: begin
           if(~Reset_n | TFT_iic_xfer) 
             n_state = INIT;
           else 
             n_state = IDLE;
           IIC_xfer_done = 1'b0;

       end
       //////////////////////////////////////////////////////////////
       //  INIT STATE
       //////////////////////////////////////////////////////////////
       INIT: begin
          if (transition) 
            n_state = START;
          else 
            n_state = INIT;
          IIC_xfer_done = 1'b0;
       end
       //////////////////////////////////////////////////////////////
       //  START STATE
       //////////////////////////////////////////////////////////////
       START: begin
          if( transition) 
            n_state = CLK_FALL;
          else 
            n_state = START;
          IIC_xfer_done = 1'b0;
       end
       //////////////////////////////////////////////////////////////
       //  CLK_FALL STATE
       //////////////////////////////////////////////////////////////
       CLK_FALL: begin
          if( transition) 
            n_state = SETUP;
          else 
            n_state = CLK_FALL;
          IIC_xfer_done = 1'b0;
       end
       //////////////////////////////////////////////////////////////
       //  SETUP STATE
       //////////////////////////////////////////////////////////////
       SETUP: begin
          if( transition) 
            n_state = CLK_RISE;
          else 
            n_state = SETUP;
          IIC_xfer_done = 1'b0;
       end
       //////////////////////////////////////////////////////////////
       //  CLK_RISE STATE
       //////////////////////////////////////////////////////////////
       CLK_RISE: begin
          if( transition && bit_count == SDA_BUFFER_MSB) 
            n_state = WAIT_IIC;
          else if (transition )
            n_state = CLK_FALL;  
          else 
            n_state = CLK_RISE;
          IIC_xfer_done = 1'b0;
       end  
       //////////////////////////////////////////////////////////////
       //  WAIT_IIC STATE
       //////////////////////////////////////////////////////////////
       WAIT_IIC: begin
          IIC_xfer_done = 1'b0;          
          if((transition && write_count <= 3'd3))
            begin
              n_state = INIT;
            end
          else if (transition ) 
            begin
              n_state = XFER_DONE;
            end  
          else 
            begin 
              n_state = WAIT_IIC;
            end  
         end 

       //////////////////////////////////////////////////////////////
       //  XFER_DONE STATE
       //////////////////////////////////////////////////////////////
       XFER_DONE: begin
          
          IIC_xfer_done = 1'b1;
          
          if(transition)
              n_state = IDLE;
          else 
              n_state = XFER_DONE;
         end 

       default: n_state = IDLE;


     
   endcase
end


endmodule
