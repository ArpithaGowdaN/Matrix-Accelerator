# Hardware Accelerator for Matrix Multiplication
### DLC Project — Track 4: VLSI | 4×4 Systolic Array | Pipelining + Parallel Processing

> A VLSI-based hardware accelerator that performs 4×4 matrix multiplication using a pipelined systolic array implemented in Verilog, targeting Xilinx Artix-7 FPGA via Vivado synthesis.

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [The Problem We Solve](#the-problem-we-solve)
3. [Architecture](#architecture)
4. [Pipeline Stages](#pipeline-stages)
5. [Verilog Modules](#verilog-modules)
6. [Team Structure](#team-structure)
7. [Project Timeline](#project-timeline)
8. [Tools Required](#tools-required)
9. [Repository Structure](#repository-structure)
10. [How to Simulate](#how-to-simulate)
11. [DLC Syllabus Mapping](#dlc-syllabus-mapping)
12. [Final Deliverables](#final-deliverables)

---

## Project Overview

This project builds a **hardware accelerator** that computes 4×4 matrix multiplication using a **systolic array architecture** — the same concept used in Google's Tensor Processing Unit (TPU).

Instead of a CPU computing one multiplication at a time (64 multiplications done sequentially), our design uses **16 Processing Elements (PEs) working in parallel**, each handling one portion of the matrix simultaneously — combined with **3-stage pipelining** inside each PE for maximum throughput.

| Metric | Value |
|---|---|
| Matrix Size | 4×4 |
| Parallel Processing Elements | 16 |
| Pipeline Stages | 3 |
| Total Cycle Latency | 10 cycles |
| Target Platform | Xilinx Artix-7 FPGA |
| HDL Language | Verilog |

---

## The Problem We Solve

**Software (CPU) approach:**
- Multiplies one element at a time — sequential
- For a 4×4 matrix: 64 multiplications + 48 additions done one by one
- High latency, low throughput
- Completely unsuitable for real-time AI or DSP applications

**Our hardware approach:**
- 16 PEs compute in parallel every clock cycle
- Pipelining overlaps multiply and accumulate operations — no idle time
- Result in 10 clock cycles regardless of data complexity
- Scales to 8×8 or larger by changing a single parameter `N`

> **Factory Analogy:** Without pipeline — build one car fully, then start the next (slow). With pipeline — while car A gets painted, car B gets wheels, car C gets the engine, all at once (fast). With 16 parallel assembly lines — 16 cars being built simultaneously (fastest). That is exactly what this project builds, but for matrix multiplication in hardware.

---

## Architecture

### Systolic Array (Core)
A 4×4 grid of PE units where:
- **Matrix A rows** feed left-to-right across the array
- **Matrix B columns** feed top-to-bottom through the array
- Each PE computes one **Multiply-Accumulate (MAC)** operation per clock
- Data pulses through the grid like a heartbeat — hence "systolic"

### Data Flow
```
Input A & B matrices
        ↓
Input Buffer (skewed/staggered feed)
        ↓
4×4 Systolic Array (16 PEs in parallel)
        ↓
Output Buffer (captures results when done fires)
        ↓
Result Matrix C
```

### FSM Controller
A 5-state Finite State Machine manages the entire datapath:

```
IDLE → LOAD → MULTIPLY → ADD → OUTPUT_ST → (back to LOAD)
```

- Controls when data is fed into PEs
- Controls when PEs are enabled
- Generates the `done` signal when computation is complete
- Maps directly to Module 4 and Module 5 syllabus content

### Pipelining Inside Each PE
Each PE has 3 internal pipeline stages:
- **Stage 1:** Latch inputs (a_in, b_in) into registers on rising clock edge
- **Stage 2:** Multiply a_in × b_in combinationally
- **Stage 3:** Accumulate product into running sum register (`acc`)

While Stage 3 is accumulating, Stage 2 is already computing the next product — no idle time.

---

## Pipeline Stages

| Stage | Name | Description |
|---|---|---|
| Stage 1 | LOAD | A and B values registered on posedge clk. Input skewing staggers data so PE[i][j] gets A[i][k] and B[k][j] at the correct cycle |
| Stage 2 | MULTIPLY | All 16 PEs multiply a_in × b_in simultaneously in the same clock cycle — this is the parallel processing |
| Stage 3 | ACCUMULATE | Each PE adds current product to its `acc` register. Repeats N=4 times. After N cycles, acc holds the complete dot product C[i][j] |
| Stage 4 | OUTPUT | After (3N−2) = 10 total cycles, all 16 accumulators hold valid results. `done` fires high. Output buffer latches C_flat |

---

## Verilog Modules

| File | Owner | Description |
|---|---|---|
| `pe.v` | Member 1 | Single pipelined MAC unit. Ports: `clk, rst, clr, en, a_in[7:0], b_in[7:0], a_out[7:0], b_out[7:0], acc[31:0]`. Atomic building block of the entire design |
| `systolic_array.v` | Member 1 | 4×4 grid of pe.v instances wired via `a_wire[N][N+1]` and `b_wire[N+1][N]` interconnects. Handles cycle counter, running/done logic |
| `input_buffer.v` | Member 2 | Staggered input feeding. Staggers A rows and B columns so PE[i][j] receives data at cycle (i+j). Trickiest module — requires careful timing analysis |
| `output_buffer.v` | Member 2 | Captures all 16 PE accumulator values into `C_flat[N×N×32-1:0]` when `done` fires. Register bank |
| `top.v` | Member 2 | Top-level integration. Instantiates all submodules. Exposes: `clk, rst, sys_start, A_flat[N×N×8-1:0], B_flat[N×N×8-1:0], C_flat[N×N×32-1:0], done` |
| `tb_top.v` | Member 3 | Self-checking testbench. Applies identity/all-ones/random inputs, computes golden reference, compares DUT outputs, prints PASS/FAIL, dumps .vcd for GTKWave |

### Global Parameters (agreed by all members in Week 1)
```verilog
parameter DATA_W = 8;   // Input data width (8-bit)
parameter ACC_W  = 32;  // Accumulator width (32-bit)
parameter N      = 4;   // Matrix dimension (4×4)
```

---

## Team Structure

| Member | Role | Files Owned | Dependency |
|---|---|---|---|
| **M1** | Hardware Core — strongest Verilog person | `pe.v`, `systolic_array.v`, `pe_tb.v` | None — starts Week 1 |
| **M2** | Buffers + Integration | `input_buffer.v`, `output_buffer.v`, `top.v` | Needs M1's verified pe.v before top.v |
| **M3** | Testbench + Verification + Performance | `tb_top.v`, Vivado sim, Reports | Needs M2's top.v |
| **M4** | Documentation + Architecture + Report | Architecture diagram, FSM diagram, Final report, Slides | Uses M3's synthesis numbers |

### Branch Rules
- `main` — only verified, working code. **Never push directly.**
- `m1-hardware` — M1's workspace
- `m2-buffers` — M2's workspace
- `m3-testbench` — M3's workspace
- `m4-docs` — M4's workspace

> ⚠️ **Most important team rule:** All members must agree on signal names and port widths in **Week 1** before writing any code. Create a shared `interface_spec.md` on GitHub in the first team meeting.

---

## Project Timeline

| Week | Goals |
|---|---|
| **Week 1** | M1 writes and verifies pe.v in isolation · M2 studies systolic array timing theory · Team agrees on DATA_W=8, ACC_W=32, N=4 · GitHub repo set up with all branches · Interface spec document created |
| **Week 2** | M1 completes systolic_array.v · M2 completes input_buffer.v and output_buffer.v · M2 starts top.v integration · M3 writes testbench skeleton with identity matrix test |
| **Week 3** | M2 completes top.v · Full system simulation in Vivado · M3 runs all test cases and captures GTKWave waveform screenshots · M3 runs synthesis → extracts timing, LUT, power reports · Team debugs failures |
| **Week 4** | M4 compiles final report with all diagrams and synthesis numbers · Presentation slides prepared · All members review report · Final submission |

---

## Tools Required

| Tool | Purpose | Download |
|---|---|---|
| **Vivado ML Edition (WebPACK)** | HDL simulation, synthesis, FPGA implementation, timing/LUT/power reports | xilinx.com (~50 GB) |
| **VS Code + Verilog-HDL Extension** | Write and edit .v files with syntax highlighting | code.visualstudio.com |
| **GTKWave** | View .vcd waveform dumps from simulation | gtkwave.sourceforge.net |
| **Git + GitHub** | Branch-based collaboration across all 5 members | git-scm.com |
| **Python + NumPy** | Compute golden reference matrices for verification | python.org |

> **No Vivado yet?** Use [EDA Playground](https://www.edaplayground.com) (free, browser-based) with Icarus Verilog to test functional correctness of your modules while Vivado downloads.

---

## Repository Structure

```
DLC-Matrix-Accelerator/
├── README.md
├── interface_spec.md          ← Port names and widths agreed by all members
├── src/
│   ├── pe.v                   ← M1: Processing Element
│   ├── systolic_array.v       ← M1: 4×4 PE grid
│   ├── input_buffer.v         ← M2: Skewed input feeding
│   ├── output_buffer.v        ← M2: Result capture
│   └── top.v                  ← M2: Top-level integration
├── sim/
│   └── tb_top.v               ← M3: Self-checking testbench
├── reports/
│   ├── timing_report.txt      ← M3: Vivado timing (max MHz)
│   ├── utilization_report.txt ← M3: LUT/DSP/FF count
│   └── power_report.txt       ← M3: Power in mW
└── docs/
    ├── architecture_diagram.png
    ├── fsm_diagram.png
    └── final_report.pdf
```

---

## How to Simulate

### Option 1 — Vivado (Full)
```tcl
# In Vivado Tcl console
create_project dlc_project ./dlc_project -part xc7a35tcpg236-1
add_files [glob src/*.v]
add_files -fileset sim_1 sim/tb_top.v
launch_simulation
```

### Option 2 — EDA Playground (Browser, No Install)
1. Go to [edaplayground.com](https://www.edaplayground.com)
2. Select **Icarus Verilog** as simulator
3. Paste your module + testbench code
4. Click **Run** — view output in console

### Option 3 — Icarus Verilog (Local, Lightweight)
```bash
# Compile
iverilog -o sim_out src/pe.v src/systolic_array.v src/input_buffer.v \
         src/output_buffer.v src/top.v sim/tb_top.v

# Run simulation
vvp sim_out

# View waveforms
gtkwave dump.vcd
```

---

## DLC Syllabus Mapping

This project directly applies concepts from Modules 2, 3, 4, and 5 of Digital Logic Circuits:

| Module | Topics | How Used in This Project |
|---|---|---|
| **Module 2** | MUX, Decoders, Adders, FPGA | Carry lookahead adder in PE accumulation · MUX for data routing · FPGA is the direct synthesis target |
| **Module 3** | D Flip-Flops, Registers, Shift Registers, Timing | Every pipeline register is a D flip-flop · Input skewing uses shift register logic · Output buffer is a register bank |
| **Module 4** | Synchronous Counters, Sequential Circuits, Memories | Cycle counter is a synchronous mod-N counter · FSM implemented as synchronous sequential circuit |
| **Module 5** | FSM State Graphs, Sequence Detectors | FSM (IDLE→LOAD→MULTIPLY→ADD→OUTPUT_ST) is directly Module 5 state machine design · Done signal is analogous to a sequence detector output |

---

## Final Deliverables

| # | Deliverable | Owner |
|---|---|---|
| 1 | HDL source code — all .v files, clean, commented, parameterized | All members |
| 2 | Hardware architecture diagram (top-level block + PE grid dataflow) | M4 |
| 3 | FSM state diagram (all 5 states, transitions, done signal) | M4 |
| 4 | Simulation waveforms — GTKWave screenshots for 3+ test cases | M3 |
| 5 | Performance report — LUT count, DSP blocks, max MHz, power mW | M3 + M4 |
| 6 | Final design report — problem, solution, architecture, syllabus mapping, results | M4 |

---

## What Makes This Project Stand Out

| Other Teams | Our Team |
|---|---|
| Simulation only, no synthesis | Vivado synthesis with real FPGA data |
| No real performance numbers | MHz, LUT count, power in report |
| Fixed size only | Parameterized N — scales 2×2 to 8×8 |
| Manual or weak testbench | Self-checking testbench — ALL TESTS PASSED output |
| No comparison vs software | Speedup ratio vs CPU software baseline |

---

*DLC Project · Track 4: VLSI · Team of 4 · Verilog + Vivado · 4×4 Systolic Array*
