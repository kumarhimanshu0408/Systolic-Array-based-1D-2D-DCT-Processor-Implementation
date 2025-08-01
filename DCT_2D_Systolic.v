
`timescale 1ns / 1ps

`define DATA_W 16
`define N_DIM 8

module PU (
    input clk,
    input rst,
    input signed [`DATA_W-1:0] x_i,
    input signed [`DATA_W-1:0] x_j,
    output reg signed [`DATA_W:0] s,  
    output reg signed [`DATA_W:0] d   
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            s <= {(`DATA_W+1){1'b0}}; 
            d <= {(`DATA_W+1){1'b0}};
        end else begin
            s <= {x_i[`DATA_W-1], x_i} + {x_j[`DATA_W-1], x_j};
            d <= {x_i[`DATA_W-1], x_i} - {x_j[`DATA_W-1], x_j};
        end
    end
endmodule
module EvenPE #(
    parameter signed [`DATA_W-1:0] COEFF0 = {(`DATA_W){1'b0}}, 
    parameter signed [`DATA_W-1:0] COEFF1 = {(`DATA_W){1'b0}},
    parameter signed [`DATA_W-1:0] COEFF2 = {(`DATA_W){1'b0}},
    parameter signed [`DATA_W-1:0] COEFF3 = {(`DATA_W){1'b0}}
)(
    input clk,
    input rst,
    input signed [`DATA_W:0] s_in,      // s(n) input (Q2.15)
    input signed [34:0] acc_in0,   // partial sums (Q5.30)
    input signed [34:0] acc_in1,
    input signed [34:0] acc_in2,
    input signed [34:0] acc_in3,
    output reg signed [34:0] acc_out0,
    output reg signed [34:0] acc_out1,
    output reg signed [34:0] acc_out2,
    output reg signed [34:0] acc_out3
);
    wire signed [32:0] prod0 = s_in * COEFF0; 
    wire signed [32:0] prod1 = s_in * COEFF1;
    wire signed [32:0] prod2 = s_in * COEFF2;
    wire signed [32:0] prod3 = s_in * COEFF3;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            acc_out0 <= 35'sd0; acc_out1 <= 35'sd0;
            acc_out2 <= 35'sd0; acc_out3 <= 35'sd0;
        end else begin
            acc_out0 <= acc_in0 + {{2{prod0[32]}}, prod0};
            acc_out1 <= acc_in1 + {{2{prod1[32]}}, prod1};
            acc_out2 <= acc_in2 + {{2{prod2[32]}}, prod2};
            acc_out3 <= acc_in3 + {{2{prod3[32]}}, prod3};
        end
    end
endmodule

module OddPE #(
    parameter signed [`DATA_W-1:0] COEFF0 = {(`DATA_W){1'b0}},
    parameter signed [`DATA_W-1:0] COEFF1 = {(`DATA_W){1'b0}},
    parameter signed [`DATA_W-1:0] COEFF2 = {(`DATA_W){1'b0}},
    parameter signed [`DATA_W-1:0] COEFF3 = {(`DATA_W){1'b0}}
)(
    input clk,
    input rst,
    input signed [`DATA_W:0] d_in,      // d(n) input (Q2.15
    input signed [34:0] acc_in0,   // partial sums (Q5.30)
    input signed [34:0] acc_in1,
    input signed [34:0] acc_in2,
    input signed [34:0] acc_in3,
    output reg signed [34:0] acc_out0,
    output reg signed [34:0] acc_out1,
    output reg signed [34:0] acc_out2,
    output reg signed [34:0] acc_out3
);
    wire signed [32:0] prod0 = d_in * COEFF0;
    wire signed [32:0] prod1 = d_in * COEFF1;
    wire signed [32:0] prod2 = d_in * COEFF2;
    wire signed [32:0] prod3 = d_in * COEFF3;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            acc_out0 <= 35'sd0; acc_out1 <= 35'sd0;
            acc_out2 <= 35'sd0; acc_out3 <= 35'sd0;
        end else begin
            acc_out0 <= acc_in0 + {{2{prod0[32]}}, prod0};
            acc_out1 <= acc_in1 + {{2{prod1[32]}}, prod1};
            acc_out2 <= acc_in2 + {{2{prod2[32]}}, prod2};
            acc_out3 <= acc_in3 + {{2{prod3[32]}}, prod3};
        end
    end
endmodule

module DCT_1D_Systolic (
    input clk,
    input rst,
    input signed [`DATA_W-1:0] x0, x1, x2, x3, x4, x5, x6, x7, // input Q1.15
    output reg signed [`DATA_W-1:0] X0, X1, X2, X3, X4, X5, X6, X7 // output: Q1.15
);

    localparam signed [`DATA_W-1:0] C_A_SFN  = 16'h16a1; 
    localparam signed [`DATA_W-1:0] C_B_SFN  = 16'h1d97; 
    localparam signed [`DATA_W-1:0] C_D_SFN  = 16'h0c40; 
    localparam signed [`DATA_W-1:0] C_S_SFN  = 16'h1f63; 
    localparam signed [`DATA_W-1:0] C_E_SFN  = 16'h1a9b; 
    localparam signed [`DATA_W-1:0] C_M_SFN  = 16'h11c7; 
    localparam signed [`DATA_W-1:0] C_T_SFN  = 16'h063e; 
    localparam signed [`DATA_W-1:0] C_ONE_SF0 = 16'h16a0; 

    wire signed [`DATA_W:0] s0,s1,s2,s3, d0,d1,d2,d3; 
    PU pu0_i(clk,rst,x0,x7,s0,d0); PU pu1_i(clk,rst,x1,x6,s1,d1);
    PU pu2_i(clk,rst,x2,x5,s2,d2); PU pu3_i(clk,rst,x3,x4,s3,d3);

    wire signed [34:0] even_acc0_w[0:4], even_acc1_w[0:4], even_acc2_w[0:4], even_acc3_w[0:4];
    wire signed [34:0] odd_acc0_w[0:4], odd_acc1_w[0:4], odd_acc2_w[0:4], odd_acc3_w[0:4];

    assign even_acc0_w[0]=35'sd0; assign even_acc1_w[0]=35'sd0; assign even_acc2_w[0]=35'sd0; assign even_acc3_w[0]=35'sd0;
    assign odd_acc0_w[0]=35'sd0; assign odd_acc1_w[0]=35'sd0; assign odd_acc2_w[0]=35'sd0; assign odd_acc3_w[0]=35'sd0;

    EvenPE #(C_ONE_SF0,C_B_SFN,C_A_SFN,C_D_SFN) ep0_i(clk,rst,s0,even_acc0_w[0],even_acc1_w[0],even_acc2_w[0],even_acc3_w[0],even_acc0_w[1],even_acc1_w[1],even_acc2_w[1],even_acc3_w[1]);
    EvenPE #(C_ONE_SF0,C_D_SFN,-C_A_SFN,-C_B_SFN) ep1_i(clk,rst,s1,even_acc0_w[1],even_acc1_w[1],even_acc2_w[1],even_acc3_w[1],even_acc0_w[2],even_acc1_w[2],even_acc2_w[2],even_acc3_w[2]);
    EvenPE #(C_ONE_SF0,-C_D_SFN,-C_A_SFN,C_B_SFN) ep2_i(clk,rst,s2,even_acc0_w[2],even_acc1_w[2],even_acc2_w[2],even_acc3_w[2],even_acc0_w[3],even_acc1_w[3],even_acc2_w[3],even_acc3_w[3]);
    EvenPE #(C_ONE_SF0,-C_B_SFN,C_A_SFN,-C_D_SFN) ep3_i(clk,rst,s3,even_acc0_w[3],even_acc1_w[3],even_acc2_w[3],even_acc3_w[3],even_acc0_w[4],even_acc1_w[4],even_acc2_w[4],even_acc3_w[4]);

    OddPE #(C_S_SFN,C_E_SFN,C_M_SFN,C_T_SFN) op0_i(clk,rst,d0,odd_acc0_w[0],odd_acc1_w[0],odd_acc2_w[0],odd_acc3_w[0],odd_acc0_w[1],odd_acc1_w[1],odd_acc2_w[1],odd_acc3_w[1]);
    OddPE #(C_E_SFN,-C_T_SFN,-C_S_SFN,-C_M_SFN) op1_i(clk,rst,d1,odd_acc0_w[1],odd_acc1_w[1],odd_acc2_w[1],odd_acc3_w[1],odd_acc0_w[2],odd_acc1_w[2],odd_acc2_w[2],odd_acc3_w[2]);
    OddPE #(C_M_SFN,-C_S_SFN,C_T_SFN,C_E_SFN) op2_i(clk,rst,d2,odd_acc0_w[2],odd_acc1_w[2],odd_acc2_w[2],odd_acc3_w[2],odd_acc0_w[3],odd_acc1_w[3],odd_acc2_w[3],odd_acc3_w[3]);
    OddPE #(C_T_SFN,-C_M_SFN,C_E_SFN,-C_S_SFN) op3_i(clk,rst,d3,odd_acc0_w[3],odd_acc1_w[3],odd_acc2_w[3],odd_acc3_w[3],odd_acc0_w[4],odd_acc1_w[4],odd_acc2_w[4],odd_acc3_w[4]);

    function signed [`DATA_W-1:0] convert_q5_30_to_q1_15(input signed [34:0] value_q5_30);
        reg signed [34:0] rounded_value;
        reg signed [20:0] temp_q5_15; 
        localparam signed[`DATA_W-1:0] MAX_Q115 = {1'b0, {(`DATA_W-1){1'b1}}}; 
        localparam signed[`DATA_W-1:0] MIN_Q115 = {1'b1, {(`DATA_W-1){1'b0}}}; 
        localparam signed[20:0] ONE_AS_Q515 = (1 << 15); 
        reg signed[`DATA_W-1:0] final_result_q115;
    begin 
        rounded_value = value_q5_30 + (1 << 14); 
        temp_q5_15 = rounded_value >>> 15; 

        if (temp_q5_15 >= ONE_AS_Q515) begin 
            final_result_q115 = MAX_Q115;
        end else if (temp_q5_15 < -ONE_AS_Q515) begin 
             final_result_q115 = MIN_Q115;
        end else begin
            final_result_q115 = temp_q5_15[`DATA_W-1:0]; 
        end
        convert_q5_30_to_q1_15 = final_result_q115;
    end
    endfunction
    
    always @(posedge clk or posedge rst) begin
        if(rst) begin
             X0 <= {(`DATA_W){1'b0}}; X1 <= {(`DATA_W){1'b0}}; X2 <= {(`DATA_W){1'b0}}; X3 <= {(`DATA_W){1'b0}};
             X4 <= {(`DATA_W){1'b0}}; X5 <= {(`DATA_W){1'b0}}; X6 <= {(`DATA_W){1'b0}}; X7 <= {(`DATA_W){1'b0}};
        end else begin
             X0 <= convert_q5_30_to_q1_15(even_acc0_w[4]);
             X1 <= convert_q5_30_to_q1_15(odd_acc0_w[4]);
             X2 <= convert_q5_30_to_q1_15(even_acc1_w[4]);
             X3 <= convert_q5_30_to_q1_15(odd_acc1_w[4]);
             X4 <= convert_q5_30_to_q1_15(even_acc2_w[4]);
             X5 <= convert_q5_30_to_q1_15(odd_acc2_w[4]);
             X6 <= convert_q5_30_to_q1_15(even_acc3_w[4]);
             X7 <= convert_q5_30_to_q1_15(odd_acc3_w[4]);
        end
    end
endmodule

module DCT_2D_Systolic #(
    parameter P_N_DIM = `N_DIM,   
    parameter P_DATA_W = `DATA_W 
) (
    input clk,
    input rst,
    input [(P_N_DIM * P_N_DIM * P_DATA_W)-1:0] x_in_flat, // input: Q1.15
    output [(P_N_DIM * P_N_DIM * P_DATA_W)-1:0] Z_out_flat  // output: Q1.15
);

    localparam N_DIM = P_N_DIM; 
    localparam DATA_W = P_DATA_W;


    reg signed [DATA_W-1:0] x_in_matrix [N_DIM-1:0] [N_DIM-1:0];             
    wire signed [DATA_W-1:0] Y_row_transformed_wires [N_DIM-1:0] [N_DIM-1:0]; 
    reg signed [DATA_W-1:0] Y_row_transformed_reg [N_DIM-1:0] [N_DIM-1:0];   
    wire signed [DATA_W-1:0] Y_T_transformed_wires [N_DIM-1:0] [N_DIM-1:0];   
    reg signed [DATA_W-1:0] Y_T_transformed_reg [N_DIM-1:0] [N_DIM-1:0];     
    wire signed [DATA_W-1:0] Z_out_matrix_wires [N_DIM-1:0] [N_DIM-1:0];   
    reg signed [DATA_W-1:0] Z_out_matrix_reg [N_DIM-1:0] [N_DIM-1:0];     

    integer r_idx_loop, c_idx_loop; 

    always @(*) begin : unpack_x_input_comb
        integer r_local, c_local; 
        for (r_local = 0; r_local < N_DIM; r_local = r_local + 1) begin
            for (c_local = 0; c_local < N_DIM; c_local = c_local + 1) begin
                x_in_matrix[r_local][c_local] = x_in_flat[ (r_local * N_DIM + c_local) * DATA_W +: DATA_W ];
            end
        end
    end

    genvar r1_genvar;
    generate 
        for (r1_genvar = 0; r1_genvar < N_DIM; r1_genvar = r1_genvar + 1) begin : gen_row_dcts_instance_block
            DCT_1D_Systolic #( .DATA_W(DATA_W) ) 
             row_dct_inst_unit (
                .clk(clk), .rst(rst),
                .x0(x_in_matrix[r1_genvar][0]), .x1(x_in_matrix[r1_genvar][1]), 
                .x2(x_in_matrix[r1_genvar][2]), .x3(x_in_matrix[r1_genvar][3]),
                .x4(x_in_matrix[r1_genvar][4]), .x5(x_in_matrix[r1_genvar][5]), 
                .x6(x_in_matrix[r1_genvar][6]), .x7(x_in_matrix[r1_genvar][7]),
                .X0(Y_row_transformed_wires[r1_genvar][0]), .X1(Y_row_transformed_wires[r1_genvar][1]),
                .X2(Y_row_transformed_wires[r1_genvar][2]), .X3(Y_row_transformed_wires[r1_genvar][3]),
                .X4(Y_row_transformed_wires[r1_genvar][4]), .X5(Y_row_transformed_wires[r1_genvar][5]),
                .X6(Y_row_transformed_wires[r1_genvar][6]), .X7(Y_row_transformed_wires[r1_genvar][7])
            );
        end
    endgenerate

    always @(posedge clk or posedge rst) begin : reg_Y_row_transformed_block
        if (rst) begin
            for (r_idx_loop = 0; r_idx_loop < N_DIM; r_idx_loop = r_idx_loop + 1) begin
                for (c_idx_loop = 0; c_idx_loop < N_DIM; c_idx_loop = c_idx_loop + 1) begin
                    Y_row_transformed_reg[r_idx_loop][c_idx_loop] <= {(DATA_W){1'b0}};
                end
            end
        end else begin
            for (r_idx_loop = 0; r_idx_loop < N_DIM; r_idx_loop = r_idx_loop + 1) begin
                for (c_idx_loop = 0; c_idx_loop < N_DIM; c_idx_loop = c_idx_loop + 1) begin
                    Y_row_transformed_reg[r_idx_loop][c_idx_loop] <= Y_row_transformed_wires[r_idx_loop][c_idx_loop];
                end
            end
        end
    end

    genvar tr_r_genvar, tr_c_genvar;
    generate 
        for (tr_r_genvar = 0; tr_r_genvar < N_DIM; tr_r_genvar = tr_r_genvar + 1) begin : gen_transpose_rows_instance_block
            for (tr_c_genvar = 0; tr_c_genvar < N_DIM; tr_c_genvar = tr_c_genvar + 1) begin : gen_transpose_cols_instance_block
                assign Y_T_transformed_wires[tr_c_genvar][tr_r_genvar] = Y_row_transformed_reg[tr_r_genvar][tr_c_genvar];
            end
        end
    endgenerate

    always @(posedge clk or posedge rst) begin : reg_Y_T_transposed_block
        if (rst) begin
            for (r_idx_loop = 0; r_idx_loop < N_DIM; r_idx_loop = r_idx_loop + 1) begin
                for (c_idx_loop = 0; c_idx_loop < N_DIM; c_idx_loop = c_idx_loop + 1) begin
                    Y_T_transformed_reg[r_idx_loop][c_idx_loop] <= {(DATA_W){1'b0}};
                end
            end
        end else begin
             for (r_idx_loop = 0; r_idx_loop < N_DIM; r_idx_loop = r_idx_loop + 1) begin
                for (c_idx_loop = 0; c_idx_loop < N_DIM; c_idx_loop = c_idx_loop + 1) begin
                    Y_T_transformed_reg[r_idx_loop][c_idx_loop] <= Y_T_transformed_wires[r_idx_loop][c_idx_loop];
                end
            end
        end
    end
    
    genvar c1_genvar;
    generate 
        for (c1_genvar = 0; c1_genvar < N_DIM; c1_genvar = c1_genvar + 1) begin : gen_col_dcts_instance_block
             DCT_1D_Systolic #( .DATA_W(DATA_W) ) 
              col_dct_inst_unit (
                .clk(clk), .rst(rst),
                .x0(Y_T_transformed_reg[c1_genvar][0]), .x1(Y_T_transformed_reg[c1_genvar][1]), 
                .x2(Y_T_transformed_reg[c1_genvar][2]), .x3(Y_T_transformed_reg[c1_genvar][3]),
                .x4(Y_T_transformed_reg[c1_genvar][4]), .x5(Y_T_transformed_reg[c1_genvar][5]),
                .x6(Y_T_transformed_reg[c1_genvar][6]), .x7(Y_T_transformed_reg[c1_genvar][7]),
                .X0(Z_out_matrix_wires[c1_genvar][0]), .X1(Z_out_matrix_wires[c1_genvar][1]), 
                .X2(Z_out_matrix_wires[c1_genvar][2]), .X3(Z_out_matrix_wires[c1_genvar][3]), 
                .X4(Z_out_matrix_wires[c1_genvar][4]), .X5(Z_out_matrix_wires[c1_genvar][5]), 
                .X6(Z_out_matrix_wires[c1_genvar][6]), .X7(Z_out_matrix_wires[c1_genvar][7])
            );
        end
    endgenerate

     always @(posedge clk or posedge rst) begin : reg_Z_out_matrix_block
        if (rst) begin
            for (r_idx_loop = 0; r_idx_loop < N_DIM; r_idx_loop = r_idx_loop + 1) begin
                for (c_idx_loop = 0; c_idx_loop < N_DIM; c_idx_loop = c_idx_loop + 1) begin
                    Z_out_matrix_reg[r_idx_loop][c_idx_loop] <= {(DATA_W){1'b0}};
                end
            end
        end else begin
             for (r_idx_loop = 0; r_idx_loop < N_DIM; r_idx_loop = r_idx_loop + 1) begin
                for (c_idx_loop = 0; c_idx_loop < N_DIM; c_idx_loop = c_idx_loop + 1) begin
                    Z_out_matrix_reg[r_idx_loop][c_idx_loop] <= Z_out_matrix_wires[r_idx_loop][c_idx_loop];
                end
            end
        end
    end
    genvar row_idx_gen, col_idx_gen; 
    generate
      for(row_idx_gen=0; row_idx_gen < N_DIM; row_idx_gen = row_idx_gen + 1) begin: final_pack_row_loop 
        for(col_idx_gen=0; col_idx_gen < N_DIM; col_idx_gen = col_idx_gen + 1) begin: final_pack_col_loop 
          localparam FINAL_ROW_U = row_idx_gen; 
          localparam FINAL_COL_C = col_idx_gen; 
          localparam LSB_IDX = (FINAL_ROW_U * N_DIM + FINAL_COL_C) * DATA_W;
          localparam MSB_IDX = LSB_IDX + DATA_W - 1;
          assign Z_out_flat[MSB_IDX : LSB_IDX] = Z_out_matrix_reg[FINAL_COL_C][FINAL_ROW_U]; 
        end
      end
    endgenerate

endmodule