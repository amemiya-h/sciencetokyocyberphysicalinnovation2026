# Stepper turntable rig

Everything printable is printed (both GT2 pulleys, shaft collar, platter hub, spindle pin, feet).
To buy: Amazon (controller kit, motor) and MISUMI (2 × 608ZZ, shaft, 2GT belt, screws).

- docs/      design_build_guide and parts_list
- drawings/  CPI-TT-001 sheet 1/3 (section A-A + parts list), sheet 2/3 (plan), CPI-TT-002 sheet 3/3 (electrical); DXF + PDF. make_drawings.py regenerates them.
- cad/       tt_parts.scad (all printed parts, parametric) + stl/ (P1S, PETG; feet TPU; already in print orientation, no supports)
- firmware/  tt_firmware/tt_firmware.ino (Arduino Uno + CNC shield, serial command set)
- matlab/    tt_run_index.m (runs an index scan, logs one CSV row per dwell)

The firmware also drives an optional radial axis on the shield's Y slot (commands Y, W, K, Q; set RAD_STEPS_PER_MM in the sketch).
The MATLAB driver for scans is code/+rig, used by code/examples/scan_ring_motorized.m and scan_side_motorized.m.
