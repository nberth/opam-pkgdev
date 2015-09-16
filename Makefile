# -*- makefile-gmake -*-
# -----------------------------------------------------------------------
#
# Makefile for building the opam-pkgdev package.
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
# -----------------------------------------------------------------------

PKGNAME = opam-pkgdev
PKGVERS = $(shell git describe --tags --always)

OPAM_DIR = opam
OPAM_FILES = descr opam
DIST_FILES = generic.mk LICENSE Makefile Makefile.example	\
	     opam-pkgdev.install README.md
ifndef OPAM_DIST_DIR
  $(error OPAM_DIST_DIR must be defined to build this package)
else
  include $(OPAM_DIST_DIR)/opam-dist.mk
endif

# -----------------------------------------------------------------------

