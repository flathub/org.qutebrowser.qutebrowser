#!/bin/bash

_FPID=org.qutebrowser.qutebrowser

[ -f ${_FPID}.yml ] || { echo "Can't find ${_FPID}.yml"; exit 1; }
flatpak run \
  --runtime=org.freedesktop.Sdk//21.08 \
  --filesystem=$PWD \
  org.flathub.flatpak-external-data-checker \
  --edit-only ${_FPID}.yml

tools/pip-updater

for _mod in maturin python-adblock; do
  pushd $_mod
  ../tools/cargo-updater $_mod
  popd
done

for _mod in asciidoc pyqt5/{pyqt-builder,pyqt5-sip,sip} python-packaging{,/python-pyparsing} python-toml; do
  tools/fedc-merge-updater $_mod
done
