// 16-WAY FP8 MAC at Dense Core
// Support fp8 e4m3fn
// 3-stage pipeline
// Input : FP8(1-4-3), Weight : FP8(1-4-3), Output: BF16(1-8-7)
// Output: 16-bit Brain Float16(1-8-7)
// Author : JongYeop KIM
module Float8Mac16_3stage #(
    parameter int unsigned N_WAY  = 16,
    parameter int unsigned PADBIT = 10
)(
    input  logic               clk,
    input  logic               rst_n,
    input  logic [8*N_WAY-1:0] din_X,
    input  logic [8*N_WAY-1:0] din_W,
    input  logic               din_valid,
    output logic [15:0]        dout,
    output logic               dout_valid
);
    //-------------------------------------------------------------------------
    // Parameters
    //-------------------------------------------------------------------------
    localparam int unsigned S_BIT       = PADBIT + 9;
    localparam int unsigned F_BIT       = S_BIT + $clog2(N_WAY);
    localparam int unsigned FIRST_BIT   = $clog2(F_BIT);
    localparam int unsigned ROUND_BIT   = (F_BIT-1)-8;
    //-------------------------------------------------------------------------
    // Internal Signals
    //-------------------------------------------------------------------------
    logic        i_sign[N_WAY-1:0];
    logic [7:0]  i_exp [N_WAY-1:0];
    logic [7:0]  i_man [N_WAY-1:0];
    logic        zero_x[N_WAY-1:0];
    logic        zero_w[N_WAY-1:0];
    logic        sub_normal_flag_X[N_WAY-1:0];
    logic        sub_normal_flag_W[N_WAY-1:0];
    logic [3:0]  first[N_WAY-1:0];
    logic [7:0]  m_exp[N_WAY-1:0];
    logic [7:0]  m_man[N_WAY-1:0];
    logic [7:0]  max;
    logic        f_sign;
    logic [7:0]  f_exp;
    logic [FIRST_BIT-1:0]   f_first;
    logic signed [S_BIT-1:0] s_man [N_WAY-1:0];
    logic signed [F_BIT-1:0] f_man;
    //-------------------------------------------------------------------------
    // Pipeline registers
    //-------------------------------------------------------------------------
    // For Stage 1
    //-------------------------------------------------------------------------
    logic         dout_valid_buf;
    logic         i_sign_buf[N_WAY-1:0];
    logic [7:0]  i_exp_buf [N_WAY-1:0];
    logic [7:0]  i_man_buf [N_WAY-1:0];
    logic         zero_x_buf[N_WAY-1:0];
    logic         zero_w_buf[N_WAY-1:0];
    //-------------------------------------------------------------------------
    // For Stage 2
    //-------------------------------------------------------------------------
    logic signed [S_BIT-1:0] s_man_buf [N_WAY-1:0];
    logic         dout_valid_buf_1;
    logic [7:0]  max_buf;
    //-------------------------------------------------------------------------
    // For Stage 3
    //-------------------------------------------------------------------------
    logic [15:0] dout_buf;
    //-------------------------------------------------------------------------
    genvar K;
    generate 
        for (K = 0; K < N_WAY; K = K + 1) begin : gen_mul
            assign sub_normal_flag_X[K] = (din_X[8*K+6:8*K+3] == 4'd0 & din_X[8*K+2:8*K] != 3'd0) ? 1'b1 : 1'b0; // Subnormal flag for X
            assign sub_normal_flag_W[K] = (din_W[8*K+6:8*K+3] == 4'd0 & din_W[8*K+2:8*K] != 3'd0) ? 1'b1 : 1'b0; // Subnormal flag for W
            assign zero_x[K] = (din_X[8*K+6:8*K] == 7'd0 | din_valid == 1'b0) ? 1'b1 : 1'b0;  // Zero : S.0000.000
            assign zero_w[K] = (din_W[8*K+6:8*K] == 7'd0 | din_valid == 1'b0) ? 1'b1 : 1'b0;  // Zero : S.0000.000
            assign i_sign[K] = (din_X[8*K+7] ^ din_W[8*K+7]);
            assign i_exp[K]  = (sub_normal_flag_X[K] | sub_normal_flag_W[K]) ? (sub_normal_flag_X[K] & sub_normal_flag_W[K]) ?
            (din_X[8*K+6:8*K+3] + din_W[8*K+6:8*K+3] - 'd7 + 'd2 + 'd120) : // When both X and W are subnormal
            (din_X[8*K+6:8*K+3] + din_W[8*K+6:8*K+3] - 'd7 + 'd1 + 'd120) : // When only one of X and W is subnormal
            (din_X[8*K+6:8*K+3] + din_W[8*K+6:8*K+3] - 'd7 + 'd120);        // When both X and W are normal
            assign i_man[K]  = {|{din_X[8*K+6:8*K+3]},din_X[8*K+2:8*K]} * {|{din_W[8*K+6:8*K+3]},din_W[8*K+2:8*K]};
        end
    endgenerate

    generate
        for (K = 0; K < N_WAY; K = K + 1) begin : gen_first
            always_comb begin
                first[K] = 'd0;
                for (int unsigned i = 0; i < 8; i = i + 1) begin
                    if (i_man_buf[K][i]) begin
                        first[K] = i;
                    end
                end
                if (zero_x_buf[K] | zero_w_buf[K]) begin
                    m_exp[K] = 'd0;
                    m_man[K] = 'd0;
                end
                else begin
                    //------------------------------------------
                    // Normalization
                    //------------------------------------------
                    m_exp[K] = i_exp_buf[K] + first[K] - 'd6;
                    m_man[K] = i_man_buf[K] << ('d7 - first[K]);
                    //------------------------------------------
                end
            end
        end
    endgenerate


    always_comb begin  // Find the maximum exponent
        max = 'd0;
        for (int unsigned i = 0; i < N_WAY; i = i + 1) begin
            if (m_exp[i] > max) begin
                max = m_exp[i];
            end
        end
    end

    generate 
        for (K = 0; K < N_WAY; K = K + 1) begin : gen_s_man
            always_comb begin
                // Padding the mantissa with PADBIT number of 0s
                // and shift the mantissa to the right by (max - m_exp[K])
                s_man[K] = ({|{m_exp[K]},m_man[K][6:0],{PADBIT{1'b0}}} >> (max - m_exp[K]));
                if (i_sign_buf[K]) begin
                    s_man[K] = -s_man[K];
                end
            end
        end
    endgenerate

    always_comb begin
        f_man   = 'd0;
        f_first = 'd0;
        for (int unsigned i = 0; i < N_WAY; i = i + 1) begin
            f_man = f_man + s_man_buf[i];
        end
        if (f_man < 0) begin
            f_sign = 1'b1;
            f_man  = -f_man;
        end
        else begin
            f_sign = 1'b0;
        end
        for (int unsigned i = 0; i < F_BIT; i = i + 1) begin
            if (f_man[i]) begin
                f_first = i;
            end
        end
        f_man = f_man << ((F_BIT-1) - f_first);
        // Need to consider f_man = 0 case
        if (f_man == {F_BIT{1'b0}}) begin
            // When f_man is zero, set f_exp to 0
            f_exp = 8'd0;
        end else begin
            // When f_man is not zero, calculate f_exp based on max_buf and f_first
            f_exp = max_buf + f_first - ((F_BIT-1)-($clog2(N_WAY)+1));
        end
        //------------------------------------------
        // Rounding Logic
        //------------------------------------------
        if (f_man[ROUND_BIT]) begin
            // If the next bit is 1, we need to consider rounding
            if (|f_man[ROUND_BIT-1:0]) begin
                // If any of the remaining bits are non-zero
                if (&f_man[ROUND_BIT+7:ROUND_BIT+1]) begin
                    // If the current 7-bit mantissa is all ones (111_1111), it will overflow
                    f_man[ROUND_BIT+8:ROUND_BIT+1] = 8'b10000000; // Set mantissa to 1000_0000 and increment exponent
                    f_exp = f_exp + 1; 
                end
                else begin
                    // Otherwise, simply increment the mantissa
                    f_man[ROUND_BIT+8:ROUND_BIT+1] = f_man[ROUND_BIT+8:ROUND_BIT+1] + 1'b1;
                end
            end
            else begin
                // If we are exactly halfway and need to round to even
                if (f_man[ROUND_BIT+1]) begin
                    // If the current LSB of the mantissa is 1
                    if (&f_man[ROUND_BIT+7:ROUND_BIT+1]) begin
                        // Handle overflow case
                        f_man[ROUND_BIT+8:ROUND_BIT+1] = 8'b10000000;
                        f_exp = f_exp + 1;
                    end
                    else begin
                        // Round up by incrementing the mantissa
                        f_man[ROUND_BIT+8:ROUND_BIT+1] = f_man[ROUND_BIT+8:ROUND_BIT+1] + 1'b1;
                    end
                end
            end
        end
    end
    //------------------------------------------
    // Final Output Assignment
    //------------------------------------------
    assign dout_buf = {f_sign, f_exp, f_man[ROUND_BIT+7:ROUND_BIT+1]};
    //------------------------------------------
    // 3-stage pipeline
    //------------------------------------------
    // Stage 1
    //------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin 
        if (rst_n == 1'b0) begin
            dout_valid_buf    <= 1'b0;
            for (int unsigned i = 0; i < N_WAY; i = i + 1) begin
                i_sign_buf[i] <= 1'b0;
                i_exp_buf[i]  <= 'd0;
                i_man_buf[i]  <= 'd0;
                zero_x_buf[i] <= 1'b0;
                zero_w_buf[i] <= 1'b0;
            end
        end
        else begin
            dout_valid_buf    <= din_valid;
            for (int unsigned i = 0; i < N_WAY; i = i + 1) begin
                i_sign_buf[i] <= i_sign[i];
                i_exp_buf[i]  <= i_exp[i];
                i_man_buf[i]  <= i_man[i];
                zero_x_buf[i] <= zero_x[i];
                zero_w_buf[i] <= zero_w[i];
            end
        end
    end
    //------------------------------------------
    // Stage 2
    //------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin 
        if (rst_n == 1'b0) begin
            dout_valid_buf_1  <= 1'b0;
            max_buf           <= 'd0;
            for (int unsigned i = 0; i < N_WAY; i = i + 1) begin
                s_man_buf[i]  <= 'd0;
            end
        end
        else begin
            dout_valid_buf_1  <= dout_valid_buf;
            max_buf           <= max;
            for (int unsigned i = 0; i < N_WAY; i = i + 1) begin
                s_man_buf[i]  <= s_man[i];
            end
        end 
    end
    //-----------------------------------------
    // Stage 3
    //-----------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin 
        if (rst_n == 1'b0) begin
            dout_valid <= 1'b0;
            dout       <= 16'd0;
        end
        else begin
            dout_valid <= dout_valid_buf_1;
            dout       <= dout_buf;
        end
    end
    //-----------------------------------------

endmodule