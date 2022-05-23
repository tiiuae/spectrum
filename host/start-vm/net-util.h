// SPDX-License-Identifier: EUPL-1.2+
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

#include <net/if.h>

int if_up(const char *name);
int if_rename(const char *name, const char *newname);
int if_down(const char *name);

int bridge_add(const char *name);
int bridge_add_if(const char *brname, const char *ifname);
int bridge_remove_if(const char *brname, const char *ifname);
int bridge_delete(const char *name);

int tap_open(char name[static IFNAMSIZ], int flags);
