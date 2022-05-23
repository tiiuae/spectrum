// SPDX-License-Identifier: EUPL-1.2+
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

#include <stdint.h>

struct ch_device;

int ch_add_net(const char *vm_name, int tap, const uint8_t mac[6],
               struct ch_device **out);
int ch_remove_device(const char *vm_name, struct ch_device *);

void ch_device_free(struct ch_device *);
