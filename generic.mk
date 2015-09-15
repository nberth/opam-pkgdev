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
#
# See `Makefile.example' in `opam-pkgdev' source repository for usage
# information.
#
# ----------------------------------------------------------------------

QUIET ?= @

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
ifeq ($(ENABLE_DEBUG),yes)
  TARGETS += $(addprefix src/main/,$(addsuffix .d.byte,$(EXECS)))
endif
ifeq ($(ENABLE_PROFILING),yes)
  TARGETS += $(addprefix src/main/,$(addsuffix .p.native,$(EXECS)))
endif

TARGETS := $(strip $(TARGETS))

# ---

NATIVE_EXT = .opt
BYTE_EXT = 
ifeq ($(ENABLE_NATIVE),yes)
  ifneq ($(ENABLE_BYTE),yes)
    NATIVE_EXT = 
  endif
endif

# ---

OCAMLBUILD ?= ocamlbuild -use-ocamlfind
OCAMLDOC ?= ocamldoc
NO_PREFIX_ERROR_MSG ?= Missing prefix: use "make PREFIX=..."
NO_DOCDIR_ERROR_MSG ?= Missing documentation directory: use \
                       "make DOCDIR=..."
BUILD_VERSION_ML_IN ?= yes

ifeq ($(BUILD_VERSION_ML_IN),yes)
  EXTRA_DEPS += version.ml.in
endif

# ---

.PHONY: build
build: force $(EXTRA_DEPS)
  ifneq ($(TARGETS),)
	$(QUIET)$(OCAMLBUILD) $(OCAMLBUILDFLAGS) $(TARGETS)
  else
	$(QUIET)echo "Nothing to build."
  endif

.PHONY: clean
clean: force
	$(QUIET)rm -f META
  ifneq ($(TARGETS),)
	$(QUIET)$(OCAMLBUILD) $(OCAMLBUILDFLAGS) -clean
  endif

.PHONY: force
force:

# ---

.PHONY: doc
doc: force
ifneq ($(strip $(AVAILABLE_LIBs)),)
	$(QUIET)$(OCAMLBUILD) $(OCAMLBUILDFLAGS) -I .			\
	  -ocamldoc "$(OCAMLDOC) $(OCAMLDOCFLAGS)"			\
	  -no-sanitize -no-hygiene					\
	  $(foreach p,$(AVAILABLE_LIBs),src/$(p).docdir/index.html)
endif

# ---

.PHONY: install-findlib uninstall-findlib
ifeq ($(INSTALL_LIBS),yes)
  install-findlib: META build
	-ocamlfind remove $(PKGNAME) 2> /dev/null;
	ocamlfind install $(PKGNAME) META				\
	  $(foreach p,$(AVAILABLE_LIBs),                 		\
	    $(addprefix _build/src/$(p).,$(LIBSUFF)))			\
	  $(foreach p,$(AVAILABLE_LIB_ITFs),_build/src/$(p).cmi)

  uninstall-findlib: force
	ocamlfind remove $(PKGNAME)
else
  install-findlib:
  ifneq ($(strip $(AVAILABLE_LIBs)),)
	$(QUIET)echo "Unable to install libraries";
  endif
  uninstall-findlib:
endif

# ---

# Force errors in case of empty variable definitions, even in dry run.

checkvar = $(or $(value $(1)),$(eval $$(error $(2))))

.PHONY: chk-prefix chk-docdir
chk-prefix: force
	$(eval $@_P := $(call checkvar,PREFIX,$(NO_PREFIX_ERROR_MSG)))
chk-docdir: force
	$(eval $@_P := $(call checkvar,DOCDIR,$(NO_DOCDIR_ERROR_MSG)))

# ---

.PHONY: install-doc uninstall-doc
ifeq ($(INSTALL_DOCS),yes)
  install-doc: chk-docdir doc
	rm -rf "$(DOCDIR)/$(PKGNAME)";
	mkdir -p "$(DOCDIR)/$(PKGNAME)";
	$(foreach p,$(AVAILABLE_LIBs),cp -r "_build/src/$(p).docdir"	\
	  "$(DOCDIR)/$(PKGNAME)/$(p)";)

  uninstall-doc: chk-docdir force
	rm -rf "$(DOCDIR)/$(PKGNAME)";
else
  install-doc:
  uninstall-doc:
endif

# ---

.PHONY: install
install: chk-prefix build install-findlib install-doc
	$(foreach e,$(EXECS), [ -x "_build/src/main/$(e).byte" ] &&	\
	  install "_build/src/main/$(e).byte"				\
	    "$(PREFIX)/bin/$(e)$(BYTE_EXT)" || exit 0;)
	$(foreach e,$(EXECS), [ -x "_build/src/main/$(e).native" ] &&	\
	  install "_build/src/main/$(e).native"				\
	    "$(PREFIX)/bin/$(e)$(NATIVE_EXT)" || exit 0;)
	$(foreach e,$(EXTRA_EXECS), [ -x "$(e)" ] &&	\
	  install "$(e)" "$(PREFIX)/bin/$(basename $(e))" || exit 0;)
	$(foreach e,$(EXTRA_LIBs), [ -x "$(e)" ] &&	\
	  install "$(e)" "$(PREFIX)/lib/$(basename $(e))" || exit 0;)

.PHONY: uninstall
uninstall: chk-prefix uninstall-findlib uninstall-doc
	-$(foreach e,$(EXECS),						\
	  rm -f "$(PREFIX)/bin/$(e)$(BYTE_EXT)"				\
	        "$(PREFIX)/bin/$(e)$(NATIVE_EXT)";)
	-$(foreach e,$(EXTRA_EXECS),					\
	  rm -f "$(PREFIX)/bin/$(basename $(e))";)
	-$(foreach e,$(EXTRA_LIBs),					\
	  rm -f "$(PREFIX)/lib/$(basename $(e))";)

# ---

# The following indicates we are possibly installing through OPAM:
ifneq ($(OPAM_PACKAGE_NAME),)
.PHONY: install-opam
install-opam: install-findlib install-doc build doc force
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
    ifneq ($(strip $(EXTRA_EXECS)),)
	$(QUIET)exec 1>>"$(OPAM_PACKAGE_NAME).install";			\
	  $(foreach e,$(EXTRA_EXECS),					\
	    echo ' "$(e)" {"$(basename $(e))"}';)
    endif
	$(QUIET)exec 1>>"$(OPAM_PACKAGE_NAME).install";			\
	  echo ']';
	$(QUIET)exec 1>>"$(OPAM_PACKAGE_NAME).install";			\
	  echo 'lib: [';
    ifneq ($(strip $(EXTRA_LIBs)),)
	$(QUIET)exec 1>>"$(OPAM_PACKAGE_NAME).install";			\
	  $(foreach e,$(EXTRA_LIBs),					\
	    echo ' "$(e)" {"$(basename $(e))"}';)
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
ifeq ($(HAS_GIT),yes)
  VERSION_STR ?= $(shell git describe --tags --always)
  ifeq ($(STRIP_VERSION_STR),yes)
    # Remove commit info that is appended at the end for readability:
    # this is ok as long as we have only one branch.
    VERSION_STR := $(patsubst %-g$(shell git describe --always	\
                     --abbrev),%,$(VERSION_STR))
  endif
else
  VERSION_STR ?= unknown
endif

# ---

ifneq ($(OPAM_DIST_DIR),)
  DIST_FILES += $(OPAM_PKGDEV_DIR)/generic.mk
  -include $(OPAM_DIST_DIR)/opam-dist.mk
  opam-dist-arch: META.in
endif

# ---

.PHONY: clean-version
ifneq ($(VERSION_STR),unknown)
  ifeq ($(BUILD_VERSION_ML_IN),yes)
    opam-dist-arch: force-rebuild-version.ml.in

    .PHONY: force-rebuild-version.ml.in
    force-rebuild-version.ml.in: force
	$(QUIET)rm -f version.ml.in && $(MAKE) --no-print-directory	\
	  version.ml.in

    version.ml.in:
	@echo "Creating \`$@'." >/dev/stderr;
	$(QUIET)echo "let str = \"$(VERSION_STR)\"" >$@
  endif

  clean-version: force
	rm -f version.ml.in META.in

  ifneq ($(wildcard etc/META.in),)
    META.in: etc/META.in force
	sed -e "s __VERSION_STR__ $(VERSION_STR) g" $< > $@
  else
    META.in:
  endif

else
  clean-version:
  META.in:
	$(eval __DUMMY__ := $$(error Unable to create META.in file))
endif

# ---

ifneq ($(AVAILABLE_LIBs),)
  META_FILES = META.in $(addprefix etc/META.,$(AVAILABLE_LIBs))
  META: $(META_FILES)
	cat $+ > $@
endif

# -----------------------------------------------------------------------
