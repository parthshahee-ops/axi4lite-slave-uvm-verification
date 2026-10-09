# Build / Run Notes (from supplied logs)

- Tool: AMD/Xilinx Vivado 2026.1
- Simulator: XSim behavioral simulation
- UVM: 1.2
- Simulation top: `tb_top`
- Log command: Vivado `launch_simulation -mode behavioral`; simulator transcript includes `xvlog --incr --relax -L uvm -prj tb_top_vlog.prj` and `xelab` elaboration.

The actual `.xpr`, `.prj`, `.tcl`, compile-order metadata and source files were not included in the supplied material. Therefore no standalone build script is provided in this overlay. Use the original Vivado project and run behavioral simulation with `tb_top` as the simulation top. Once the source/project files are added, document the exact project setup and any include paths.
