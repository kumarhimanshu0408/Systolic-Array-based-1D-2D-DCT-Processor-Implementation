`timescale 1ns / 1ps

// =============================================================================
// Testbench for 1D Discrete Cosine Transform (DCT) Systolic Array
// =============================================================================
module DCT_1D_Systolic_tb;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    parameter CLK_PERIOD      = 10;     // 10ns (100MHz)
    parameter N               = 8;      // 8-point DCT
    parameter DATA_WIDTH      = 16;     // Q1.15 format for input
    parameter NUM_TEST_CASES  = 6;
    parameter ERROR_THRESHOLD = 0.005;  // 0.5%
    parameter REF_FILENAME    = "E:/4th_year/VLSI_lab_course/Mini Project/Matlab/Systolic_1D_output_file.txt";

    // -------------------------------------------------------------------------
    // Signals
    // -------------------------------------------------------------------------
    reg                         clk = 0;
    reg                         rst;
    reg  signed [DATA_WIDTH-1:0] x [0:N-1];
    wire signed [DATA_WIDTH-1:0] X [0:N-1]; // Outputs in Q3.12 format

    // Real-valued arrays for inputs, references, and DUT outputs
    real real_inputs[0:N-1];
    real ref_outputs[0:N-1];
    real dut_outputs[0:N-1];
    real test_patterns[0:NUM_TEST_CASES-1][0:N-1];
    reg  [128*8-1:0] test_names[0:NUM_TEST_CASES-1];

    // Testbench control variables
    integer i, k;
    integer test_case;
    integer errors;
    integer total_errors = 0;
    real    max_error, abs_error, temp_error;

    // File handling
    integer ref_file_descriptor;
    integer fscanf_status;

    // Clock generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // Input assignments
    wire signed [DATA_WIDTH-1:0] x0 = x[0];
    wire signed [DATA_WIDTH-1:0] x1 = x[1];
    wire signed [DATA_WIDTH-1:0] x2 = x[2];
    wire signed [DATA_WIDTH-1:0] x3 = x[3];
    wire signed [DATA_WIDTH-1:0] x4 = x[4];
    wire signed [DATA_WIDTH-1:0] x5 = x[5];
    wire signed [DATA_WIDTH-1:0] x6 = x[6];
    wire signed [DATA_WIDTH-1:0] x7 = x[7];

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    DCT_1D_Systolic dut (
        .clk(clk), .rst(rst),
        .x0(x0), .x1(x1), .x2(x2), .x3(x3),
        .x4(x4), .x5(x5), .x6(x6), .x7(x7),
        .X0(X[0]), .X1(X[1]), .X2(X[2]), .X3(X[3]),
        .X4(X[4]), .X5(X[5]), .X6(X[6]), .X7(X[7])
    );

    // -------------------------------------------------------------------------
    // Helper Functions
    // -------------------------------------------------------------------------
    // Convert real to Q1.15 (for inputs)
    function signed [DATA_WIDTH-1:0] real_to_fixed_q1_15;
        input real val;
        real      scaled_val;
        integer   int_val;
        begin
            if (val >= 1.0) scaled_val = 32767.0;
            else if (val < -1.0) scaled_val = -32768.0;
            else scaled_val = val * 32767.0;

            int_val = (scaled_val >= 0) ? scaled_val + 0.5 : scaled_val - 0.5;

            if (int_val > 32767) int_val = 32767;
            if (int_val < -32768) int_val = -32768;
            real_to_fixed_q1_15 = int_val;
        end
    endfunction

    // Convert fixed Q3.12 to real
    function real fixed_to_real_q3_12;
        input signed [DATA_WIDTH-1:0] v;
        parameter NUM_FRAC_BITS_OUT = 12;
        begin
            fixed_to_real_q3_12 = $itor(v) / (1.0 * (1 << NUM_FRAC_BITS_OUT));
        end
    endfunction

    // -------------------------------------------------------------------------
    // Tasks
    // -------------------------------------------------------------------------
    task wait_for_pipeline;
        begin
            repeat (10) @(posedge clk);
        end
    endtask

    task init_test_patterns;
        begin
            test_names[0] = "Negative ramp";
            for (i = 0; i < N; i = i + 1)
                test_patterns[0][i] = -1.0 + 2.0 * i / (N - 1);

            test_names[1] = "Sine wave 1st harmonic";
            for (i = 0; i < N; i = i + 1)
                test_patterns[1][i] = $sin(2.0 * 3.1415926535 * i / N);

            test_names[2] = "Decaying exponential";
            for (i = 0; i < N; i = i + 1)
                test_patterns[2][i] = $exp(-0.5 * i);

            test_names[3] = "Step function";
            for (i = 0; i < N; i = i + 1)
                test_patterns[3][i] = (i < N/2) ? -0.8 : 0.8;

            test_names[4] = "Pseudo-random";
            for (i = 0; i < N; i = i + 1)
                test_patterns[4][i] = ((i * 17 + 5) % 100) / 50.0 - 1.0;

            test_names[5] = "Impulse at last index";
            for (i = 0; i < N; i = i + 1)
                test_patterns[5][i] = (i == N-1) ? 1.0 : 0.0;
        end
    endtask

    task read_reference_outputs_from_file;
        begin
            for (k = 0; k < N; k = k + 1) begin
                fscanf_status = $fscanf(ref_file_descriptor, "%f", ref_outputs[k]);
                if (fscanf_status != 1) begin
                    $display("ERROR: Failed to read reference output for index %0d from file %s. Test case %0d.",
                             k, REF_FILENAME, test_case);
                    $display("Check if file exists, has correct format, and enough data.");
                    $finish;
                end
            end
        end
    endtask

    task run_test_case;
        input integer tc;
        begin
            errors = 0;
            max_error = 0;
            $display("\n--- Test %0d: %s ---", tc, test_names[tc]);

            // Prepare inputs
            for (i = 0; i < N; i = i + 1) begin
                real_inputs[i] = test_patterns[tc][i];
                x[i] = real_to_fixed_q1_15(real_inputs[i]);
            end

            // Read reference outputs
            read_reference_outputs_from_file();

            // Apply inputs and wait for pipeline
            @(posedge clk);
            wait_for_pipeline();

            // Convert DUT outputs to real
            for (i = 0; i < N; i = i + 1)
                dut_outputs[i] = fixed_to_real_q3_12(X[i]);

            // Display results
            $display("Idx | In (real) | DUT (real) | Ref (file) | AbsErr | Result");
            for (i = 0; i < N; i = i + 1) begin
                temp_error = dut_outputs[i] - ref_outputs[i];
                abs_error = (temp_error < 0) ? -temp_error : temp_error;
                if (abs_error > max_error) max_error = abs_error;
                $write(" %0d  | %9.6f | %9.6f | %9.6f | %9.6f | ",
                       i, real_inputs[i], dut_outputs[i], ref_outputs[i], abs_error);
                if (abs_error > ERROR_THRESHOLD) begin
                    $display("FAIL");
                    errors = errors + 1;
                end else begin
                    $display("PASS");
                end
            end
            $display("Test %0d Summary: MaxErr=%f, %s", tc, max_error, (errors == 0) ? "PASS" : "FAIL");
            total_errors = total_errors + errors;
        end
    endtask

    // -------------------------------------------------------------------------
    // Main Test Sequence
    // -------------------------------------------------------------------------
    initial begin
        // Initialize test patterns
        init_test_patterns();

        // Open reference file
        ref_file_descriptor = $fopen(REF_FILENAME, "r");
        if (ref_file_descriptor == 0) begin
            $display("ERROR: Could not open reference file: %s", REF_FILENAME);
            $finish;
        end
        $display("Opened reference file: %s", REF_FILENAME);

        // Reset sequence
        rst = 1;
        for (i = 0; i < N; i = i + 1) x[i] = 0;
        repeat (3) @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Run all test cases
        for (test_case = 0; test_case < NUM_TEST_CASES; test_case = test_case + 1) begin
            run_test_case(test_case);
            repeat (2) @(posedge clk);
        end

        // Close reference file
        $fclose(ref_file_descriptor);
        $display("Closed reference file: %s", REF_FILENAME);

        // Display final results
        $display("\n=== All done: Total errors = %0d, %s ===", total_errors, (total_errors == 0) ? "PASS" : "FAIL");
        $finish;
    end
endmodule