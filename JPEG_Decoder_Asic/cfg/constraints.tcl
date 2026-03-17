# constraints.tcl
# FIXME: Update the constraint clocks
#
# This file is where design timing constraints are defined for Genus and Innovus.
# Many constraints can be written directly into the Hammer config files. However, 
# you may manually define constraints here as well.
#

create_clock -period 10 -name clk [get_ports clk_i]
# Mark reset as false path (async reset input)
#set_false_path -from [get_ports rst_i]
set_input_delay 0 -clock clk [all_inputs]
set_output_delay 0 -clock clk [all_outputs]