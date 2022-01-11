.DEFAULT_GOAL := all
PREFIX := /app
BINDIR := ${PREFIX}/bin
LIBDIR := ${PREFIX}/lib
FSWLIBDIR := ${LIBDIR}/flatpak-spawn-wrapper

symlinks := $(shell bash -c 'declare -A apps; source apps.conf; echo $${!apps[@]};')

all:
	echo "do nothing"

install:
	install -Dm755 wrapper -t ${FSWLIBDIR}/
	install -Dm644 apps.conf -t ${FSWLIBDIR}/
	for symlink in ${symlinks}; do \
		ln -sr ${FSWLIBDIR}/wrapper ${BINDIR}/$${symlink}; \
	done
