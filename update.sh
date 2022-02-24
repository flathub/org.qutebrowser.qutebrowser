#!/bin/bash

_FPID=org.qutebrowser.qutebrowser

[ -f ${_FPID}.yml ] || { echo "Can't find ${_FPID}.yml"; exit 1; }

_TOOLSDIR=$PWD/tools

flatpak run \
  --runtime=org.freedesktop.Sdk//21.08 \
  --filesystem=$PWD \
  org.flathub.flatpak-external-data-checker \
  --edit-only ${_FPID}.yml

for _mod in maturin python-adblock userscripts-dependencies/python-stem/python-cryptography:src/rust/Cargo.lock; do
  pushd ${_mod%:*}
  case $_mod in
    *:*Cargo.lock)
      ${_TOOLSDIR}/cargo-updater $(basename ${_mod%:*} ${_mod#*:})
      ;;
    *)
      ${_TOOLSDIR}/cargo-updater $(basename ${_mod%:*})
      ;;
  esac
  popd
done

# python modules with multiple dependencies and have a requirements.txt file
for _mod in userscripts-dependencies/python-{beautifulsoup4,pocket-api,pykeepass,pynacl,readability-lxml,stem/python-cryptography/python-setuptools-rust,tldextract}; do
  pushd $_mod
  ${_TOOLSDIR}/pip-updater $(basename $_mod)
  popd
done

# make only modules
for _mod in asciidoc pyqt5/{pyqt-builder,pyqt5-sip,python-toml,sip} python-packaging-tools/python-{build,flit-core,installer,packaging,pip517,pyparsing,setuptools-scm,tomli} userscripts-dependencies/python-stem/python-cryptography/python-setuptools-rust{,python-{semantic-version,typing-extensions}}; do
  ${_TOOLSDIR}/fedc-merge-updater $_mod
done
