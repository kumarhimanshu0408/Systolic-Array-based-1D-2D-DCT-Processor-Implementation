% =============================================================================
% MATLAB Script to Generate Reference Outputs for 1D DCT Systolic Array
% =============================================================================

% -------------------------------------------------------------------------
% Parameters
% -------------------------------------------------------------------------
N = 8;                    % 8-point DCT
NUM_TEST_CASES = 6;       % Number of test cases

% -------------------------------------------------------------------------
% Initialize Arrays
% -------------------------------------------------------------------------
test_patterns_real = zeros(NUM_TEST_CASES, N);      % Real-valued test inputs
ref_outputs_all_cases = zeros(NUM_TEST_CASES, N);   % Reference DCT outputs
test_names = cell(NUM_TEST_CASES, 1);              % Test case names

% -------------------------------------------------------------------------
% Define Test Patterns
% -------------------------------------------------------------------------
% Test Case 0: Negative ramp
test_names{1} = 'Negative ramp';
for i = 0:N-1
    test_patterns_real(1, i+1) = -1.0 + 2.0 * i / (N - 1);
end

% Test Case 1: Sine wave 1st harmonic
test_names{2} = 'Sine wave 1st harmonic';
for i = 0:N-1
    test_patterns_real(2, i+1) = sin(2.0 * pi * i / N);
end

% Test Case 2: Decaying exponential
test_names{3} = 'Decaying exponential';
for i = 0:N-1
    test_patterns_real(3, i+1) = exp(-0.5 * i);
end

% Test Case 3: Step function
test_names{4} = 'Step function';
for i = 0:N-1
    if i < N/2
        test_patterns_real(4, i+1) = -0.8;
    else
        test_patterns_real(4, i+1) = 0.8;
    end
end

% Test Case 4: Pseudo-random
test_names{5} = 'Pseudo-random';
for i = 0:N-1
    test_patterns_real(5, i+1) = mod(i * 17 + 5, 100) / 50.0 - 1.0; % Range [-1, 1)
end

% Test Case 5: Impulse at last index
test_names{6} = 'Impulse at last index';
for i = 0:N-1
    if i == N-1
        test_patterns_real(6, i+1) = 1.0;
    else
        test_patterns_real(6, i+1) = 0.0;
    end
end

% -------------------------------------------------------------------------
% Compute Reference DCT
% -------------------------------------------------------------------------
fprintf('Calculating reference DCTs in MATLAB...\n');
for tc = 1:NUM_TEST_CASES
    real_inputs_current_case = test_patterns_real(tc, :);
    ref_outputs_current_case = zeros(1, N);

    for k_idx = 0:N-1 % k in Verilog (0-indexed)
        current_sum = 0.0;
        for n_idx = 0:N-1 % n in Verilog (0-indexed)
            current_sum = current_sum + real_inputs_current_case(n_idx+1) * ...
                          cos(pi * (n_idx + 0.5) * k_idx / N);
        end

        % Scaling factors from Verilog testbench
        if k_idx == 0
            scale_factor = 0.1767766953; % sqrt(1/N)/2 for N=8
        else
            scale_factor = 0.25;         % sqrt(2/N)/2 for N=8
        end
        ref_outputs_current_case(k_idx+1) = scale_factor * current_sum;
    end
    ref_outputs_all_cases(tc, :) = ref_outputs_current_case;

    % Optional: Display for verification
    % fprintf('Test Case %d: %s\n', tc-1, test_names{tc});
    % disp('Inputs:'); disp(real_inputs_current_case);
    % disp('Ref Outputs:'); disp(ref_outputs_current_case);
    % fprintf('\n');
end

% -------------------------------------------------------------------------
% Save Reference Outputs to File
% -------------------------------------------------------------------------
output_filename = 'Systolic_1D_output_file.txt';
fid = fopen(output_filename, 'w');
if fid == -1
    error('Cannot open file %s for writing.', output_filename);
end

fprintf('Writing reference outputs to %s\n', output_filename);
for tc = 1:NUM_TEST_CASES
    for val_idx = 1:N
        fprintf(fid, '%.15e ', ref_outputs_all_cases(tc, val_idx));
    end
    fprintf(fid, '\n');
end
fclose(fid);
fprintf('Done. File %s created.\n', output_filename);

% -------------------------------------------------------------------------
% Verify Against MATLAB's Built-in dct() Function
% -------------------------------------------------------------------------
% MATLAB's dct() implements DCT-II:
% Y(k) = w(k) * sum_{n=1}^{N} x(n) * cos(pi*(2n-1)*(k-1) / (2N))
% w(k) = sqrt(1/N) for k=1
% w(k) = sqrt(2/N) for k=2...N
% Verilog reference is effectively: ref_outputs[k_v] = 0.5 * standard_DCT_II_output[k_v]

tc_to_verify = 1;
real_inputs_verify = test_patterns_real(tc_to_verify, :);
matlab_dct_ii_output = dct(real_inputs_verify);
scaled_matlab_dct = matlab_dct_ii_output / 2.0;

fprintf('\nVerification using MATLAB built-in dct() for test case 0:\n');
fprintf('Our scaled DCT        : '); fprintf('%.6f ', ref_outputs_all_cases(tc_to_verify, :)); fprintf('\n');
fprintf('MATLAB dct()/2.0      : '); fprintf('%.6f ', scaled_matlab_dct); fprintf('\n');
diff_dct = max(abs(ref_outputs_all_cases(tc_to_verify, :) - scaled_matlab_dct));
fprintf('Max difference: %e\n', diff_dct);
if diff_dct < 1e-9
    fprintf('Verification successful: Our manual calculation matches MATLAB''s dct()/2.0.\n');
    fprintf('This confirms the scaling used in the Verilog TB corresponds to 0.5 * standard DCT-II.\n');
else
    fprintf('Verification FAILED: Check scaling factors or formulas.\n');
end