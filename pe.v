`timescale 1ns/1ps
//=============================================================
// Module : pe.v
// Project : 4x4 Systolic Array Matrix Multiplier
// Member  : M1 - Hardware Core
// Desc    : Single pipelined MAC (Multiply-Accumulate) unit
//           3 pipeline stages: Latch -> Multiply -> Accumulate
//=============================================================
 
module pe #(
    parameter DATA_W = 8,    // input data width
    parameter ACC_W  = 32    // accumulator width
)(
    input  wire                 clk,
    input  wire                 rst,   // synchronous reset
    input  wire                 clr,   // clear accumulator (start fresh)
    input  wire                 en,    // enable MAC operation
    input  wire [DATA_W-1:0]    a_in,  // data from left
    input  wire [DATA_W-1:0]    b_in,  // data from above
    output reg  [DATA_W-1:0]    a_out, // pass to right neighbour
    output reg  [DATA_W-1:0]    b_out, // pass to bottom neighbour
    output reg  [ACC_W-1:0]     acc    // accumulated dot product result
);
 
    // ── Stage 1 registers: latch inputs ──────────────────────
    reg [DATA_W-1:0]   a_reg;
    reg [DATA_W-1:0]   b_reg;
 
    // ── Stage 2 register: multiplication result ──────────────
    reg [2*DATA_W-1:0] mult_reg;
 
    always @(posedge clk) begin
        if (rst) begin
            a_reg    <= {DATA_W{1'b0}};
            b_reg    <= {DATA_W{1'b0}};
            mult_reg <= {(2*DATA_W){1'b0}};
            acc      <= {ACC_W{1'b0}};
            a_out    <= {DATA_W{1'b0}};
            b_out    <= {DATA_W{1'b0}};
        end
        else begin
            // ── Stage 1: register inputs, propagate sideways ─
            if (en) begin
                a_reg <= a_in;
                b_reg <= b_in;
            end
            a_out <= a_reg;  // always propagate regardless of en
            b_out <= b_reg;
 
            // ── Stage 2: multiply ────────────────────────────
            mult_reg <= a_reg * b_reg;
 
            // ── Stage 3: accumulate ──────────────────────────
            if (clr)
                acc <= {{(ACC_W - 2*DATA_W){1'b0}}, mult_reg};
            else if (en)
                acc <= acc + {{(ACC_W - 2*DATA_W){1'b0}}, mult_reg};
        end
    end
 
endmodule
