// Testbench for the FP_Adder module
module tb_Float8Mac16_3stage();
    parameter N_TEST = 10000;
    // Inputs
    reg clk, rst_n; 
    reg [8*16-1:0]  din_X; // 128-bit input data W (8x16-bit elements)
    reg [8*16-1:0]  din_W; // 128-bit input data W (8x16-bit elements)
    reg             din_valid;
    // Outputs
    wire [15:0]     dout;      // Brain float16 output
    wire            dout_valid;
    reg [7:0]       mem_din_X    [N_TEST*16-1:0];
    reg [7:0]       mem_din_W    [N_TEST*16-1:0];
    reg [15:0]      mem_dout     [N_TEST-1:0];
    reg [15:0]      mem_dout_reg;
    reg             done;
    reg             start;
    reg             match_flag;

    // Read input and reference data from files
    initial begin
        $readmemh("./verification/hex/input/tb_Float8Mac_X.hex", mem_din_X);
        $readmemh("./verification/hex/input/tb_Float8Mac_W.hex", mem_din_W);
        $readmemh("./verification/hex/ref/tb_Float8Mac.hex",     mem_dout);
    end

    // generate fsdb dump file
    initial begin
        $fsdbDumpfile("./verification/fsdb/tb_Float8Mac16_3stage.fsdb");
        $fsdbDumpvars(0,tb_Float8Mac16_3stage,"+all");
    end
    
    Float8Mac16_3stage #(
        .N_WAY(16),
        .PADBIT(7)  // Modify this parameter to change the padding bit  7 -> 8- > 9 -> 10 -> ...
    ) Float8Mac16_3stage_inst(
        .clk(clk),
        .rst_n(rst_n),
        .din_X(din_X),
        .din_W(din_W),
        .din_valid(din_valid),
        .dout(dout),
        .dout_valid(dout_valid)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Initialize Inputs
        clk = 0;
        rst_n = 0;
        din_valid = 0;
        done = 0;
        start = 0;
        match_flag = 0;
        @(posedge clk);
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        start = 1;
        din_valid <= 1;
        wait(done);
        repeat(1) @(posedge clk);
        $finish;
    end

    integer counter = 0;
    integer failed_counter = 0;
    integer matched_counter = 0;

    always @(posedge clk) begin
        if (start) begin
            if (counter < N_TEST+4) begin
                if (counter < N_TEST) begin
                    din_valid <= 1;
                    din_X <= {mem_din_X[counter*16+15], mem_din_X[counter*16+14], mem_din_X[counter*16+13], mem_din_X[counter*16+12], mem_din_X[counter*16+11], mem_din_X[counter*16+10], mem_din_X[counter*16+9], mem_din_X[counter*16+8], mem_din_X[counter*16+7], mem_din_X[counter*16+6], mem_din_X[counter*16+5], mem_din_X[counter*16+4], mem_din_X[counter*16+3], mem_din_X[counter*16+2], mem_din_X[counter*16+1], mem_din_X[counter*16+0]};
                    din_W <= {mem_din_W[counter*16+15], mem_din_W[counter*16+14], mem_din_W[counter*16+13], mem_din_W[counter*16+12], mem_din_W[counter*16+11], mem_din_W[counter*16+10], mem_din_W[counter*16+9], mem_din_W[counter*16+8], mem_din_W[counter*16+7], mem_din_W[counter*16+6], mem_din_W[counter*16+5], mem_din_W[counter*16+4], mem_din_W[counter*16+3], mem_din_W[counter*16+2], mem_din_W[counter*16+1], mem_din_W[counter*16+0]};
                    mem_dout_reg = mem_dout[counter];
                end
                else begin
                    din_valid <= 0;
                end
                #0.1;
                if (dout !== mem_dout[counter-3]) begin
                    if (dout_valid) begin
                        failed_counter = failed_counter + 1;
                        match_flag = 0;
                        $display("#######################################################");
                        $display("Test failed at counter                 = %d", counter-3);
                        $display("dout = %h, ref_dout = %h", dout, mem_dout[counter-3]);
                        $display("#######################################################");
                    end
                end
                else begin
                    match_flag = 1;
                    matched_counter = matched_counter + 1;
                end
                #0.1;
                counter = counter + 1;
            end
            else begin
                done    = 1;
                $display("#######################################################");
                $display("Simulation is done");
                $display("Total number of tests       = %d", N_TEST);
                $display("Number of failed tests      = %d", failed_counter);
                $display("Number of matched tests     = %d", matched_counter);
                $display("#######################################################");
            end
        end
    end

endmodule