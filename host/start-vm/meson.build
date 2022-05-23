# SPDX-License-Identifier: EUPL-1.2+
# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

project('start-vm', 'rust', 'c',
  default_options : ['rust_std=2018', 'warning_level=3'])

add_project_arguments('-D_GNU_SOURCE', language : 'c')
add_project_arguments('-C', 'panic=abort', language : 'rust')

c_lib = static_library('start-vm-c', 'net.c', 'net-util.c')

executable('start-vm', 'start-vm.rs', link_with : c_lib, install : true)

test('Rust unit tests', executable('start-vm-test', 'start-vm.rs',
  rust_args : ['--test', '-C', 'panic=unwind'],
  link_with : c_lib))

subdir('tests')
