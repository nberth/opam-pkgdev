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
SRC ?= src

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
ifeq ($(ENABLE_DEBUG),yes)
  LIBSUFF += d.cma
endif
ifeq ($(ENABLE_NATIVE),yes)
  LIBSUFF += cmx cmxa a
  ifeq ($(ENABLE_PROFILING),yes)
    LIBSUFF += p.cmxa
  endif
endif
TARGETS = $(foreach p,$(AVAILABLE_LIBs),$(addprefix $(p).,$(LIBSUFF)))
TARGETS += $(foreach p,$(AVAILABLE_LIB_ITFs),$(p).cmi)

ifeq ($(ENABLE_BYTE),yes)
  TARGETS += $(addsuffix .byte,$(EXECS))
  TEST_TARGETS += $(addsuffix .byte,$(TEST_EXECS))
endif
ifeq ($(ENABLE_NATIVE),yes)
  TARGETS += $(addsuffix .native,$(EXECS))
endif
ifeq ($(ENABLE_DEBUG),yes)
  TARGETS += $(addsuffix .d.byte,$(EXECS))
endif
ifeq ($(ENABLE_PROFILING),yes)
  TARGETS += $(addsuffix .p.native,$(EXECS))
endif

TARGETS := $(strip $(TARGETS))
TEST_TARGETS := $(strip $(TEST_TARGETS))

# ---

BYTE_EXT = 
OPT_EXT = .opt
DBG_EXT = .d
ifeq ($(ENABLE_NATIVE),yes)
  ifneq ($(ENABLE_BYTE),yes)
    OPT_EXT =
  endif
endif

# ---

OCAMLBUILD ?= ocamlbuild -use-ocamlfind
OCAMLDOC ?= ocamldoc
TEST_FLAGS ?= -no-links
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

DOC_TARGETS ?= $(foreach p,$(AVAILABLE_LIBs),$(SRC)/$(p).docdir/index.html)

.PHONY: doc
doc: force
ifneq ($(strip $(DOC_TARGETS)),)
	$(QUIET)$(OCAMLBUILD) $(OCAMLBUILDFLAGS)			\
	  -ocamldoc "$(OCAMLDOC) $(OCAMLDOCFLAGS)"			\
	  -no-sanitize -no-hygiene					\
	  $(DOC_TARGETS)
endif

# ---

.PHONY: install-findlib uninstall-findlib
ifeq ($(INSTALL_LIBS),yes)
  install-findlib: META build
	-ocamlfind remove $(PKGNAME) 2> /dev/null;
	ocamlfind install $(PKGNAME) META				\
	  $(foreach p,$(AVAILABLE_LIBs),                 		\
	    $(addprefix _build/$(SRC)/$(p).,$(LIBSUFF)))		\
	  $(foreach p,$(AVAILABLE_LIB_ITFs),_build/$(SRC)/$(p).cmi)

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

USE_PER_LIB_INSTALL_DOC ?= yes

.PHONY: install-doc uninstall-doc
ifeq ($(INSTALL_DOCS),yes)
  .PHONY: install-doc-init install-doc-per-lib
  install-doc-init: chk-docdir doc
	rm -rf "$(DOCDIR)/$(PKGNAME)";
	install -d "$(DOCDIR)/$(PKGNAME)";

  install-doc-per-lib: install-doc-init
  ifeq ($(USE_PER_LIB_INSTALL_DOC),yes)
	$(foreach p,$(AVAILABLE_LIBs),					\
	  test -d "_build/$(SRC)/$(p).docdir" &&			\
	    cp -r "_build/$(SRC)/$(p).docdir" "$(DOCDIR)/$(PKGNAME)/$(p)";)
  endif

  install-doc: install-doc-per-lib
  uninstall-doc: chk-docdir force
	rm -rf "$(DOCDIR)/$(PKGNAME)";
else
  install-doc:
  uninstall-doc:
endif

# ---

ALL_BINS = $(strip $(EXECS) $(EXTRA_EXECS))
ALL_LIBS = $(strip $(EXTRA_LIBs))

.PHONY: install
install: chk-prefix build install-findlib install-doc
  ifneq ($(ALL_BINS),)
	install -d "$(PREFIX)/bin";
	$(foreach e,$(EXECS), [ -x "$(e).byte" ] &&			\
	  install "$(e).byte" "$(PREFIX)/bin/$(e)$(BYTE_EXT)" || true;)
	$(foreach e,$(EXECS), [ -x "$(e).d.byte" ] &&			\
	  install "$(e).d.byte" "$(PREFIX)/bin/$(e)$(DBG_EXT)" || true;)
	$(foreach e,$(EXECS), [ -x "$(e).native" ] &&			\
	  install "$(e).native" "$(PREFIX)/bin/$(e)$(OPT_EXT)" || true;)
	$(foreach e,$(EXTRA_EXECS), [ -x "$(e)" ] &&			\
	  install "$(e)" "$(PREFIX)/bin/$(basename $(e))" || true;)
  endif
  ifneq ($(ALL_LIBS),)
	install -d "$(PREFIX)/lib";
	$(foreach e,$(EXTRA_LIBs), [ -f "$(e)" ] &&			\
	  install "$(e)" "$(PREFIX)/lib/$(basename $(e))" || true;)
  endif

.PHONY: uninstall
uninstall: chk-prefix uninstall-findlib uninstall-doc
	-$(foreach e,$(EXECS),						\
	  rm -f "$(PREFIX)/bin/$(e)$(BYTE_EXT)"				\
		"$(PREFIX)/bin/$(e)$(DBG_EXT)"				\
	        "$(PREFIX)/bin/$(e)$(OPT_EXT)";)
	-$(foreach e,$(EXTRA_EXECS),					\
	  rm -f "$(PREFIX)/bin/$(basename $(e))";)
	-$(foreach e,$(EXTRA_LIBs),					\
	  rm -f "$(PREFIX)/lib/$(basename $(e))";)

# ---

$(PKGNAME).install:
	$(QUIET)exec 1>$@;
ifneq ($(ALL_BINS),)
	$(QUIET)exec 1>>$@;						\
	echo 'bin: [';							\
	$(foreach e,$(EXECS), echo '"?$(e).byte" {"$(e)$(BYTE_EXT)"}';	\
			      echo '"?$(e).d.byte" {"$(e)$(DBG_EXT)"}';	\
	  		      echo '"?$(e).native" {"$(e)$(OPT_EXT)"}';)\
	$(foreach e,$(EXTRA_EXECS), echo '"$(e)" {"$(basename $(e))"}';)\
	echo ']';
endif
ifneq ($(ALL_LIBS),)
	$(QUIET)exec 1>>$@;						\
	echo 'lib: [';							\
	$(foreach e,$(EXTRA_LIBs), echo '"$(e)" {"$(basename $(e))"}';)	\
	echo ']';
endif

# The following indicates we are possibly installing through OPAM:
ifneq ($(OPAM_PACKAGE_NAME),)
  ifneq ($(OPAM_PACKAGE_NAME),$(PKGNAME))
    $(OPAM_PACKAGE_NAME).install: $(PKGNAME).install
	cp $< $@
  endif

  .PHONY: install-opam
  install-opam: build install-findlib install-doc			\
		$(OPAM_PACKAGE_NAME).install

  .PHONY: uninstall-opam
  uninstall-opam: uninstall-findlib uninstall-doc
  # Note the documentation directory could be removed by OPAM.

  .PHONY: clean-$(OPAM_PACKAGE_NAME)-install
  clean-$(OPAM_PACKAGE_NAME)-install:
	rm -f $(OPAM_PACKAGE_NAME).install
  clean: clean-$(OPAM_PACKAGE_NAME)-install
endif

# ---

# Build and run test files for now.
.PHONY: check
check: force $(EXTRA_DEPS)
  ifneq ($(TEST_TARGETS),)
	$(QUIET)$(OCAMLBUILD) $(OCAMLBUILDFLAGS) $(TEST_FLAGS)		\
		$(TEST_TARGETS);
	$(QUIET)for target in $(TEST_TARGETS); do			\
		echo "Running $$target";				\
		$(OCAMLBUILD) $(OCAMLBUILDFLAGS) $(TEST_FLAGS) 		\
			-quiet -no-hygiene -no-sanitize $${target} --;	\
	done;
  else
	$(QUIET)echo "Nothing to build."
  endif

# ---

# In case we are in a development directory, with `git' hopefully:
HAS_GIT = $(shell command -v git 2>&1 >/dev/null && test -d ".git" &&	\
	          echo yes || echo no)
ifeq ($(HAS_GIT),yes)
  MAIN_BRANCH ?= master
  PKGVERS ?= $(shell git describe --tags --always)
  CURBRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
  CURBRANCH := $(strip $(CURBRANCH:$(MAIN_BRANCH)=))
  ifneq ($(CURBRANCH),)
    # Replace detailed commit info with specific branch name.
    DEVINFO := g$(shell git describe --always --abbrev)
    PKGVERS := $(patsubst %-$(DEVINFO),%,$(PKGVERS))
    PKGVERS := $(shell	v="$(PKGVERS)"; vx="$${v}-";			\
			base="$${v%%-*}"; ext="$${vx\#*-}";		\
			echo "$${base}~$(CURBRANCH)$${ext%%-*}")
  endif
else
  # Try to guess from project directory name:
  ROOT_DIRNAME = $(dir $(firstword $(MAKEFILE_LIST)))
  PKGVERS0 = $(notdir $(abspath $(ROOT_DIRNAME)))
  __EXTRACT_VERS = \
    $(strip $(patsubst $(PKGNAME)$(1)%,%,$(filter $(PKGNAME)$(1)%,$(2))))
  PKGVERS ?= $(strip $(or $(OPAM_PACKAGE_VERSION),\
			  $(call __EXTRACT_VERS,.,$(PKGVERS0)),\
			  $(call __EXTRACT_VERS,-,$(PKGVERS0)),\
			  unknown))
endif

# ---

ifneq ($(OPAM_DIST_DIR),)
  DIST_FILES += $(OPAM_PKGDEV_DIR)/generic.mk
  -include $(OPAM_DIST_DIR)/opam-dist.mk
  opam-dist-arch: META.in
endif

# ---

.PHONY: clean-version
ifneq ($(PKGVERS),unknown)
  ifeq ($(BUILD_VERSION_ML_IN),yes)
    opam-dist-arch: force-rebuild-version.ml.in

    .PHONY: force-rebuild-version.ml.in
    force-rebuild-version.ml.in: force
	$(QUIET)rm -f version.ml.in && $(MAKE) --no-print-directory	\
	  version.ml.in
  endif

  version.ml.in:
	@echo "Creating \`$@'." >/dev/stderr;
	$(QUIET)echo "let str = \"$(PKGVERS)\"" >$@

  clean-version: force
	rm -f version.ml.in META.in

  ifneq ($(wildcard etc/META.in),)
    META.in: etc/META.in force
	sed -e "s __VERSION_STR__ $(PKGVERS) g;\
	        s __PKGVERS__ $(PKGVERS) g;" $< > $@
  else
    META.in:
  endif

else
  $(warning Unable to guess package version)
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
