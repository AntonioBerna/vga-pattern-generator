# VGA Pattern Generator

## :brain: Overview

This project implements a VGA pattern generator in SystemVerilog.

The reference design uses a 100 MHz system clock.

## :building_construction: Architecture

- RTL language: SystemVerilog
- Video output: VGA
- Reference system clock: 100 MHz
- Pixel tick generation:
	- internal fractional rate generator
	- external synchronous pixel tick input
- Configurable timing parameters:
	- horizontal visible area, front porch, sync pulse, and back porch
	- vertical visible area, front porch, sync pulse, and back porch
	- `hsync` and `vsync` polarity
- Example video modes used in simulation:
	- 640x480 @ 60 Hz with a 25.175 MHz pixel clock
	- 800x600 @ 60 Hz with a 40 MHz pixel clock
	- 1024x768 @ 60 Hz with a 65 MHz pixel clock

Block architecture:

```
+--------------+    +------------+    +-----------+    +-------------+    +------------+
| Shared Video | -> | Video Rate | -> | Pattern   | -> | AXI-Stream  | -> | AXI-Stream |
| Config Types | -> | Generator  | -> | Generator | -> | Skid Buffer | -> | to VGA     |
+--------------+    +------------+    +-----------+    +-------------+    +------------+
```

## :rocket: Get Started

### :pushpin: Requirements

This project requires the following dependencies:

- [Vivado 2019.1](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/archive.html)
- [Verilator](https://verilator.org/guide/latest/install.html)
- [SDL2](https://wiki.libsdl.org/SDL2/Installation)

> [!TIP]
> The project can still be used without installing all three dependencies. The minimum requirement is Vivado 2019.1 installed on the host machine.

After installing the required tools, run the following commands:

```bash
# Clone the repository
git clone https://github.com/AntonioBerna/vga-pattern-generator.git
cd vga-pattern-generator/
```

### :zap: Create a new Vivado project

To create a new Vivado project based on the current code organization, use the `scripts/create_vivado_2019_project.tcl` script.

To get started, open the Vivado 2019.1 GUI, go to `Tools > Run Tcl Script...`, and select `create_vivado_2019_project.tcl`.

After a few seconds, the project will be created automatically.

> [!IMPORTANT]
> The Tcl script creates the `vivado/vga_pattern_generator` project directory and the `vga_pattern_generator.xpr` file. To reopen the project, open `vga_pattern_generator.xpr` directly instead of running the Tcl script again.

## :test_tube: Testbench

### :zap: Vivado Standard Simulation

Open the Vivado 2019.1 GUI and click `Run Simulation`.

Wait for the simulation to complete.

### :zap: Verilator Simulation

Run the following command:

```bash
make tb
```

Expected output:

```bash
T=95000 [TB] Applied scenario 0: manual solid/internal tick
T=16683296000 [TB] PASS scenario=0 frame=0 name=manual solid/internal tick
T=33366516000 [TB] PASS scenario=0 frame=1 name=manual solid/internal tick
T=33366565000 [TB] Applied scenario 1: manual vertical/internal tick
T=49945746000 [TB] PASS scenario=1 frame=0 name=manual vertical/internal tick
T=49945795000 [TB] Applied scenario 2: manual gradient/external tick
T=71611046000 [TB] PASS scenario=2 frame=0 name=manual gradient/external tick
T=71611095000 [TB] Applied scenario 3: auto sequence hold-last
T=88294296000 [TB] PASS scenario=3 frame=0 name=auto sequence hold-last
T=104977516000 [TB] PASS scenario=3 frame=1 name=auto sequence hold-last
T=121660736000 [TB] PASS scenario=3 frame=2 name=auto sequence hold-last
T=138343946000 [TB] PASS scenario=3 frame=3 name=auto sequence hold-last
T=155027166000 [TB] PASS scenario=3 frame=4 name=auto sequence hold-last
T=171710386000 [TB] PASS scenario=3 frame=5 name=auto sequence hold-last
T=188393606000 [TB] PASS scenario=3 frame=6 name=auto sequence hold-last
=== VERILATOR TB SUMMARY: PASS=11 FAIL=0 ===
```

### :zap: Verilator + SDL2 Simulation

Run the following command:

```bash
make sim
```

Expected output:

```bash
[monitor] configured for 640x480@60
[sim] step 1/6: solid color @ 640x480
[monitor] configured for 640x480@60
[sim] step 2/6: vertical bars @ 640x480
[monitor] configured for 800x600@60
[sim] step 3/6: horizontal bars @ 800x600
[monitor] configured for 800x600@60
[sim] step 4/6: gradient RGB @ 800x600
[monitor] configured for 1024x768@60
[sim] step 5/6: checkerboard @ 1024x768
[monitor] configured for 1024x768@60
[sim] step 6/6: grid @ 1024x768
[sim] frames presented: 90
[sim] timing errors: 0
```

> [!TIP]
> A demo video of the SDL2 simulation is not included yet.

## :bulb: Laboratory of FPGA Design Flow

> [!WARNING]
> Work in progress: waiting for Digilent Basys 3 FPGA board.
