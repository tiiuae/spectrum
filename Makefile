# SPDX-License-Identifier: EUPL-1.2
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

TARFLAGS = -v --show-transformed-names

build/rootfs.ext4: build/rootfs.tar
	tar2sqfs -f $@ < build/rootfs.tar

FILES = etc/group etc/init etc/login etc/passwd etc/service/getty/run
BUILD_FILES = build/etc/s6-rc
MOUNTPOINTS = dev run proc sys

build/rootfs.tar: $(PACKAGES_TAR) $(FILES) $(BUILD_FILES)
	cp --no-preserve=mode -f $(PACKAGES_TAR) $@
	tar $(TARFLAGS) --append -f $@ $(FILES)
	echo $(BUILD_FILES) | cut -d/ -f2 | \
	    tar $(TARFLAGS) --append -f $@ -C build -T -
	for m in $(MOUNTPOINTS); do \
	    tar $(TARFLAGS) --append -hf $@ --xform="s,.*,$$m," /var/empty ; \
	done
	tar $(TARFLAGS) --append -hf $@ --xform='s,.*,etc/service,' /var/empty

S6_RC_FILES = \
	etc/s6-rc/hello/type \
	etc/s6-rc/hello/up \
	etc/s6-rc/ok-all/contents \
	etc/s6-rc/ok-all/type

# s6-rc-compile's input is a directory, but that doesn't play nice
# with Make, because it won't know to update if some file in the
# directory is changed, or a file is created or removed in a
# subdirectory.  Using the whole source directory could also end up
# including files that aren't intended to be part of the input, like
# temporary editor files or .license files.  So for all these reasons,
# only explicitly listed files are made available to s6-rc-compile.
build/etc/s6-rc: $(S6_RC_FILES)
	mkdir -p $$(dirname $@)
	rm -rf $@

	dir=$$(mktemp -d) && \
	    tar -c $(S6_RC_FILES) | tar -C $$dir -x --strip-components 2 && \
	    s6-rc-compile $@ $$dir; \
	    exit=$$?; rm -r $$dir; exit $$exit

clean:
	rm -rf build
.PHONY: clean
