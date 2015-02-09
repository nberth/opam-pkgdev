# -*- makefile-gmake -*-
# ----------------------------------------------------------------------
#
# Generic makefile for OPAM package contruction.
# 
# Copyright (C) 2015 Nicolas Berthier
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# ----------------------------------------------------------------------

# Check at least the eval construct to reject old implementations of
# make.
eval_available :=
$(eval eval_available := yes)
ifneq ($(eval_available),yes)
 $(error This Makefile only works with a Make program that supports	\
	 $$(eval))
endif

# ---

ifeq ($(ENABLE_BYTE),yes)
  LIBSUFF += cma
endif
ifeq ($(ENABLE_NATIVE),yes)
  LIBSUFF += cmxa a
endif
TARGETS = $(foreach p,$(AVAILABLE_LIBs),$(addprefix $(p).,$(LIBSUFF)))
TARGETS += $(foreach p,$(AVAILABLE_LIB_ITFs),$(p).cmi)

ifeq ($(ENABLE_BYTE),yes)
  TARGETS += $(addprefix src/main/,$(addsuffix .byte,$(EXECS)))
endif
ifeq ($(ENABLE_NATIVE),yes)
  TARGETS += $(addprefix src/main/,$(addsuffix .native,$(EXECS)))
endif

# ---

NATIVE_EXT = .opt
BYTE_EXT = 
ifeq ($(ENABLE_NATIVE),yes)
  ifneq ($(ENABLE_BYTE),yes)
    NATIVE_EXT = 
  endif
endif

# ---

.PHONY: all
all: force version.ml.in
	$(QUIET)$(OCAMLBUILD) $(TARGETS)

.PHONY: clean
clean: force
	$(QUIET)rm -f META
	$(QUIET)$(OCAMLBUILD) -clean

.PHONY: distclean
distclean: force clean clean-version
	$(QUIET)rm -f config.mk

# ---

.PHONY: doc
doc: force
	$(QUIET)$(OCAMLBUILD) -I .					\
	  -ocamldoc "ocamldoc -charset iso-10646-1"			\
	  -no-sanitize -no-hygiene					\
	  $(foreach p,$(AVAILABLE_LIBs),src/$(p).docdir/index.html)

.PHONY: cleandoc
cleandoc:
	$(QUIET)rm doc -Rf

.PHONY: force
force:

# ---

.PHONY: install-findlib uninstall-findlib
ifeq ($(INSTALL_LIBS),yes)
  install-findlib: META all
	-ocamlfind remove $(PKGNAME) 2> /dev/null;
	ocamlfind install $(PKGNAME) META				\
	  $(foreach p,$(AVAILABLE_LIBs),                 		\
	    $(addprefix _build/src/$(p).,$(LIBSUFF)))			\
	  $(foreach p,$(AVAILABLE_LIB_ITFs),_build/src/$(p).cmi)

  uninstall-findlib: force
	ocamlfind remove $(PKGNAME)
else
  install-findlib:
  uninstall-findlib:
endif

# ---

.PHONY: install-doc uninstall-doc
ifeq ($(INSTALL_DOCS),yes)
  install-doc: doc
	rm -rf "$(DOCDIR)/$(PKGNAME)";
	mkdir -p "$(DOCDIR)/$(PKGNAME)";
	$(foreach p,$(AVAILABLE_LIBs),cp -r "_build/src/$(p).docdir"	\
	  "$(DOCDIR)/$(PKGNAME)/$(p)";)

  uninstall-doc: force
	rm -rf "$(DOCDIR)/$(PKGNAME)";
else
  install-doc:
  uninstall-doc:
endif

# ---

checkvar = $(or $(value $(1)),$(eval $$(error $(2))))

NO_PREFIX_ERROR_MSG ?= Missing prefix: use "make PREFIX=..."

.PHONY: chk-prefix
chk-prefix: force
	$(eval $@_P := $(call checkvar,PREFIX,$(NO_PREFIX_ERROR_MSG)))

.PHONY: install
install: chk-prefix all install-findlib install-doc
	$(foreach e,$(EXECS), [ -x "_build/src/main/$(e).byte" ] &&	\
	  install "_build/src/main/$(e).byte"				\
	    "$(PREFIX)/bin/$(e)$(BYTE_EXT)" || exit 0;)
	$(foreach e,$(EXECS), [ -x "_build/src/main/$(e).native" ] &&	\
	  install "_build/src/main/$(e).native"				\
	    "$(PREFIX)/bin/$(e)$(NATIVE_EXT)" || exit 0;)

.PHONY: uninstall
uninstall: chk-prefix uninstall-findlib uninstall-doc
	-$(foreach e,$(EXECS),						\
	  rm -f "$(PREFIX)/bin/$(e)$(BYTE_EXT)"				\
	        "$(PREFIX)/bin/$(e)$(NATIVE_EXT)";)

# ---

ifneq ($(OPAM_PACKAGE_NAME),)
.PHONY: install-opam
install-opam: install-findlib install-doc all doc force
	$(QUIET)exec 1>"$(OPAM_PACKAGE_NAME).install";			\
	  echo 'bin: [';
    ifeq ($(ENABLE_BYTE),yes)
	$(QUIET)exec 1>>"$(OPAM_PACKAGE_NAME).install";			\
	  $(foreach e,$(EXECS),						\
	    echo ' "_build/src/main/$(e).byte" {"$(e)'$(BYTE_EXT)'"}';)
    endif
    ifeq ($(ENABLE_NATIVE),yes)
	$(QUIET)exec 1>>"$(OPAM_PACKAGE_NAME).install";			\
	  $(foreach e,$(EXECS),						\
	    echo ' "_build/src/main/$(e).native"			\
	      {"$(e)'$(NATIVE_EXT)'"}';)
    endif
	$(QUIET)exec 1>>"$(OPAM_PACKAGE_NAME).install";			\
	  echo ']';

.PHONY: uninstall-opam
uninstall-opam: uninstall-findlib uninstall-doc
# Note the documentation directory could be removed by OPAM.
endif

# ---

# In case we are in a development directory, with `git' hopefully:
HAS_GIT = $(shell command -v git 2>&1 >/dev/null && test -d ".git" && \
	          echo yes || echo no)
.PHONY: clean-version
ifeq ($(HAS_GIT),yes)
  VERSION_STR = $(shell git describe --tags --always)
  # XXX remove commit info that is appended at the end for
  # readability: this is ok as long as we have only one branch.
  # VERSION_STR := $(patsubst %-g$(shell git describe --always	\
  #                                       --abbrev),%, $(VERSION_STR)))
  clean-version: force
	rm -f version.ml.in
else
  VERSION_STR = unknown
  clean-version:
endif

# ---

ifneq ($(OPAM_DEVEL_DIR),)
  -include $(OPAM_DEVEL_DIR)/opam-dist.mk
  opam-package: META
endif

# ---

ifneq ($(VERSION_STR),unknown)
  opam-package: force-rebuild-version.ml.in

  .PHONY: force-rebuild-version.ml.in
  force-rebuild-version.ml.in: force
	@rm -f version.ml.in && $(MAKE) --no-print-directory		\
	  version.ml.in

  version.ml.in:
	@echo "Creating \`$@'." >/dev/stderr;
	$(QUIET)echo "let str = \"$(VERSION_STR)\"" >$@

  META_FILES = etc/META.in $(addprefix etc/META.,$(AVAILABLE_LIBs))

  META: $(META_FILES) force
	sed -e "s __VERSION_STR__ $(VERSION_STR) g" $(META_FILES) > $@
else
  META:
	$(eval __DUMMY__ := $$(error Unable to create META file))
endif

# -----------------------------------------------------------------------
