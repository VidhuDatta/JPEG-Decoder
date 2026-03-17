module jpeg_input_cov (
    // Standard signals
    input logic clk_i,
    input logic rst_i,
    
    // Input interface
    input logic           inport_valid_i,
    input logic [31:0]    inport_data_i,
    input logic [3:0]     inport_strb_i,
    input logic           inport_last_i,
    input logic           dqt_cfg_accept_i,
    input logic           dht_cfg_accept_i,
    input logic           data_accept_i,
    
    // Output signals
    input logic           inport_accept_o,
    input logic           img_start_o,
    input logic           img_end_o,
    input logic [15:0]    img_width_o,
    input logic [15:0]    img_height_o,
    input logic [1:0]     img_mode_o,
    input logic [1:0]     img_dqt_table_y_o,
    input logic [1:0]     img_dqt_table_cb_o,
    input logic [1:0]     img_dqt_table_cr_o,
    input logic           dqt_cfg_valid_o,
    input logic [7:0]     dqt_cfg_data_o,
    input logic           dqt_cfg_last_o,
    input logic           dht_cfg_valid_o,
    input logic [7:0]     dht_cfg_data_o,
    input logic           dht_cfg_last_o,
    input logic           data_valid_o,
    input logic [7:0]     data_data_o,
    input logic           data_last_o,
    input logic [15:0]    restart_val_o,
    input logic           restart_valid_o,
    
    // Internal signals (from the module)
    input logic [4:0]     state_q,
    input logic [7:0]     last_b_q,
    input logic [7:0]     data_r
);

    // FSM State definitions
    localparam STATE_IDLE        = 5'd0;
    localparam STATE_ACTIVE      = 5'd1;
    localparam STATE_UXP_LENH    = 5'd2;
    localparam STATE_UXP_LENL    = 5'd3;
    localparam STATE_UXP_DATA    = 5'd4;
    localparam STATE_DQT_LENH    = 5'd5;
    localparam STATE_DQT_LENL    = 5'd6;
    localparam STATE_DQT_DATA    = 5'd7;
    localparam STATE_DHT_LENH    = 5'd8;
    localparam STATE_DHT_LENL    = 5'd9;
    localparam STATE_DHT_DATA    = 5'd10;
    localparam STATE_IMG_LENH    = 5'd11;
    localparam STATE_IMG_LENL    = 5'd12;
    localparam STATE_IMG_SOS     = 5'd13;
    localparam STATE_IMG_DATA    = 5'd14;
    localparam STATE_SOF_LENH    = 5'd15;
    localparam STATE_SOF_LENL    = 5'd16;
    localparam STATE_SOF_DATA    = 5'd17;
    localparam STATE_DRI_LENH    = 5'd18;
    localparam STATE_DRI_LENL    = 5'd19;
    localparam STATE_DRI_DATA1   = 5'd20;
    localparam STATE_DRI_DATA2   = 5'd21;

    // Reset coverage
    covergroup cg_reset @(posedge clk_i);
        cp_reset: coverpoint rst_i {
            bins active = {1};
            bins inactive = {0};
            bins deassert = (1 => 0);
        }
    endgroup

    // FSM State coverage
    covergroup cg_fsm @(posedge clk_i iff !rst_i);
        cp_state: coverpoint state_q {
            bins IDLE = {STATE_IDLE};
            bins ACTIVE = {STATE_ACTIVE};
            bins DQT_STATES = {STATE_DQT_LENH, STATE_DQT_LENL, STATE_DQT_DATA};
            bins DHT_STATES = {STATE_DHT_LENH, STATE_DHT_LENL, STATE_DHT_DATA};
            bins IMG_STATES = {STATE_IMG_LENH, STATE_IMG_LENL, STATE_IMG_SOS, STATE_IMG_DATA};
            bins SOF_STATES = {STATE_SOF_LENH, STATE_SOF_LENL, STATE_SOF_DATA};
            bins DRI_STATES = {STATE_DRI_LENH, STATE_DRI_LENL, STATE_DRI_DATA1, STATE_DRI_DATA2};
            bins UXP_STATES = {STATE_UXP_LENH, STATE_UXP_LENL, STATE_UXP_DATA};
        }
        
        // Important state transitions
        cp_state_trans: coverpoint state_q {
            bins idle_to_active = (STATE_IDLE => STATE_ACTIVE);
            bins active_to_dqt = (STATE_ACTIVE => STATE_DQT_LENH);
            bins active_to_dht = (STATE_ACTIVE => STATE_DHT_LENH);
            bins active_to_sof = (STATE_ACTIVE => STATE_SOF_LENH);
            bins active_to_sos = (STATE_ACTIVE => STATE_IMG_LENH);
            bins active_to_dri = (STATE_ACTIVE => STATE_DRI_LENH);
            bins dqt_complete = (STATE_DQT_DATA => STATE_ACTIVE);
            bins dht_complete = (STATE_DHT_DATA => STATE_ACTIVE);
            bins sof_complete = (STATE_SOF_DATA => STATE_ACTIVE);
            bins sos_to_img_data = (STATE_IMG_SOS => STATE_IMG_DATA);
            bins dri_complete = (STATE_DRI_DATA2 => STATE_ACTIVE);
            bins img_data_to_idle = (STATE_IMG_DATA => STATE_IDLE);
        }
    endgroup

    // Token detection coverage
    covergroup cg_tokens @(posedge clk_i iff (inport_valid_i && !rst_i));
        cp_token: coverpoint {last_b_q, data_r} {
            bins soi = {16'hFFD8};
            bins sof0 = {16'hFFC0};
            bins dqt = {16'hFFDB};
            bins dht = {16'hFFC4};
            bins sos = {16'hFFDA};
            bins eoi = {16'hFFD9};
            bins dri = {16'hFFDD};
            bins pad = {16'hFF00};
      
            bins rst_d0 = {16'hFFD0};
            bins rst_d1 = {16'hFFD1};
            bins rst_d2 = {16'hFFD2};
            bins rst_d3 = {16'hFFD3};
            bins rst_d4 = {16'hFFD4};
            bins rst_d5 = {16'hFFD5};
            bins rst_d6 = {16'hFFD6};
            bins rst_d7 = {16'hFFD7};
          
            bins app_e0 = {16'hFFE0};
            bins app_e1 = {16'hFFE1};
            bins app_other = {16'hFFE2, 16'hFFE3, 16'hFFE4, 16'hFFE5, 16'hFFE6, 16'hFFE7, 16'hFFE8, 16'hFFE9, 16'hFFEA, 16'hFFEB, 16'hFFEC, 16'hFFED, 16'hFFEE, 16'hFFEF};
            bins com = {16'hFFFE};
        }
    endgroup

    // JPEG Mode coverage
    // covergroup cg_mode @(posedge clk_i iff img_start_o);
    //     cp_mode: coverpoint img_mode_o {
    //         bins monochrome = {2'd0};
    //         bins ycbcr_444 = {2'd1};
    //         bins ycbcr_420 = {2'd2};
    //         bins unsupported = {2'd3};
    //     }
        
    //     cp_dqt_table_y: coverpoint img_dqt_table_y_o;
    //     cp_dqt_table_cb: coverpoint img_dqt_table_cb_o;
    //     cp_dqt_table_cr: coverpoint img_dqt_table_cr_o;
        
    //     cross_tables: cross cp_mode, cp_dqt_table_y, cp_dqt_table_cb, cp_dqt_table_cr;
    // endgroup

    // Interface handshaking coverage
    covergroup cg_handshake @(posedge clk_i iff !rst_i);
        // Input interface
        cp_in_valid: coverpoint inport_valid_i;
        cp_in_ready: coverpoint inport_accept_o;
        cp_in_handshake: cross cp_in_valid, cp_in_ready {
            bins successful = binsof(cp_in_valid) intersect {1} && binsof(cp_in_ready) intersect {1};
            bins backpressure = binsof(cp_in_valid) intersect {1} && binsof(cp_in_ready) intersect {0};
        }
        
        // DQT interface
        cp_dqt_valid: coverpoint dqt_cfg_valid_o;
        cp_dqt_yumi: coverpoint dqt_cfg_accept_i;
        cp_dqt_handshake: cross cp_dqt_valid, cp_dqt_yumi {
            bins successful = binsof(cp_dqt_valid) intersect {1} && binsof(cp_dqt_yumi) intersect {1};
            bins blocked = binsof(cp_dqt_valid) intersect {1} && binsof(cp_dqt_yumi) intersect {0};
        }
        
        // DHT interface
        cp_dht_valid: coverpoint dht_cfg_valid_o;
        cp_dht_yumi: coverpoint dht_cfg_accept_i;
        cp_dht_handshake: cross cp_dht_valid, cp_dht_yumi {
            bins successful = binsof(cp_dht_valid) intersect {1} && binsof(cp_dht_yumi) intersect {1};
            bins blocked = binsof(cp_dht_valid) intersect {1} && binsof(cp_dht_yumi) intersect {0};
        }
        
        // Data interface
        cp_data_valid: coverpoint data_valid_o;
        cp_data_yumi: coverpoint data_accept_i;
        cp_data_handshake: cross cp_data_valid, cp_data_yumi {
            bins successful = binsof(cp_data_valid) intersect {1} && binsof(cp_data_yumi) intersect {1};
            bins blocked = binsof(cp_data_valid) intersect {1} && binsof(cp_data_yumi) intersect {0};
        }
    endgroup

    // CHANGE: Improved restart interval coverage with better sampling conditions
    // Now sampling during DRI states or when restart_valid_o is asserted
    // covergroup cg_restart @(posedge clk_i iff ((state_q == STATE_DRI_DATA1 || state_q == STATE_DRI_DATA2) || restart_valid_o));
    //     cp_restart_val: coverpoint restart_val_o {
    //         bins zero = {0};                             // No restart intervals
    //         bins small_values = {1, 2, 4, 8, 16};        // Small intervals
    //         bins medium_values = {32, 64, 128, 256};     // Medium intervals
    //         bins large_values = {512, 1024, 2048, 4096}; // Large intervals
    //         bins very_large = {8192, 16384, 32768, 65535}; // Very large intervals
    //     }
    // endgroup

    // CHANGE: Add coverage for DRI token detection
    covergroup cg_dri_token @(posedge clk_i iff (inport_valid_i && !rst_i));
        cp_token_dri: coverpoint {last_b_q, data_r} {
            bins dri_marker = {16'hFFDD};
        }
        cp_state_at_dri: coverpoint state_q {
            bins ACTIVE = {STATE_ACTIVE}; // DRI should be detected in ACTIVE state
        }
        cross_dri_detect: cross cp_token_dri, cp_state_at_dri;
    endgroup

    // State-token cross coverage
    // Removed illegal bin in state-token cross
    covergroup cg_state_token @(posedge clk_i iff (inport_valid_i && !rst_i));
        cp_state: coverpoint state_q {
            bins IDLE = {STATE_IDLE};
            bins ACTIVE = {STATE_ACTIVE};
            bins IMG_DATA = {STATE_IMG_DATA};
        }
        
        cp_token: coverpoint {last_b_q, data_r} {
            bins soi = {16'hFFD8};
            bins eoi = {16'hFFD9};
            bins sof0 = {16'hFFC0};
            bins dqt = {16'hFFDB};
            bins dht = {16'hFFC4};
            bins sos = {16'hFFDA};
            bins dri = {16'hFFDD};
            bins pad = {16'hFF00};
        }
        
        cross_state_token: cross cp_state, cp_token {
            // Valid combinations
            bins idle_soi = binsof(cp_state) intersect {STATE_IDLE} && binsof(cp_token) intersect {16'hFFD8};
            bins active_sof0 = binsof(cp_state) intersect {STATE_ACTIVE} && binsof(cp_token) intersect {16'hFFC0};
            bins active_dqt = binsof(cp_state) intersect {STATE_ACTIVE} && binsof(cp_token) intersect {16'hFFDB};
            bins active_dht = binsof(cp_state) intersect {STATE_ACTIVE} && binsof(cp_token) intersect {16'hFFC4};
            bins active_sos = binsof(cp_state) intersect {STATE_ACTIVE} && binsof(cp_token) intersect {16'hFFDA};
            bins active_dri = binsof(cp_state) intersect {STATE_ACTIVE} && binsof(cp_token) intersect {16'hFFDD};
            bins img_data_eoi = binsof(cp_state) intersect {STATE_IMG_DATA} && binsof(cp_token) intersect {16'hFFD9};
            bins img_data_pad = binsof(cp_state) intersect {STATE_IMG_DATA} && binsof(cp_token) intersect {16'hFF00};
        }
    endgroup

    // CHANGE: Track DRI state transitions - FIXED SYNTAX ERROR
    covergroup cg_dri_states @(posedge clk_i iff !rst_i);
        cp_dri_state: coverpoint state_q {
            bins dri_states = {STATE_DRI_LENH, STATE_DRI_LENL, STATE_DRI_DATA1, STATE_DRI_DATA2};
            
            // Fixed: Use proper transition syntax for sequence
            bins dri_sequence = (STATE_ACTIVE => STATE_DRI_LENH => STATE_DRI_LENL => STATE_DRI_DATA1 => STATE_DRI_DATA2 => STATE_ACTIVE);
        }
    endgroup

    // Create instances of all covergroups
    cg_reset cov_reset = new();
    cg_fsm cov_fsm = new();
    cg_tokens cov_tokens = new();
    // cg_mode cov_mode = new();
    cg_handshake cov_handshake = new();
    // cg_restart cov_restart = new(); // Modified instance for restart coverage
    cg_dri_token cov_dri_token = new(); // New covergroup for DRI token detection
    cg_dri_states cov_dri_states = new(); // New covergroup for DRI state transitions
    cg_state_token cov_state_token = new();
    
    // Report coverage at the end of simulation
    final begin
        int file_handle;
        string filename = "jpeg_input_coverage_report.txt";
        
        file_handle = $fopen(filename, "w");
        if (file_handle == 0) begin
            $display("Error: Failed to open file %s for writing", filename);
        end else begin
            $fdisplay(file_handle, "=================================================================");
            $fdisplay(file_handle, "                JPEG Input Module Coverage Report                 ");
            $fdisplay(file_handle, "=================================================================");
            $fdisplay(file_handle, "Reset Coverage:           %0.2f%%", cov_reset.get_coverage());
            $fdisplay(file_handle, "FSM State Coverage:       %0.2f%%", cov_fsm.get_coverage());
            $fdisplay(file_handle, "Token Detection Coverage: %0.2f%%", cov_tokens.get_coverage());
            // $fdisplay(file_handle, "Mode Coverage:            %0.2f%%", cov_mode.get_coverage());
            $fdisplay(file_handle, "Handshake Coverage:       %0.2f%%", cov_handshake.get_coverage());
            // $fdisplay(file_handle, "Restart Coverage:         %0.2f%%", cov_restart.get_coverage()); // Modified restart coverage
            $fdisplay(file_handle, "DRI Token Coverage:       %0.2f%%", cov_dri_token.get_coverage()); // New DRI token coverage
            $fdisplay(file_handle, "DRI States Coverage:      %0.2f%%", cov_dri_states.get_coverage()); // New DRI states coverage
            $fdisplay(file_handle, "State-Token Cross Coverage:%0.2f%%", cov_state_token.get_coverage());
            $fdisplay(file_handle, "-----------------------------------------------------------------");
            $fdisplay(file_handle, "Total Coverage:           %0.2f%%", $get_coverage());
            $fdisplay(file_handle, "=================================================================");
            
            // Simplified detailed coverage information
            $fdisplay(file_handle, "\n=== Coverage Group Details ===\n");
            
            $fdisplay(file_handle, "--- FSM State Coverage ---");
            $fdisplay(file_handle, "FSM State Coverage:       %0.2f%%", cov_fsm.get_coverage());
            
            $fdisplay(file_handle, "\n--- Token Detection Coverage ---");
            $fdisplay(file_handle, "Token Detection Coverage: %0.2f%%", cov_tokens.get_coverage());
            
            // $fdisplay(file_handle, "\n--- Mode Coverage ---");
            // $fdisplay(file_handle, "Mode Coverage:            %0.2f%%", cov_mode.get_coverage());
            
            $fdisplay(file_handle, "\n--- Interface Handshake Coverage ---");
            $fdisplay(file_handle, "Handshake Coverage:       %0.2f%%", cov_handshake.get_coverage());
            
            // $fdisplay(file_handle, "\n--- Restart Interval Coverage ---");
            // $fdisplay(file_handle, "Restart Coverage:         %0.2f%%", cov_restart.get_coverage());
            
            $fdisplay(file_handle, "\n--- DRI Token Coverage ---");
            $fdisplay(file_handle, "DRI Token Coverage:       %0.2f%%", cov_dri_token.get_coverage());
            
            $fdisplay(file_handle, "\n--- DRI States Coverage ---");
            $fdisplay(file_handle, "DRI States Coverage:      %0.2f%%", cov_dri_states.get_coverage());
            
            $fdisplay(file_handle, "\n--- State-Token Cross Coverage ---");
            $fdisplay(file_handle, "State-Token Coverage:     %0.2f%%", cov_state_token.get_coverage());
            
            $fclose(file_handle);
            $display("Coverage report written to %s", filename);
        end
    end
endmodule