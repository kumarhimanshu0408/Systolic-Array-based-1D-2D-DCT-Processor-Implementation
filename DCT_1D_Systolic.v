`timescale 1ns / 1ps

// =============================================================================
// Processing Unit (PU) for Addition and Subtraction
// =============================================================================
module PU (
    input              clk,
    input              rst,
    input  signed [15:0] x_i,  // Q1.15 format
    input  signed [15:0] x_j,  // Q1.15 format
    output reg signed [16:0] s,  // x_i + x_j (Q2.15 format)
    output reg signed [16:0] d   // x_i - x_j (Q2.15 format)
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            s <= 17'd0;
            d <= 17'd0;
        end else begin
            s <= {x_i[15], x_i} + {x_j[15], x_j}; // Sign-extended addition
            d <= {x_i[15], x_i} - {x_j[15], x_j}; // Sign-extended subtraction
        end
    end
endmodule

// =============================================================================
// Even Processing Element (EvenPE) for Even-Indexed DCT Coefficients
// =============================================================================
module EvenPE #(
    parameter signed [15:0] COEFF0 = 16'h0000,
    parameter signed [15:0] COEFF1 = 16'h0000,
    parameter signed [15:0] COEFF2 = 16'h0000,
    parameter signed [15:0] COEFF3 = 16'h0000
)(
    input              clk,
    input              rst,
    input  signed [16:0] s_in,          // s(n) input (Q2.15 format)
    input  signed [34:0] acc_in0,       // Partial sum 0 (Q5.30 format)
    input  signed [34:0] acc_in1,       // Partial sum 1 (Q5.30 format)
    input  signed [34:0] acc_in2,       // Partial sum 2 (Q5.30 format)
    input  signed [34:0] acc_in3,       // Partial sum 3 (Q5.30 format)
    output reg signed [34:0] acc_out0,  // Accumulated output 0 (Q5.30 format)
    output reg signed [34:0] acc_out1,  // Accumulated output 1 (Q5.30 format)
    output reg signed [34:0] acc_out2,  // Accumulated output 2 (Q5.30 format)
    output reg signed [34:0] acc_out3   // Accumulated output 3 (Q5.30 format)
);
    // Multiplications: s_in * coefficients
    wire signed [32:0] prod0 = s_in * COEFF0;
    wire signed [32:0] prod1 = s_in * COEFF1;
    wire signed [32:0] prod2 = s_in * COEFF2;
    wire signed [32:0] prod3 = s_in * COEFF3;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            acc_out0 <= 35'd0;
            acc_out1 <= 35'd0;
            acc_out2 <= 35'd0;
            acc_out3 <= 35'd0;
        end else begin
            acc_out0 <= acc_in0 + {{2{prod0[32]}}, prod0}; // Sign-extended accumulation
            acc_out1 <= acc_in1 + {{2{prod1[32]}}, prod1};
            acc_out2 <= acc_in2 + {{2{prod2[32]}}, prod2};
            acc_out3 <= acc_in3 + {{2{prod3[32]}}, prod3};
        end
    end
endmodule

// =============================================================================
// Odd Processing Element (OddPE) for Odd-Indexed DCT Coefficients
// =============================================================================
module OddPE #(
    parameter signed [15:0] COEFF0 = 16'h0000,
    parameter signed [15:0] COEFF1 = 16'h0000,
    parameter signed [15:0] COEFF2 = 16'h0000,
    parameter signed [15:0] COEFF3 = 16'h0000
)(
    input              clk,
    input              rst,
    input  signed [16:0] d_in,          // d(n) input (Q2.15 format)
    input  signed [34:0] acc_in0,       // Partial sum 0 (Q5.30 format)
    input  signed [34:0] acc_in1,       // Partial sum 1 (Q5.30 format)
    input  signed [34:0] acc_in2,       // Partial sum 2 (Q5.30 format)
    input  signed [34:0] acc_in3,       // Partial sum 3 (Q5.30 format)
    output reg signed [34:0] acc_out0,  // Accumulated output 0 (Q5.30 format)
    output reg signed [34:0] acc_out1,  // Accumulated output 1 (Q5.30 format)
    output reg signed [34:0] acc_out2,  // Accumulated output 2 (Q5.30 format)
    output reg signed [34:0] acc_out3   // Accumulated output 3 (Q5.30 format)
);
    // Multiplications: d_in * coefficients
    wire signed [32:0] prod0 = d_in * COEFF0;
    wire signed [32:0] prod1 = d_in * COEFF1;
    wire signed [32:0] prod2 = d_in * COEFF2;
    wire signed [32:0] prod3 = d_in * COEFF3;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            acc_out0 <= 35'd0;
            acc_out1 <= 35'd0;
            acc_out2 <= 35'd0;
            acc_out3 <= 35'd0;
        end else begin
            acc_out0 <= acc_in0 + {{2{prod0[32]}}, prod0}; // Sign-extended accumulation
            acc_out1 <= acc_in1 + {{2{prod1[32]}}, prod1};
            acc_out2 <= acc_in2 + {{2{prod2[32]}}, prod2};
            acc_out3 <= acc_in3 + {{2{prod3[32]}}, prod3};
        end
    end
endmodule

// =============================================================================
// 1D Discrete Cosine Transform (DCT) Systolic Array
// =============================================================================
module DCT_1D_Systolic (
    input              clk,
    input              rst,
    input  signed [15:0] x0, x1, x2, x3, x4, x5, x6, x7, // Inputs: Q1.15 format
    output reg signed [15:0] X0, X1, X2, X3, X4, X5, X6, X7 // Outputs: Q3.12 format
);
    // -------------------------------------------------------------------------
    // Coefficient Constants (Q0.15 effective format, representing MatrixElem * a_eff[k])
    // a_eff[0] = sqrt(1/N)/2 ≈ 0.17677 for N=8
    // a_eff[k] = sqrt(2/N)/2 = 0.25 for N=8, k>0
    // -------------------------------------------------------------------------
    parameter signed [15:0] C_ONE_SF0 = 16'h16A0; // 0.1767578125 (target 0.176776695)
    parameter signed [15:0] C_A_SFN   = 16'h16A1; // 0.17678833 (target 0.176776695, cos(pi/4)*0.25)
    parameter signed [15:0] C_B_SFN   = 16'h1D97; // 0.23118347 (target 0.23096988, cos(pi/8)*0.25)
    parameter signed [15:0] C_D_SFN   = 16'h0C40; // 0.095703125 (target 0.09567085, sin(pi/8)*0.25)
    parameter signed [15:0] C_S_SFN   = 16'h1F63; // 0.24519348 (target 0.24519632, cos(pi/16)*0.25)
    parameter signed [15:0] C_E_SFN   = 16'h1A9B; // 0.20787048 (target 0.20786740, cos(3pi/16)*0.25)
    parameter signed [15:0] C_M_SFN   = 16'h11C7; // 0.13888550 (target 0.13889255, cos(5pi/16)*0.25)
    parameter signed [15:0] C_T_SFN   = 16'h063E; // 0.04876709 (target 0.04877258, cos(7pi/16)*0.25)

    // -------------------------------------------------------------------------
    // PU Outputs (Q2.15 format)
    // -------------------------------------------------------------------------
    wire signed [16:0] s0, s1, s2, s3;
    wire signed [16:0] d0, d1, d2, d3;

    // -------------------------------------------------------------------------
    // Accumulator Arrays (Q5.30 format)
    // -------------------------------------------------------------------------
    wire signed [34:0] even_acc0 [0:4];
    wire signed [34:0] even_acc1 [0:4];
    wire signed [34:0] even_acc2 [0:4];
    wire signed [34:0] even_acc3 [0:4];
    wire signed [34:0] odd_acc0  [0:4];
    wire signed [34:0] odd_acc1  [0:4];
    wire signed [34:0] odd_acc2  [0:4];
    wire signed [34:0] odd_acc3  [0:4];

    // -------------------------------------------------------------------------
    // Instantiate PUs
    // -------------------------------------------------------------------------
    PU pu0 (.clk(clk), .rst(rst), .x_i(x0), .x_j(x7), .s(s0), .d(d0));
    PU pu1 (.clk(clk), .rst(rst), .x_i(x1), .x_j(x6), .s(s1), .d(d1));
    PU pu2 (.clk(clk), .rst(rst), .x_i(x2), .x_j(x5), .s(s2), .d(d2));
    PU pu3 (.clk(clk), .rst(rst), .x_i(x3), .x_j(x4), .s(s3), .d(d3));

    // -------------------------------------------------------------------------
    // Initialize Accumulator Inputs
    // -------------------------------------------------------------------------
    assign even_acc0[0] = 35'd0;
    assign even_acc1[0] = 35'd0;
    assign even_acc2[0] = 35'd0;
    assign even_acc3[0] = 35'd0;
    assign odd_acc0[0]  = 35'd0;
    assign odd_acc1[0]  = 35'd0;
    assign odd_acc2[0]  = 35'd0;
    assign odd_acc3[0]  = 35'd0;

    // -------------------------------------------------------------------------
    // Instantiate EvenPEs
    // -------------------------------------------------------------------------
    EvenPE #(C_ONE_SF0,  C_B_SFN,  C_A_SFN,  C_D_SFN) even_pe0 (
        .clk(clk), .rst(rst), .s_in(s0),
        .acc_in0(even_acc0[0]), .acc_in1(even_acc1[0]), .acc_in2(even_acc2[0]), .acc_in3(even_acc3[0]),
        .acc_out0(even_acc0[1]), .acc_out1(even_acc1[1]), .acc_out2(even_acc2[1]), .acc_out3(even_acc3[1])
    );
    EvenPE #(C_ONE_SF0,  C_D_SFN, -C_A_SFN, -C_B_SFN) even_pe1 (
        .clk(clk), .rst(rst), .s_in(s1),
        .acc_in0(even_acc0[1]), .acc_in1(even_acc1[1]), .acc_in2(even_acc2[1]), .acc_in3(even_acc3[1]),
        .acc_out0(even_acc0[2]), .acc_out1(even_acc1[2]), .acc_out2(even_acc2[2]), .acc_out3(even_acc3[2])
    );
    EvenPE #(C_ONE_SF0, -C_D_SFN, -C_A_SFN,  C_B_SFN) even_pe2 (
        .clk(clk), .rst(rst), .s_in(s2),
        .acc_in0(even_acc0[2]), .acc_in1(even_acc1[2]), .acc_in2(even_acc2[2]), .acc_in3(even_acc3[2]),
        .acc_out0(even_acc0[3]), .acc_out1(even_acc1[3]), .acc_out2(even_acc2[3]), .acc_out3(even_acc3[3])
    );
    EvenPE #(C_ONE_SF0, -C_B_SFN,  C_A_SFN, -C_D_SFN) even_pe3 (
        .clk(clk), .rst(rst), .s_in(s3),
        .acc_in0(even_acc0[3]), .acc_in1(even_acc1[3]), .acc_in2(even_acc2[3]), .acc_in3(even_acc3[3]),
        .acc_out0(even_acc0[4]), .acc_out1(even_acc1[4]), .acc_out2(even_acc2[4]), .acc_out3(even_acc3[4])
    );

    // -------------------------------------------------------------------------
    // Instantiate OddPEs
    // -------------------------------------------------------------------------
    OddPE #(C_S_SFN,  C_E_SFN,  C_M_SFN,  C_T_SFN) odd_pe0 (
        .clk(clk), .rst(rst), .d_in(d0),
        .acc_in0(odd_acc0[0]), .acc_in1(odd_acc1[0]), .acc_in2(odd_acc2[0]), .acc_in3(odd_acc3[0]),
        .acc_out0(odd_acc0[1]), .acc_out1(odd_acc1[1]), .acc_out2(odd_acc2[1]), .acc_out3(odd_acc3[1])
    );
    OddPE #(C_E_SFN, -C_T_SFN, -C_S_SFN, -C_M_SFN) odd_pe1 (
        .clk(clk), .rst(rst), .d_in(d1),
        .acc_in0(odd_acc0[1]), .acc_in1(odd_acc1[1]), .acc_in2(odd_acc2[1]), .acc_in3(odd_acc3[1]),
        .acc_out0(odd_acc0[2]), .acc_out1(odd_acc1[2]), .acc_out2(odd_acc2[2]), .acc_out3(odd_acc3[2])
    );
    OddPE #(C_M_SFN, -C_S_SFN,  C_T_SFN,  C_E_SFN) odd_pe2 (
        .clk(clk), .rst(rst), .d_in(d2),
        .acc_in0(odd_acc0[2]), .acc_in1(odd_acc1[2]), .acc_in2(odd_acc2[2]), .acc_in3(odd_acc3[2]),
        .acc_out0(odd_acc0[3]), .acc_out1(odd_acc1[3]), .acc_out2(odd_acc2[3]), .acc_out3(odd_acc3[3])
    );
    OddPE #(C_T_SFN, -C_M_SFN,  C_E_SFN, -C_S_SFN) odd_pe3 (
        .clk(clk), .rst(rst), .d_in(d3),
        .acc_in0(odd_acc0[3]), .acc_in1(odd_acc1[3]), .acc_in2(odd_acc2[3]), .acc_in3(odd_acc3[3]),
        .acc_out0(odd_acc0[4]), .acc_out1(odd_acc1[4]), .acc_out2(odd_acc2[4]), .acc_out3(odd_acc3[4])
    );

    // -------------------------------------------------------------------------
    // Format Conversion Function: Q5.30 to Q3.12 with Rounding and Saturation
    // -------------------------------------------------------------------------
    function signed [15:0] convert_q5_30_to_q3_12;
        input signed [34:0] value_q5_30;
        reg signed [34:0] rounded_value;
        reg signed [17:0] temp_q5_12;
        parameter signed [15:0] MAX_OUT_Q312 = 16'h7FFF;
        parameter signed [15:0] MIN_OUT_Q312 = 16'h8000;
        parameter signed [17:0] FOUR_Q512 = 18'sd16384;
        reg signed [15:0] final_result;
        begin
            rounded_value = value_q5_30 + (1 << 17); // Rounding
            temp_q5_12 = rounded_value >>> 18;       // Shift to Q5.12
            if (temp_q5_12 >= FOUR_Q512) begin
                final_result = MAX_OUT_Q312;         // Saturate to max
            end else if (temp_q5_12 < -FOUR_Q512) begin
                final_result = MIN_OUT_Q312;         // Saturate to min
            end else begin
                final_result = temp_q5_12[15:0];     // Truncate to Q3.12
            end
            convert_q5_30_to_q3_12 = final_result;
        end
    endfunction

    // -------------------------------------------------------------------------
    // Output Registers
    // -------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            X0 <= 16'd0;
            X1 <= 16'd0;
            X2 <= 16'd0;
            X3 <= 16'd0;
            X4 <= 16'd0;
            X5 <= 16'd0;
            X6 <= 16'd0;
            X7 <= 16'd0;
        end else begin
            X0 <= convert_q5_30_to_q3_12(even_acc0[4]);
            X2 <= convert_q5_30_to_q3_12(even_acc1[4]);
            X4 <= convert_q5_30_to_q3_12(even_acc2[4]);
            X6 <= convert_q5_30_to_q3_12(even_acc3[4]);
            X1 <= convert_q5_30_to_q3_12(odd_acc0[4]);
            X3 <= convert_q5_30_to_q3_12(odd_acc1[4]);
            X5 <= convert_q5_30_to_q3_12(odd_acc2[4]);
            X7 <= convert_q5_30_to_q3_12(odd_acc3[4]);
        end
    end
endmodule