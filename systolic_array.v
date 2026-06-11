`timescale 1ns/1ps
//=============================================================
// Module : systolic_array.v
// Project : 4x4 Systolic Array Matrix Multiplier
// Member  : M1 - Hardware Core
// Desc    : 4x4 grid of PE instances with a_wire and b_wire
//           interconnects. Handles cycle counter, running
//           signal, clr logic, and done output.
//=============================================================

module systolic_array #(
    parameter DATA_W = 8,
    parameter ACC_W  = 32,
    parameter N      = 4
)(
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         start,       // begin computation

    // Skewed inputs from input_buffer
    input  wire [DATA_W-1:0]            a_feed_0,    // row 0
    input  wire [DATA_W-1:0]            a_feed_1,    // row 1
    input  wire [DATA_W-1:0]            a_feed_2,    // row 2
    input  wire [DATA_W-1:0]            a_feed_3,    // row 3

    input  wire [DATA_W-1:0]            b_feed_0,    // col 0
    input  wire [DATA_W-1:0]            b_feed_1,    // col 1
    input  wire [DATA_W-1:0]            b_feed_2,    // col 2
    input  wire [DATA_W-1:0]            b_feed_3,    // col 3

    // Accumulator outputs — all 16 PEs
    output wire [ACC_W-1:0]             acc_00, acc_01, acc_02, acc_03,
    output wire [ACC_W-1:0]             acc_10, acc_11, acc_12, acc_13,
    output wire [ACC_W-1:0]             acc_20, acc_21, acc_22, acc_23,
    output wire [ACC_W-1:0]             acc_30, acc_31, acc_32, acc_33,

    output reg                          done         // computation complete
);

    // ── Interconnect wires ────────────────────────────────────
    // a_wire[row][col] — horizontal data flow left to right
    // col 0 = input, col N = unused (drain)
    wire [DATA_W-1:0] a_wire [0:N-1][0:N];
    wire [DATA_W-1:0] b_wire [0:N][0:N-1];

    // ── Cycle counter and control signals ────────────────────
    // Total cycles needed = 3*N - 2 = 10 for N=4
    localparam TOTAL_CYCLES = 3*N - 2;

    reg [4:0]  cycle_count;
    reg        running;
    reg        en_global;
    reg        clr_global;

    // ── Feed left edge and top edge from input_buffer ────────
    assign a_wire[0][0] = a_feed_0;
    assign a_wire[1][0] = a_feed_1;
    assign a_wire[2][0] = a_feed_2;
    assign a_wire[3][0] = a_feed_3;

    assign b_wire[0][0] = b_feed_0;
    assign b_wire[0][1] = b_feed_1;
    assign b_wire[0][2] = b_feed_2;
    assign b_wire[0][3] = b_feed_3;

    // ── Instantiate 4x4 = 16 PEs ─────────────────────────────
    genvar gi, gj;
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : row_gen
            for (gj = 0; gj < N; gj = gj + 1) begin : col_gen
                pe #(
                    .DATA_W(DATA_W),
                    .ACC_W (ACC_W)
                ) pe_inst (
                    .clk   (clk),
                    .rst   (rst),
                    .clr   (clr_global),
                    .en    (en_global),
                    .a_in  (a_wire[gi][gj]),
                    .b_in  (b_wire[gi][gj]),
                    .a_out (a_wire[gi][gj+1]),
                    .b_out (b_wire[gi+1][gj])
                );
            end
        end
    endgenerate

    // ── Connect PE accumulator outputs ───────────────────────
    assign acc_00 = row_gen[0].col_gen[0].pe_inst.acc;
    assign acc_01 = row_gen[0].col_gen[1].pe_inst.acc;
    assign acc_02 = row_gen[0].col_gen[2].pe_inst.acc;
    assign acc_03 = row_gen[0].col_gen[3].pe_inst.acc;

    assign acc_10 = row_gen[1].col_gen[0].pe_inst.acc;
    assign acc_11 = row_gen[1].col_gen[1].pe_inst.acc;
    assign acc_12 = row_gen[1].col_gen[2].pe_inst.acc;
    assign acc_13 = row_gen[1].col_gen[3].pe_inst.acc;

    assign acc_20 = row_gen[2].col_gen[0].pe_inst.acc;
    assign acc_21 = row_gen[2].col_gen[1].pe_inst.acc;
    assign acc_22 = row_gen[2].col_gen[2].pe_inst.acc;
    assign acc_23 = row_gen[2].col_gen[3].pe_inst.acc;

    assign acc_30 = row_gen[3].col_gen[0].pe_inst.acc;
    assign acc_31 = row_gen[3].col_gen[1].pe_inst.acc;
    assign acc_32 = row_gen[3].col_gen[2].pe_inst.acc;
    assign acc_33 = row_gen[3].col_gen[3].pe_inst.acc;

    // ── FSM: control cycle counter and done signal ────────────
    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 0;
            running     <= 0;
            en_global   <= 0;
            clr_global  <= 0;
            done        <= 0;
        end
        else begin
            clr_global <= 0;  // default
            done       <= 0;  // default

            if (start && !running) begin
                running     <= 1;
                cycle_count <= 0;
                en_global   <= 1;
                clr_global  <= 1;  // clear accumulators on first cycle
            end
            else if (running) begin
                cycle_count <= cycle_count + 1;

                if (cycle_count == TOTAL_CYCLES - 1) begin
                    running   <= 0;
                    en_global <= 0;
                    done      <= 1;  // fire done for one cycle
                end
            end
        end
    end

endmodule
