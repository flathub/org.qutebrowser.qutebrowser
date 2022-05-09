#!/bin/bash

_FPID=org.qutebrowser.qutebrowser

[ -f ${_FPID}.yml ] || { echo "Can't find ${_FPID}.yml"; exit 1; }

_TOOLSDIR=$PWD/tools

flatpak-external-data-checker --edit-only ${_FPID}.yml

#for _mod in python-adblock; do
#  (
#    cd ${_mod%:*}
#    case $_mod in
#      *:*Cargo.lock)
#        ${_TOOLSDIR}/cargo-updater $(basename ${_mod%:*}) ${_mod#*:}
#        ;;
#      *)
#        ${_TOOLSDIR}/cargo-updater $(basename ${_mod%:*})
#        ;;
#    esac
#  )
#done

# python modules with multiple dependencies and have a requirements.txt file
#for _mod in tests; do
#  (
#    cd $_mod
#    ${_TOOLSDIR}/pip-updater $(basename $_mod)
#  )
#done

# make only modules
#for _mod in asciidoc maturin-bin/maturin-bin-{aarch64,x86_64}; do
#  ${_TOOLSDIR}/fedc-merge-updater $_mod
#done
