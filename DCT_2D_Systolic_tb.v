
`timescale 1ns / 1ps

`define DATA_W 16 // Data width for fixed-point numbers (Q1.15 assumed for input/output)
`define N_DIM 8   // Dimension of the DCT (e.g., 8 for an 8x8 DCT)

module DCT_2D_Systolic_tb;

    localparam N_TB = `N_DIM;                     // DCT dimension used in testbench
    localparam DATA_WIDTH_TB = `DATA_W;           // Data width used in testbench
    localparam CLK_PERIOD_TB = 10;                // Clock period in ns (100 MHz)
    localparam TOTAL_SYSTEM_LATENCY_TB = 16;      // Expected latency of the DUT in clock cycles
    parameter real ERROR_THRESHOLD_2D_VAL_TB_VAL = 0.025; // Max allowed absolute error for PASS
    
    localparam MAX_FILENAME_LEN = 128;            
    reg [MAX_FILENAME_LEN*8-1:0] REF_FILENAME_2D_TB; 

    // Testbench Signals
    reg clk_tb; 
    reg rst_tb;
    reg [(N_TB*N_TB*DATA_WIDTH_TB)-1:0] x_input_tb_flat_sig;     
    wire [(N_TB*N_TB*DATA_WIDTH_TB)-1:0] Z_output_dut_flat_sig;  

    reg signed [DATA_WIDTH_TB-1:0] x_input_tb_2d [0:N_TB-1][0:N_TB-1];       // 2D input (fixed-point)
    reg signed [DATA_WIDTH_TB-1:0] Z_output_dut_2d [0:N_TB-1][0:N_TB-1];    // 2D DUT output (fixed-point)
    real Z_reference_real_tb [0:N_TB-1][0:N_TB-1];

    integer r_tb_loop, c_tb_loop; 
    integer error_count_tb_val;
    real max_abs_error_val_tb_val;
    real current_error_val_tb_val;
    
    real val_tmp_init_local_in_initial; 
    reg signed [DATA_WIDTH_TB-1:0] dut_val_fixed_comp_local_print_in_initial; 
    reg signed [DATA_WIDTH_TB-1:0] ref_val_fixed_for_print_tb; 
    real dut_val_real_conv_comp_local_print_in_initial; 
    real ref_val_real_from_file_tb; 

    integer ref_file_descriptor_2d_tb; 
    integer fscanf_status_tb;         

    // --- Clock Generation ---
    initial begin clk_tb = 1'b0; end
    always #(CLK_PERIOD_TB/2) clk_tb = ~clk_tb;

    // --- DUT Instantiation ---
    DCT_2D_Systolic #(
        .P_N_DIM(N_TB), 
        .P_DATA_W(DATA_WIDTH_TB) 
    ) dut_2d_i (
        .clk(clk_tb),
        .rst(rst_tb),
        .x_in_flat(x_input_tb_flat_sig),
        .Z_out_flat(Z_output_dut_flat_sig)
    );

    always @(*) begin : unpack_dut_output_comb_block
        integer r_unpack_loop, c_unpack_loop; 
        for (r_unpack_loop = 0; r_unpack_loop < N_TB; r_unpack_loop = r_unpack_loop + 1) begin
            for (c_unpack_loop = 0; c_unpack_loop < N_TB; c_unpack_loop = c_unpack_loop + 1) begin
                Z_output_dut_2d[r_unpack_loop][c_unpack_loop] = 
                    Z_output_dut_flat_sig[ (r_unpack_loop * N_TB + c_unpack_loop) * DATA_WIDTH_TB +: DATA_WIDTH_TB ];
            end
        end
    end

    // Converts a real number to Q1.15 fixed-point format
    function signed [DATA_WIDTH_TB-1:0] real_to_fixed_tb;
        input real val_in_real;
        real scaled_val_real; 
        integer int_val_out_int;
        begin 
            // Clamp input to approximate Q1.15 range before scaling
            if (val_in_real > 0.999969482421875) begin // Max positive for Q1.15 (32767/32768)
                scaled_val_real = 0.999969482421875 * 32768.0;
            end else if (val_in_real < -1.0) begin      // Min negative for Q1.15
                scaled_val_real = -1.0 * 32768.0;
            end else begin 
                scaled_val_real = val_in_real * 32768.0; 
            end
            
            // Round to nearest integer
            if (scaled_val_real >= 0) begin 
                int_val_out_int = scaled_val_real + 0.5; 
            end else begin 
                int_val_out_int = scaled_val_real - 0.5; 
            end
            
            // Saturate to Q1.15 limits
            if (int_val_out_int > 32767) begin 
                int_val_out_int = 32767; 
            end else if (int_val_out_int < -32768) begin 
                int_val_out_int = -32768; 
            end
            real_to_fixed_tb = int_val_out_int;
        end 
    endfunction

    // Converts a Q1.15 fixed-point number to real format
    function real fixed_to_real_tb;
        input signed [DATA_WIDTH_TB-1:0] val_fixed_in_func;
        begin 
            fixed_to_real_tb = $itor(val_fixed_in_func) / 32768.0; // 2^15 = 32768
        end 
    endfunction
    
    // Read 2D Reference Data From File
    task read_2d_reference_from_file_tb;
        integer r_read_loop, c_read_loop;
    begin
        $display("TB: Reading 2D reference outputs from file: %s", REF_FILENAME_2D_TB);
        for (r_read_loop = 0; r_read_loop < N_TB; r_read_loop = r_read_loop + 1) begin
            for (c_read_loop = 0; c_read_loop < N_TB; c_read_loop = c_read_loop + 1) begin
                fscanf_status_tb = $fscanf(ref_file_descriptor_2d_tb, "%f", Z_reference_real_tb[r_read_loop][c_read_loop]);
                if (fscanf_status_tb != 1) begin
                    $display("ERROR: Failed to read reference output for element [%0d][%0d] from file %s.", r_read_loop, c_read_loop, REF_FILENAME_2D_TB);
                    $display("Ensure the file exists, is correctly formatted, and contains sufficient data.");
                    $finish;
                end
            end
        end
        $display("TB: Finished reading 2D reference outputs from file.");
    end
    endtask
    initial begin
        
        REF_FILENAME_2D_TB = "E:/4th_year/VLSI_lab_course/Mini Project/Matlab/Systolic_2D_output_file.txt"; 
        #1;
        $display("Starting 2D DCT Testbench...");
        ref_file_descriptor_2d_tb = $fopen(REF_FILENAME_2D_TB, "r");
        if (ref_file_descriptor_2d_tb == 0) begin 
            $display("ERROR: Could not open reference file: %s", REF_FILENAME_2D_TB);
            $display("Please check the path and file permissions.");
            $finish;
        end
        read_2d_reference_from_file_tb(); 
        rst_tb = 1'b1; 
        for (r_tb_loop = 0; r_tb_loop < N_TB; r_tb_loop = r_tb_loop + 1) begin
            for (c_tb_loop = 0; c_tb_loop < N_TB; c_tb_loop = c_tb_loop + 1) begin
                val_tmp_init_local_in_initial = (r_tb_loop * 0.12 + c_tb_loop * 0.08) - 0.6; 
                // Clamp input values
                if (val_tmp_init_local_in_initial > 0.99) val_tmp_init_local_in_initial = 0.99; 
                if (val_tmp_init_local_in_initial < -0.99) val_tmp_init_local_in_initial = -0.99;
                x_input_tb_2d[r_tb_loop][c_tb_loop] = real_to_fixed_tb(val_tmp_init_local_in_initial); 
            end
        end
        // Specific input overrides
        x_input_tb_2d[0][0] = real_to_fixed_tb(0.75);
        x_input_tb_2d[1][2] = real_to_fixed_tb(-0.5);
        x_input_tb_2d[N_TB-1][N_TB-2] = real_to_fixed_tb(0.25);

        // Pack the 2D input array into the flat signal for the DUT
        for (r_tb_loop = 0; r_tb_loop < N_TB; r_tb_loop = r_tb_loop + 1) begin
            for (c_tb_loop = 0; c_tb_loop < N_TB; c_tb_loop = c_tb_loop + 1) begin
                 x_input_tb_flat_sig[(r_tb_loop * N_TB + c_tb_loop) * DATA_WIDTH_TB +: DATA_WIDTH_TB] = 
                     x_input_tb_2d[r_tb_loop][c_tb_loop];
            end
        end

        repeat(3) @(posedge clk_tb);
        rst_tb = 1'b0;
        $display("TB: Reset released. Inputs applied at t=%0t.", $time);
        repeat(TOTAL_SYSTEM_LATENCY_TB) @(posedge clk_tb);
        $display("TB: Expected output available from DUT at t=%0t.", $time);
        
        #1; 
        error_count_tb_val = 0; 
        max_abs_error_val_tb_val = 0.0; 
        $display("\n--- Comparing DUT 2D DCT Output with Reference (from file) ---");
        $display("Idx (R,C)| DUT (Hex) | Ref (Hex) | DUT (Real) | Ref (Real) | Abs Error | Status");
        $display("-----------------------------------------------------------------------------------");
        for (r_tb_loop = 0; r_tb_loop < N_TB; r_tb_loop = r_tb_loop + 1) begin
            for (c_tb_loop = 0; c_tb_loop < N_TB; c_tb_loop = c_tb_loop + 1) begin
             
                dut_val_fixed_comp_local_print_in_initial = Z_output_dut_2d[r_tb_loop][c_tb_loop]; 
                ref_val_real_from_file_tb = Z_reference_real_tb[r_tb_loop][c_tb_loop];
                ref_val_fixed_for_print_tb = real_to_fixed_tb(ref_val_real_from_file_tb); 
                
                // Convert DUT output to real for comparison
                dut_val_real_conv_comp_local_print_in_initial = fixed_to_real_tb(dut_val_fixed_comp_local_print_in_initial);

                // Calculate absolute error
                current_error_val_tb_val = dut_val_real_conv_comp_local_print_in_initial - ref_val_real_from_file_tb; 
                if (current_error_val_tb_val < 0) current_error_val_tb_val = -current_error_val_tb_val; // abs()

                // Track maximum absolute error
                if (current_error_val_tb_val > max_abs_error_val_tb_val) begin
                    max_abs_error_val_tb_val = current_error_val_tb_val; 
                end

                // Display comparison results for each element
                $write(" (%0d,%0d)   |  %4h     |  %4h     | %10.6f | %10.6f | %9.6f | ",
                             r_tb_loop, c_tb_loop, 
                             dut_val_fixed_comp_local_print_in_initial, 
                             ref_val_fixed_for_print_tb, 
                             dut_val_real_conv_comp_local_print_in_initial, 
                             ref_val_real_from_file_tb, 
                             current_error_val_tb_val);
                
                // Check if error exceeds threshold
                if (current_error_val_tb_val > ERROR_THRESHOLD_2D_VAL_TB_VAL) begin
                    $display("FAIL");
                    error_count_tb_val = error_count_tb_val + 1; 
                end else begin
                    $display("PASS");
                end
            end
        end
        $display("-----------------------------------------------------------------------------------");

        $fclose(ref_file_descriptor_2d_tb);
        $display("TB: Closed reference file: %s", REF_FILENAME_2D_TB);
        if (error_count_tb_val == 0) begin 
            $display("\nSUCCESS: 2D DCT Test PASSED!");
        end else begin
            $display("\nFAILURE: 2D DCT Test FAILED with %0d error(s).", error_count_tb_val); 
        end
        $display("Maximum absolute error observed: %f", max_abs_error_val_tb_val); 

        $finish; 
    end 
endmodule