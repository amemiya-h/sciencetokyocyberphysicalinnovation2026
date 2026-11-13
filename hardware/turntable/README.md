# Stepper turntable rig (rev E)

Rev E: everything printable is printed (both GT2 pulleys, shaft collar, platter hub, spindle pin, feet).
To buy: Amazon (controller kit, motor) and MISUMI (2 × 608ZZ, shaft, 2GT belt, screws).

Design & build guide: https://claude.ai/artifact/W3DnE52DKvMBuj6eLcoNxf
Parts list (with listings): https://claude.ai/artifact/2ybU5fh8v67GFHu9vxT2Gt

- docs/      design_build_guide (PDF, DOCX, MD + media/) and parts_list.xlsx: offline copies of the two artifacts above, as of 2026-11-13. The artifacts are the live versions.
- drawings/  CPI-TT-001 sheet 1/3 (section A-A + parts list), sheet 2/3 (plan), CPI-TT-002 sheet 3/3 (electrical); DXF + PDF. make_drawings.py regenerates them.
- cad/       tt_parts.scad (all printed parts, parametric) + stl/ (P1S, PETG; feet TPU; already in print orientation, no supports)
- firmware/  tt_firmware/tt_firmware.ino (Arduino Uno + CNC shield, serial command set)
- matlab/    tt_run_index.m (runs an index scan, logs one CSV row per dwell)
