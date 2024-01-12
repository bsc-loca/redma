set root_dir .
set prj_dir $root_dir/vivado_prj

create_project -force ompps_manager_tb $prj_dir/redma_tb
set_property simulator_language Verilog [current_project]
set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets sim_1]

add_files $root_dir/src
add_files -norecurse $root_dir/test
set_property top tb [get_filesets sim_1]

launch_simulation -step compile
launch_simulation -step elaborate
launch_simulation -step simulate
run all
