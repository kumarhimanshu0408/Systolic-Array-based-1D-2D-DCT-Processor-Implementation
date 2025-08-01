% =============================================================================
% MATLAB Script to Generate Reference Outputs for 2D DCT Systolic Array
% =============================================================================

% -------------------------------------------------------------------------
% Parameters
% -------------------------------------------------------------------------
N_TB = 8; % Dimension of the DCT (e.g., 8 for 8x8)

% -------------------------------------------------------------------------
% Generate 2D Input Data
% -------------------------------------------------------------------------
fprintf('Generating 2D input data in MATLAB...\n');
x_input_real_2d = zeros(N_TB, N_TB);

for r_tb_loop_matlab = 1:N_TB
    for c_tb_loop_matlab = 1:N_TB
        r_verilog = r_tb_loop_matlab - 1;
        c_verilog = c_tb_loop_matlab - 1;

        val_tmp = (r_verilog * 0.12 + c_verilog * 0.08) - 0.6;
        % Clamp values to approximately [-0.99, 0.99]
        if val_tmp > 0.99
            val_tmp = 0.99;
        end
        if val_tmp < -0.99
            val_tmp = -0.99;
        end
        x_input_real_2d(r_tb_loop_matlab, c_tb_loop_matlab) = val_tmp;
    end
end

% Specific input overrides
x_input_real_2d(0+1, 0+1) = 0.75;
x_input_real_2d(1+1, 2+1) = -0.5;
x_input_real_2d(N_TB-1+1, N_TB-2+1) = 0.25;

% -------------------------------------------------------------------------
% Compute 2D DCT Reference
% -------------------------------------------------------------------------
fprintf('Calculating reference 2D DCT (2-pass 1D method) in MATLAB...\n');

Y_intermediate_real = zeros(N_TB, N_TB); % Intermediate row DCT results
Z_reference_real = zeros(N_TB, N_TB);   % Final real-valued reference output
PI_CONST = pi;

% Pass 1: Row-wise 1D DCTs
% Output is scaled by (alpha[v]/2) as per the Verilog task
% alpha[k] = sqrt(1/N) for k=0, sqrt(2/N) for k>0
for r_idx = 1:N_TB % Current row being processed
    for v_idx = 1:N_TB % Output coefficient index for the current row DCT
        sum_val = 0.0;
        for c_idx = 1:N_TB % Input element index along the row
            % Verilog uses 0-based indexing, MATLAB uses 1-based
            sum_val = sum_val + x_input_real_2d(r_idx, c_idx) * ...
                      cos(PI_CONST * ((c_idx-1) + 0.5) * (v_idx-1) / N_TB);
        end

        if (v_idx-1) == 0 % Verilog: v_idx_task == 0
            scale_factor_dim1 = sqrt(1.0/N_TB) / 2.0;
        else
            scale_factor_dim1 = sqrt(2.0/N_TB) / 2.0;
        end
        Y_intermediate_real(r_idx, v_idx) = scale_factor_dim1 * sum_val;
    end
end

% Pass 2: Column-wise 1D DCTs
% Input is Y_intermediate_real, output is scaled by (alpha[u]/2)
for v_col_idx = 1:N_TB % Current column being processed
    for u_row_idx = 1:N_TB % Output coefficient index for the current column DCT
        sum_val = 0.0;
        for r_sum_idx = 1:N_TB % Input element index down the column
            % Verilog uses 0-based indexing, MATLAB uses 1-based
            sum_val = sum_val + Y_intermediate_real(r_sum_idx, v_col_idx) * ...
                      cos(PI_CONST * ((r_sum_idx-1) + 0.5) * (u_row_idx-1) / N_TB);
        end

        if (u_row_idx-1) == 0 % Verilog: u_idx_task == 0
            scale_factor_dim2 = sqrt(1.0/N_TB) / 2.0;
        else
            scale_factor_dim2 = sqrt(2.0/N_TB) / 2.0;
        end
        % Verilog stores as Z_temp_real_task[u_idx_task][v_idx_task]
        % MATLAB equivalent: Z_reference_real(u_row_idx, v_col_idx)
        Z_reference_real(u_row_idx, v_col_idx) = scale_factor_dim2 * sum_val;
    end
end

% -------------------------------------------------------------------------
% Save Reference Outputs to File
% -------------------------------------------------------------------------
output_filename = 'Systolic_2D_output_file.txt';
fid = fopen(output_filename, 'w');
if fid == -1
    error('ERROR: Cannot open file "%s" for writing.', output_filename);
end

fprintf('Writing reference 2D DCT (real values) to "%s"...\n', output_filename);
for r_idx = 1:N_TB
    for c_idx = 1:N_TB
        fprintf(fid, '%.15e ', Z_reference_real(r_idx, c_idx)); % High precision
    end
    fprintf(fid, '\n'); % Newline for each row of the 2D DCT block
end
fclose(fid);
fprintf('Successfully created reference file: "%s".\n', output_filename);
fprintf('This file contains the expected 2D DCT outputs (real numbers) for the Verilog testbench.\n');
