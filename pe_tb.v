`timescale 1ns/1ps
//=============================================================
// Module : pe_tb.v
// Project : 4x4 Systolic Array Matrix Multiplier
// Member  : M1 - Hardware Core
// Desc    : Isolation testbench for pe.v
//           Tests MAC operation with known inputs
//           Expected: 2*3 + 4*5 + 6*7 = 6+20+42 = 68
//=============================================================

module pe_tb;

    parameter DATA_W = 8;
    parameter ACC_W  = 32;

    reg                  clk, rst, clr, en;
    reg  [DATA_W-1:0]    a_in, b_in;
    wire [DATA_W-1:0]    a_out, b_out;
    wire [ACC_W-1:0]     acc;

    // Instantiate PE
    pe #(
        .DATA_W(DATA_W),
        .ACC_W (ACC_W)
    ) uut (
        .clk  (clk),
        .rst  (rst),
        .clr  (clr),
        .en   (en),
        .a_in (a_in),
        .b_in (b_in),
        .a_out(a_out),
        .b_out(b_out),
        .acc  (acc)
    );

    // Clock — 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Test sequence
    initial begin
        $dumpfile("pe_tb.vcd");
        $dumpvars(0, pe_tb);

        // ── Reset ──────────────────────────────────────────
        rst=1; clr=0; en=0; a_in=0; b_in=0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst=0;

        // ── Test 1: 2*3 + 4*5 + 6*7 = 68 ─────────────────
        $display("--- Test 1: 2*3 + 4*5 + 6*7 = 68 ---");

        // Cycle 1: feed 2,3 with clr=1 (fresh start)
        en=1; clr=1; a_in=2; b_in=3;
        @(posedge clk); #1;

        // Cycle 2: feed 4,5
        clr=0; a_in=4; b_in=5;
        @(posedge clk); #1;

        // Cycle 3: feed 6,7
        a_in=6; b_in=7;
        @(posedge clk); #1;

        // Cycle 4,5,6: flush pipeline (3 stages need to drain)
        a_in=0; b_in=0; en=0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;

        $display("acc = %0d (expect 68)", acc);
        if (acc == 68)
            $display("Test 1 PASSED ✅");
        else
            $display("Test 1 FAILED ❌ — got %0d", acc);

        // ── Test 2: passthrough check ──────────────────────
        $display("--- Test 2: a_out and b_out passthrough ---");
        rst=1; @(posedge clk); #1; rst=0;

        en=1; clr=1; a_in=8'd55; b_in=8'd77;
        @(posedge clk); #1;
        @(posedge clk); #1;

        $display("a_out = %0d (expect 55)", a_out);
        $display("b_out = %0d (expect 77)", b_out);
        if (a_out == 55 && b_out == 77)
            $display("Test 2 PASSED ✅");
        else
            $display("Test 2 FAILED ❌");

        // ── Test 3: reset clears accumulator ──────────────
        $display("--- Test 3: reset clears acc ---");
        rst=1; @(posedge clk); #1; rst=0; #1;
        $display("acc after reset = %0d (expect 0)", acc);
        if (acc == 0)
            $display("Test 3 PASSED ✅");
        else
            $display("Test 3 FAILED ❌");

        $display("--- All pe.v tests complete ---");
        $finish;
    end

endmodule
