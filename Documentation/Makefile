# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>
# SPDX-License-Identifier: EUPL-1.2

ASCIIDOCTOR = asciidoctor

prefix = /usr/local
datarootdir = $(prefix)/share
docdir = $(datarootdir)/doc/spectrum

SOURCES = \
	binary-cache.adoc \
	creating-vms.adoc \
	development.adoc \
	getting-spectrum.adoc \
	index.adoc \
	running-vms.adoc \
	user-partition.adoc

all: $(SOURCES:adoc=html)
.PHONY: all

.SUFFIXES: .adoc .html

.adoc.html:
	$(ASCIIDOCTOR) $<

install: all
	mkdir -p -- $(docdir)
	cp -- $(SOURCES:adoc=html) $(docdir)
.PHONY: install

clean:
	rm -rf *.html
.PHONY: clean
