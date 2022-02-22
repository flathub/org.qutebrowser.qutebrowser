#!/bin/bash

_FPID=org.qutebrowser.qutebrowser

[ -f ${_FPID}.yml ] || { echo "Can't find ${_FPID}.yml"; exit 1; }

_TOOLSDIR=$PWD/tools

flatpak run \
  --runtime=org.freedesktop.Sdk//21.08 \
  --filesystem=$PWD \
  org.flathub.flatpak-external-data-checker \
  --edit-only ${_FPID}.yml

for _mod in maturin python-adblock; do
  pushd $_mod
  ${_TOOLSDIR}/cargo-updater $(basename $_mod)
  popd
done

# python modules with multiple dependencies and have a requirements.txt file
for _mod in userscripts-dependencies/python-{bs4,pocket-api,pykeepass,readability-lxml,tldextract}; do
  pushd $_mod
  ${_TOOLSDIR}/pip-updater $(basename $_mod)
  popd
done

# make only modules
for _mod in asciidoc pyqt5/{pyqt-builder,pyqt5-sip,sip} python-packaging{,/python-pyparsing} python-toml; do
  ${_TOOLSDIR}/fedc-merge-updater $_mod
done
