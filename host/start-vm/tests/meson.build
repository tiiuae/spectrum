# SPDX-License-Identifier: EUPL-1.2
# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

test('bridge_add', executable('bridge_add', 'bridge_add.c', '../net-util.c'))
test('bridge_add (%d)', executable('bridge_add-%d',
  'bridge_add-%d.c', '../net-util.c'))
test('bridge_add (name too long)', executable('bridge_add-name-too-long',
  'bridge_add-name-too-long.c', '../net-util.c'))

test('bridge_add_if', executable('bridge_add_if', 'bridge_add_if.c',
  '../net-util.c'))
test('bridge_remove_if', executable('bridge_remove_if', 'bridge_remove_if.c',
  '../net-util.c'))
test('bridge_remove', executable('bridge_remove',
  'bridge_remove.c', '../net-util.c'))

test('tap_open', executable('tap_open', 'tap_open.c', '../net-util.c'))
test('tap_open (name too long)', executable('tap_open-name-too-long',
  'tap_open-name-too-long.c', '../net-util.c'))
