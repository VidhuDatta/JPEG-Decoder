//-----------------------------------------------------------------
//                      Baseline JPEG Decoder
//                             V0.1
//                       Ultra-Embedded.com
//                        Copyright 2020
//
//                   admin@ultra-embedded.com
//-----------------------------------------------------------------
//                      License: Apache 2.0
// This IP can be freely used in commercial projects, however you may
// want access to unreleased materials such as verification environments,
// or test vectors, as well as changes to the IP for integration purposes.
// If this is the case, contact the above address.
// I am interested to hear how and where this IP is used, so please get
// in touch!
//-----------------------------------------------------------------
// Copyright 2020 Ultra-Embedded.com
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//-----------------------------------------------------------------

module jpeg_input
(
    // Inputs
     input  logic           clk_i
    ,input  logic           rst_i
    ,input  logic           inport_valid_i
    ,input  logic [ 31:0]   inport_data_i
    ,input  logic [  3:0]   inport_strb_i
    ,input  logic           inport_last_i
    ,input  logic           dqt_cfg_accept_i 
    ,input  logic           dht_cfg_accept_i
    ,input  logic           data_accept_i

    // Outputs
    ,output logic           inport_accept_o
    ,output logic           img_start_o
    ,output logic           img_end_o
    ,output logic [ 15:0]   img_width_o
    ,output logic [ 15:0]   img_height_o
    ,output logic [  1:0]   img_mode_o
    ,output logic [  1:0]   img_dqt_table_y_o
    ,output logic [  1:0]   img_dqt_table_cb_o
    ,output logic [  1:0]   img_dqt_table_cr_o
    ,output logic           dqt_cfg_valid_o
    ,output logic [  7:0]   dqt_cfg_data_o
    ,output logic           dqt_cfg_last_o
    ,output logic           dht_cfg_valid_o
    ,output logic [  7:0]   dht_cfg_data_o
    ,output logic           dht_cfg_last_o
    ,output logic           data_valid_o
    ,output logic [  7:0]   data_data_o
    ,output logic           data_last_o
    ,output logic [ 15:0]   restart_val_o
    ,output logic           restart_valid_o
);

logic inport_accept_w;

//-----------------------------------------------------------------
// Input data read index
// This module takes in 32 bits of data at a time but parses only a byte at a time
// This block tracks the current byte being processed
//-----------------------------------------------------------------
logic [1:0] byte_idx_q;

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        byte_idx_q <= 2'b0;
  else if (inport_valid_i && inport_accept_w && inport_last_i)  // TODO: kaulad - Understand the inport_list_i signal. According to my current understanding asserted when last word on AXI input stream but implementation suggests last byte of input AXI stream
        byte_idx_q <= 2'b0;
    else if (inport_valid_i && inport_accept_w)
        byte_idx_q <= byte_idx_q + 2'd1;
end


//-----------------------------------------------------------------
// Data mux
// Using a MUX with masked inputs depending on the input strobe signal to track the current byte
//-----------------------------------------------------------------
logic [7:0] data_r;


always_comb //FIXME: kaulad - If a strobe is 0, we send 8 bits of 0's to the logic ahead, any way to optimize the logic here to save cycles?
begin
    data_r = 8'b0;

    case (byte_idx_q)
    default: data_r = {8{inport_strb_i[0]}} & inport_data_i[7:0];
    2'd1:    data_r = {8{inport_strb_i[1]}} & inport_data_i[15:8];
    2'd2:    data_r = {8{inport_strb_i[2]}} & inport_data_i[23:16];
    2'd3:    data_r = {8{inport_strb_i[3]}} & inport_data_i[31:24];
    endcase
end

//-----------------------------------------------------------------
// Last data
// Storing the last indexed byte
//-----------------------------------------------------------------
logic [7:0] last_b_q;

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        last_b_q <= 8'b0;
    else if (inport_valid_i && inport_accept_w)
        last_b_q <= inport_last_i ? 8'b0 : data_r;
end

//-----------------------------------------------------------------
// Token decoder
// 16 bit marker checks using last stored data and current data
//-----------------------------------------------------------------
logic token_soi_w;
logic token_sof0_w;
logic token_dqt_w;
logic token_dht_w;
logic token_eoi_w;
logic token_sos_w;
logic token_pad_w;
logic token_sof2_w;
logic token_dri_w;
logic token_rst_w;
logic token_app_w;
logic token_com_w;

assign token_soi_w  = (last_b_q == 8'hFF && data_r == 8'hd8);
assign token_sof0_w = (last_b_q == 8'hFF && data_r == 8'hc0);
assign token_dqt_w  = (last_b_q == 8'hFF && data_r == 8'hdb);
assign token_dht_w  = (last_b_q == 8'hFF && data_r == 8'hc4);
assign token_eoi_w  = (last_b_q == 8'hFF && data_r == 8'hd9);
assign token_dri_w  = (last_b_q == 8'hFF && data_r == 8'hdd);
assign token_sos_w  = (last_b_q == 8'hFF && data_r == 8'hda);
assign token_pad_w  = (last_b_q == 8'hFF && data_r == 8'h00);


// Unsupported
assign token_sof2_w = (last_b_q == 8'hFF && data_r == 8'hc2);
assign token_rst_w  = (last_b_q == 8'hFF && data_r >= 8'hd0 && data_r <= 8'hd7);
assign token_app_w  = (last_b_q == 8'hFF && data_r >= 8'he0 && data_r <= 8'hef);
assign token_com_w  = (last_b_q == 8'hFF && data_r == 8'hfe);

//-----------------------------------------------------------------
// FSM
//-----------------------------------------------------------------
// FSM State Definitions
typedef enum logic [4:0] {
    STATE_IDLE        = 5'd0,    // Idle, waiting for SOI marker
    STATE_ACTIVE      = 5'd1,    // Active processing state
    STATE_UXP_LENH    = 5'd2,    // Unsupported seg: length high byte
    STATE_UXP_LENL    = 5'd3,    // Unsupported seg: length low byte
    STATE_UXP_DATA    = 5'd4,    // Skipping unsupported segment data
    STATE_DQT_LENH    = 5'd5,    // Quant table: length high byte
    STATE_DQT_LENL    = 5'd6,    // Quant table: length low byte
    STATE_DQT_DATA    = 5'd7,    // Quant table data processing
    STATE_DHT_LENH    = 5'd8,    // Huffman table: length high byte
    STATE_DHT_LENL    = 5'd9,    // Huffman table: length low byte
    STATE_DHT_DATA    = 5'd10,   // Huffman table data processing
    STATE_IMG_LENH    = 5'd11,   // SOS: length high byte
    STATE_IMG_LENL    = 5'd12,   // SOS: length low byte
    STATE_IMG_SOS     = 5'd13,   // Start of Scan header processing
    STATE_IMG_DATA    = 5'd14,   // Compressed data streaming
    STATE_SOF_LENH    = 5'd15,   // SOF: length high byte
    STATE_SOF_LENL    = 5'd16,   // SOF: length low byte
    STATE_SOF_DATA    = 5'd17,    // SOF parameter extraction
    STATE_DRI_LENH    = 5'd18,   // DRI: length high byte
    STATE_DRI_LENL    = 5'd19,   // DRI: length low byte
    STATE_DRI_DATA1   = 5'd20,   // DRI: first byte of interval
    STATE_DRI_DATA2   = 5'd21    // DRI: second byte of interval

} state_e;

state_e state_q;
logic [15:0] length_q;

state_e next_state_r;

always_comb
begin
    next_state_r = state_q;

    case (state_q)
    //-------------------------------------------------------------
    // IDLE - waiting for SOI
    //-------------------------------------------------------------
    STATE_IDLE :
    begin
        if (token_soi_w)
            next_state_r = STATE_ACTIVE;
    end
    //-------------------------------------------------------------
    // ACTIVE - waiting for various image markers
    //-------------------------------------------------------------
    STATE_ACTIVE :
    begin
        if (token_eoi_w)
            next_state_r = STATE_IDLE;
        else if (token_dqt_w)
            next_state_r = STATE_DQT_LENH;
        else if (token_dht_w)
            next_state_r = STATE_DHT_LENH;
        else if (token_dri_w)
            next_state_r = STATE_DRI_LENH;
        else if (token_sos_w)
            next_state_r = STATE_IMG_LENH;
        else if (token_sof0_w)
            next_state_r = STATE_SOF_LENH;
        // Unsupported
        else if (token_sof2_w ||
                 token_rst_w ||
                 token_app_w ||
                 token_com_w)
            next_state_r = STATE_UXP_LENH;
    end
    //-------------------------------------------------------------
    // IMG
    //-------------------------------------------------------------
    STATE_IMG_LENH :
    begin
        if (inport_valid_i)
            next_state_r = STATE_IMG_LENL;
    end
    STATE_IMG_LENL :
    begin
        if (inport_valid_i)
            next_state_r = STATE_IMG_SOS;
    end
    STATE_IMG_SOS :
    begin
        if (inport_valid_i && length_q <= 16'd1)
            next_state_r = STATE_IMG_DATA;
    end
    STATE_IMG_DATA :
    begin
        if (token_eoi_w)
            next_state_r = STATE_IDLE;
    end
    //-------------------------------------------------------------
    // DQT
    //-------------------------------------------------------------
    STATE_DQT_LENH :
    begin
        if (inport_valid_i)
            next_state_r = STATE_DQT_LENL;
    end
    STATE_DQT_LENL :
    begin
        if (inport_valid_i)
            next_state_r = STATE_DQT_DATA;
    end
    STATE_DQT_DATA :
    begin
        if (inport_valid_i && inport_accept_w && length_q <= 16'd1)
            next_state_r = STATE_ACTIVE;
    end
    //-------------------------------------------------------------
    // SOF
    //-------------------------------------------------------------
    STATE_SOF_LENH :
    begin
        if (inport_valid_i)
            next_state_r = STATE_SOF_LENL;
    end
    STATE_SOF_LENL :
    begin
        if (inport_valid_i)
            next_state_r = STATE_SOF_DATA;
    end
    STATE_SOF_DATA :
    begin
        if (inport_valid_i && inport_accept_w && length_q <= 16'd1)
            if (token_sos_w)
                next_state_r = STATE_IMG_LENH;
            else
                next_state_r = STATE_ACTIVE;
    end
    //-------------------------------------------------------------
    // DHT
    //-------------------------------------------------------------
    STATE_DHT_LENH :
    begin
        if (inport_valid_i)
            next_state_r = STATE_DHT_LENL;
    end
    STATE_DHT_LENL :
    begin
        if (inport_valid_i)
            next_state_r = STATE_DHT_DATA;
    end
    STATE_DHT_DATA :
    begin
        if (inport_valid_i && inport_accept_w && length_q <= 16'd1)
            next_state_r = STATE_ACTIVE;
    end
    //-------------------------------------------------------------
    // DRI
    //-------------------------------------------------------------
    STATE_DRI_LENH:
    begin
        if (inport_valid_i)
            next_state_r = STATE_DRI_LENL;
    end

    STATE_DRI_LENL:
    begin
        if (inport_valid_i)
            next_state_r = STATE_DRI_DATA1;
    end

    STATE_DRI_DATA1:
    begin
        if (inport_valid_i)
            next_state_r = STATE_DRI_DATA2;
    end

    STATE_DRI_DATA2:
    begin
        if (inport_valid_i)
            next_state_r = STATE_ACTIVE;
    end
    //-------------------------------------------------------------
    // Unsupported sections - skip
    //-------------------------------------------------------------
    STATE_UXP_LENH :
    begin
        if (inport_valid_i)
            next_state_r = STATE_UXP_LENL;
    end
    STATE_UXP_LENL :
    begin
        if (inport_valid_i)
            next_state_r = STATE_UXP_DATA;
    end
    STATE_UXP_DATA :
    begin
        if (inport_valid_i && inport_accept_w && length_q <= 16'd1)
            next_state_r = STATE_ACTIVE;
    end
    default:
        ;
    endcase

    // End of data stream
    if (inport_valid_i && inport_last_i && inport_accept_w)
        next_state_r = STATE_IDLE;
end

always_ff @(posedge clk_i)
begin
    if (rst_i | token_eoi_w)
        begin
            state_q <= STATE_IDLE;
            restart_valid_o <= 0;
        end
    else
        begin
            if (state_q == STATE_DRI_DATA2)
                restart_valid_o <= 1;
            state_q <= next_state_r;
        end
        
end

//-----------------------------------------------------------------
// Length
// Code to capture the length and track the remaining data length
//-----------------------------------------------------------------

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        length_q <= 16'b0;
    else if (state_q == STATE_UXP_LENH || state_q == STATE_DQT_LENH || 
             state_q == STATE_DHT_LENH || state_q == STATE_IMG_LENH ||
             state_q == STATE_SOF_LENH)
        length_q <= {data_r, 8'b0};
    else if (state_q == STATE_UXP_LENL || state_q == STATE_DQT_LENL ||
             state_q == STATE_DHT_LENL || state_q == STATE_IMG_LENL ||
             state_q == STATE_SOF_LENL)
      length_q <= {8'b0, data_r} - 16'd2; // TODO: kaulad - Understand why we are overwriting upper bits?
    else if ((state_q == STATE_UXP_DATA || 
              state_q == STATE_DQT_DATA ||
              state_q == STATE_DHT_DATA ||
              state_q == STATE_SOF_DATA ||
              state_q == STATE_IMG_SOS) && inport_valid_i && inport_accept_w)
        length_q <= length_q - 16'd1;
    else if (state_q == STATE_DRI_LENH)
        length_q <= {data_r, 8'b0};
    else if (state_q == STATE_DRI_LENL)
        length_q <= {8'b0, data_r} - 16'd2;
end

//-----------------------------------------------------------------
// DQT
// Enable DQT Logic and tells it when it is supposed to be disabled
//-----------------------------------------------------------------
assign dqt_cfg_valid_o = (state_q == STATE_DQT_DATA) && inport_valid_i;
assign dqt_cfg_data_o = data_r;
assign dqt_cfg_last_o = inport_last_i || (state_q == STATE_DQT_DATA) && (length_q == 16'd1);

//-----------------------------------------------------------------
// DHT
// Enable DHT Logic and tells it when it is supposed to be disabled
//-----------------------------------------------------------------
assign dht_cfg_valid_o = (state_q == STATE_DHT_DATA) && inport_valid_i;
assign dht_cfg_data_o = data_r;
assign dht_cfg_last_o = inport_last_i || (state_q == STATE_DHT_DATA) && (length_q == 16'd1);

//----------------------------------------------------------------
// DRI
// Logic for DRI
//----------------------------------------------------------------
logic [15:0] restart_interval_q;
always_ff @(posedge clk_i) 
begin
    if (rst_i)
        restart_interval_q <= 16'b0;
    else if (state_q == STATE_DRI_DATA1 && inport_valid_i)
        restart_interval_q[15:8] <= data_r;
    else if (state_q == STATE_DRI_DATA2 && inport_valid_i)
        restart_interval_q[7:0] <= data_r;
end

assign restart_val_o = restart_interval_q;

//-----------------------------------------------------------------
// Image data
//-----------------------------------------------------------------
logic data_valid_q;
logic [7:0] data_data_q;

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        data_valid_q <= 1'b0;
    else if (inport_valid_i && data_accept_i) 
        data_valid_q <= (state_q == STATE_IMG_DATA) && (inport_valid_i && ~token_pad_w && ~token_eoi_w);
    else if (state_q != STATE_IMG_DATA)
        data_valid_q <= 1'b0;
end

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        data_data_q <= 8'b0;
    else if (inport_valid_i && data_accept_i)
        data_data_q <= data_r;
end

assign data_valid_o = data_valid_q && inport_valid_i && !token_eoi_w;
assign data_data_o = data_data_q;

// NOTE: Last is delayed by one cycles (not qualified by data_v_o)
assign data_last_o = data_valid_q && inport_valid_i && token_eoi_w;

//-----------------------------------------------------------------
// Handshaking
// YUMI implementation: Accept data when downstream is ready (yumi) or when we're not outputting data
//-----------------------------------------------------------------
logic last_byte_w;
assign last_byte_w = (byte_idx_q == 2'd3) || inport_last_i;

assign inport_accept_w = (state_q == STATE_DQT_DATA && dqt_cfg_accept_i) ||
                         (state_q == STATE_DHT_DATA && dht_cfg_accept_i) ||
                         (state_q == STATE_IMG_DATA && (data_accept_i || token_pad_w)) ||
                         (state_q != STATE_DQT_DATA && 
                          state_q != STATE_DHT_DATA && 
                          state_q != STATE_IMG_DATA);

assign inport_accept_o = last_byte_w && inport_accept_w;

//-----------------------------------------------------------------
// Capture Index
//-----------------------------------------------------------------
logic [5:0] idx_q;

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        idx_q <= 6'b0;
    else if (inport_valid_i && inport_accept_w && state_q == STATE_SOF_DATA)
        idx_q <= idx_q + 6'd1;
    else if (state_q == STATE_SOF_LENH)
        idx_q <= 6'b0;
end

//-----------------------------------------------------------------
// SOF capture
//-----------------------------------------------------------------
logic [7:0] img_precision_q;

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        img_precision_q <= 8'b0;
    else if (token_sof0_w)
        img_precision_q <= 8'b0;
    else if (state_q == STATE_SOF_DATA && idx_q == 6'd0)
        img_precision_q <= data_r;
end

logic [15:0] img_height_q;

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        img_height_q <= 16'b0;
    else if (token_sof0_w)
        img_height_q <= 16'b0;
    else if (state_q == STATE_SOF_DATA && idx_q == 6'd1)
        img_height_q <= {data_r, 8'b0};
    else if (state_q == STATE_SOF_DATA && idx_q == 6'd2)
        img_height_q <= {img_height_q[15:8], data_r};
end

assign img_height_o = img_height_q;

logic [15:0] img_width_q;

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        img_width_q <= 16'b0;
    else if (token_sof0_w)
        img_width_q <= 16'b0;
    else if (state_q == STATE_SOF_DATA && idx_q == 6'd3)
        img_width_q <= {data_r, 8'b0};
    else if (state_q == STATE_SOF_DATA && idx_q == 6'd4)
        img_width_q <= {img_width_q[15:8], data_r};
end

assign img_width_o = img_width_q;

logic [7:0] img_num_comp_q;

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        img_num_comp_q <= 8'b0;
    else if (token_sof0_w)
        img_num_comp_q <= 8'b0;
    else if (state_q == STATE_SOF_DATA && idx_q == 6'd5)
        img_num_comp_q <= data_r;
end

logic [7:0] img_y_factor_q;

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        img_y_factor_q <= 8'b0;
    else if (token_sof0_w)
        img_y_factor_q <= 8'b0;
    else if (state_q == STATE_SOF_DATA && idx_q == 6'd7)
        img_y_factor_q <= data_r;
end

logic [1:0] img_y_dqt_table_q;

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        img_y_dqt_table_q <= 2'b0;
    else if (token_sof0_w)
        img_y_dqt_table_q <= 2'b0;
    else if (state_q == STATE_SOF_DATA && idx_q == 6'd8)
        img_y_dqt_table_q <= data_r[1:0];
end

logic [7:0] img_cb_factor_q;

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        img_cb_factor_q <= 8'b0;
    else if (token_sof0_w)
        img_cb_factor_q <= 8'b0;
    else if (state_q == STATE_SOF_DATA && idx_q == 6'd10)
        img_cb_factor_q <= data_r;
end

logic [1:0] img_cb_dqt_table_q;

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        img_cb_dqt_table_q <= 2'b0;
    else if (token_sof0_w)
        img_cb_dqt_table_q <= 2'b0;
    else if (state_q == STATE_SOF_DATA && idx_q == 6'd11)
        img_cb_dqt_table_q <= data_r[1:0];
end

logic [7:0] img_cr_factor_q;

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        img_cr_factor_q <= 8'b0;
    else if (token_sof0_w)
        img_cr_factor_q <= 8'b0;
    else if (state_q == STATE_SOF_DATA && idx_q == 6'd13)
        img_cr_factor_q <= data_r;
end

logic [1:0] img_cr_dqt_table_q;

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        img_cr_dqt_table_q <= 2'b0;
    else if (token_sof0_w)
        img_cr_dqt_table_q <= 2'b0;
    else if (state_q == STATE_SOF_DATA && idx_q == 6'd14)
        img_cr_dqt_table_q <= data_r[1:0];
end

assign img_dqt_table_y_o = img_y_dqt_table_q;
assign img_dqt_table_cb_o = img_cb_dqt_table_q;
assign img_dqt_table_cr_o = img_cr_dqt_table_q;

logic [3:0] y_horiz_factor_w;
logic [3:0] y_vert_factor_w;
logic [3:0] cb_horiz_factor_w;
logic [3:0] cb_vert_factor_w;
logic [3:0] cr_horiz_factor_w;
logic [3:0] cr_vert_factor_w;

assign y_horiz_factor_w = img_y_factor_q[7:4];
assign y_vert_factor_w = img_y_factor_q[3:0];
assign cb_horiz_factor_w = img_cb_factor_q[7:4];
assign cb_vert_factor_w = img_cb_factor_q[3:0];
assign cr_horiz_factor_w = img_cr_factor_q[7:4];
assign cr_vert_factor_w = img_cr_factor_q[3:0];

localparam JPEG_MONOCHROME = 2'd0;
localparam JPEG_YCBCR_444 = 2'd1;
localparam JPEG_YCBCR_420 = 2'd2;
localparam JPEG_UNSUPPORTED = 2'd3;

logic [1:0] img_mode_q;

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        img_mode_q <= JPEG_UNSUPPORTED;
    else if (token_sof0_w)
        img_mode_q <= JPEG_UNSUPPORTED;
    else if (state_q == STATE_SOF_DATA && next_state_r == STATE_ACTIVE)
    begin
        // Single component (Y)
        if (img_num_comp_q == 8'd1)
            img_mode_q <= JPEG_MONOCHROME;
        // Colour image (YCbCr)
        else if (img_num_comp_q == 8'd3)
        begin
            if (y_horiz_factor_w == 4'd1 && y_vert_factor_w == 4'd1 &&
                cb_horiz_factor_w == 4'd1 && cb_vert_factor_w == 4'd1 &&
                cr_horiz_factor_w == 4'd1 && cr_vert_factor_w == 4'd1)
                img_mode_q <= JPEG_YCBCR_444;
            else if (y_horiz_factor_w == 4'd2 && y_vert_factor_w == 4'd2 &&
                     cb_horiz_factor_w == 4'd1 && cb_vert_factor_w == 4'd1 &&
                     cr_horiz_factor_w == 4'd1 && cr_vert_factor_w == 4'd1)
                img_mode_q <= JPEG_YCBCR_420;
        end
    end
end

logic eof_q;

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        eof_q <= 1'b1;
    else if (state_q == STATE_IDLE && token_soi_w)
        eof_q <= 1'b0;
    else if (img_end_o)
        eof_q <= 1'b1;
end

logic start_q;

always_ff @ (posedge clk_i)
begin
    if (rst_i)
        start_q <= 1'b0;
    else if (inport_valid_i & token_sos_w)
        start_q <= 1'b0;
    else if (state_q == STATE_IDLE && token_soi_w)
        start_q <= 1'b1;
end

assign img_start_o = start_q;
assign img_end_o = eof_q | (inport_valid_i & token_eoi_w);
assign img_mode_o = img_mode_q;

endmodule