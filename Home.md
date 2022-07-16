# qutebrowser Flatpak documentation

The documentation here focuses on the challenges presented to the user when running qutebrowser in a Flatpak sandbox,
and the possible workarounds.

**For any other information about qutebrowser, please visit the [official website](https://qutebrowser.org/).**

To help to improve this documentation, open a pull request against the
[wiki branch](https://github.com/flathub/org.qutebrowser.qutebrowser/tree/wiki).

## Sandbox and challenges

### Filesystem access

Flatpak sets user namespaces as part of the sandbox creation.  
In particular, a mount namespace is created for each application instance, and by default, and very limited host
resources are bind mounted into this mount namespace.  
Flatpak provides a way to access host files and folders using the [Document Portal](https://flatpak.github.io/xdg-desktop-portal/#gdbus-org.freedesktop.portal.Documents),
which the user usually interacts with through the [FileChooser Portal](https://flatpak.github.io/xdg-desktop-portal/#gdbus-org.freedesktop.portal.FileChooser)
that runs on the host system.  
qutebrowser has its own file chooser dialog, which cannot use the `Document Portal`, as it runs in the same sandboxed
process.

This means that any host resource (files and folders) that needs to be accessed by qutebrowser will need to be bind mounted
into the sandbox.  
A few XDG dirs (e.g. `XDG_DOWNLOAD_DIR`) are already set to be accessible in the sandbox, and the user can add others
(or remove) by adding a `filesystem` override.

### Running external applications

Flatpak provides a way to launch host and Flatpak applications from a Flatpak sandbox with the help of `flatpak-spawn`,
and connect standard streams from the spawned application to `flatpak-spawn`'s process that runs inside the sandbox.

The spawned host or Flatpak application will run outside of qutebrowser's Flatpak sandbox, and the environment of this
spawned application is not inherited from qutebrowser's Flatpak instance, nor from the process that launched qutebrowser.  
Instead, the environment inherited from the environment of the systemd user unit `flatpak-session-helper.service`, which
in turn inherited from the systemd user session environment.

A `flatpak-spwan` wrapper is bundled with this qutebrowser Flatpak to help launch host and Flatpak applications from the
qutebrowser's Flatpak sandbox, and use these applications with userscripts.

### Adding userscripts dependencies

Some qutebrowser userscripts depend on Python modules with their shared libraries requirements and utilities that need
to be accessible in the sandbox to qutebrowser.  
The Flatpak extension [org.qutebrowser.qutebrowser.Userscripts](https://github.com/flathub/org.qutebrowser.qutebrowser.Userscripts)
packages dependencies for the bundled official userscripts and for some of the popular ones,
to help the user avoid installing Python modules, or compile shared libraries and utilities.

## Userscripts: Make them work

Depending on the specific userscript, one or more of the following is needed in order to successfully run the userscript.

* Install the Userscripts extension
* Enable host access for flatpak-spwan
* Add filesystem access
* Set the environment of spawned applications
* Install Python modules inside the sandbox

### Install the Userscripts extension

Actually, this extension does not include userscripts, but their dependencies, and is not installed by default due to
its size.
```
$ flatpak install flathub org.qutebrowser.qutebrowser.Userscripts
```
If you have a suggestion for any other userscript dependency, then please open a bug report [here](https://github.com/flathub/org.qutebrowser.qutebrowser.Userscripts/issues).
Note that except for small helper utilities (e.g. `wl-clipboard`), requests to bundle applications will not be approved.

### Enable host access for flatpak-spwan

In order to allow our `flatpak-spwan` wrapper to run applications on the host, it needs D-Bus session access to
`org.freedesktop.Flatpak`.  
This is a quite permissive permission that allows running any host executable, including SUID binaries. This is not a
small hole in the sandbox, and why the Flatpak app is not shipped with this enabled.
```
$ flatpak override --user --talk-name=org.freedesktop.Flatpak org.qutebrowser.qutebrowser
```

### Add filesystem access

Userscripts that share files or sockets with applications will likely use `/tmp`.
```
$ flatpak override --user --filesystem=/tmp org.qutebrowser.qutebrowser
```

### Set the environment of spawned applications

The environment of host and Flatpak applications that were started by `flatpak-spawn` will be derived from the
environment of the system user unit `flatpak-session-helper.service`.

Some of these environment variables are user defined.  
Others are important for the current running graphical session, and the application might not be started correctly without
them. Like `DISPLAY`, `WAYLAND_DISPLAY`, `XDG_SESSION_TYPE`, `DBUS_SESSION_BUS_ADDRESS`.

User defined environment variables should be set by the desktop environment (e.g. Gnome) in the system user session
before `flatpak-session-helper.service` is started.

Print the systemd user session environment.
```
$ systemctl --user show-environment
```
Import variables from the current environment into the systemd user environment.
```
$ systemctl --user import-environment VAR1 VAR2 ...
```
Set variables in the systemd user environment.
```
$ systemctl --user set-environment VAR1=VALUE1 VAR2=VALUE1 ...
```
Restart the systemd user unit `flatpak-session-helper.service` for changes to take effect.
```
$ systemd restart --user flatpak-session-helper.service
```

### Install Python modules inside the sandbox

Yes, it's actually possible to add Python modules that would be available inside the sandbox, and that by using the
`user scheme` for installation.  
This will require manual intervention after a runtime update that bumps the minor Python version, something that only
happens once a year, so you probably want to write down the explicitly installed Python modules.  
You might not need this, as the Userscripts extension provides already a good number of Python modules.

**Important facts**

* The default Python `user scheme` installation is `XDG_DATA_HOME/python`
* `XDG_DATA_HOME=$HOME/.var/app/org.qutebrowser.qutebrowser/data`
* `XDG_DATA_HOME` is mounted on `/var/data`
* `PATH` includes `/var/data/python/bin`

#### Initial setup

You likely want to first install the Userscripts extension (see above), as it provides updated `pip` and `wheel` modules,
other Python modules, shared libraries, and utilities.

If you expect that `pip` will need compile libraries to native code, then you will need to install the Flatpak SDK,
which include the GNU toolchain, and also offer access to Flatpak SDK extension.

* Install the Flatpak SDK of the KDE runtime used by our qutebrowser Flatpak
```
$ flatpak install flathub $(flatpak info --show-sdk org.qutebrowser.qutebrowser)
```

If for some reason, you want to avoid the Userscript extension, then it's possible use `pip` from the SDK to install
modules. Note that the executable in the SDK is `pip3`.  
For example, to install updated `pip` and `wheel` modules in the `user scheme` installation.  
```
$ flatpak run --devel --command=pip3 org.qutebrowser.qutebrowser install --user --ignore-installed pip wheel
```

#### Installing modules

Run `pip` by using Flatpak `--command` option.
```
$ flatpak run --command=pip org.qutebrowser.qutebrowser install --user [pip-options] <python-module> ...
```
Or if you choose, you can enter the sandbox, and then run `pip`.
```
$ flatpak run --command=bash org.qutebrowser.qutebrowser
$ pip install --user [pip-options] <python-module> ...
```
Important to note here that we run the `pip` executable, which is the updated module provided by the Userscripts
extension. The `pip3` executable is from the SDK runtime, which is possibly outdated, and not even be available if
don't use the SDK.  
The `--user` `pip` option is used here to avoid the non-writable warning, and you can drop it, as the `user scheme`
will be used anyway.

##### Installing modules with the SDK runtime

In a similar fashion, to install modules with the SDK runtime, run `pip` by using Flatpak `--command` option.
```
$ flatpak run --devel --command=pip org.qutebrowser.qutebrowser install --user [pip-options] <python-module> ...
```
Notice that given `--devel` Flatpak option that instructs Flatpak to mount the SDK as the runtime on top `/usr`.

And again, you can first enter the sandbox, and then run `pip`.
```
$ flatpak run --devel --command=bash org.qutebrowser.qutebrowser
$ pip install --user [pip-options] <python-module> ...
```
Entering the sandbox before running `pip` make it easier to enable required SDK extensions required by `pip`.
For example, to enable the [rust-stable](https://github.com/flathub/org.freedesktop.Sdk.Extension.rust-stable) SDK extension.
```
$ source /usr/lib/sdk/rust-stable/enable.sh
```

#### Upgrading

If you written down the explicitly installed Python modules, and didn't need to use the Flatpak SDK, then the upgrade
process is very simple.
```
$ flatpak run --command=pip org.qutebrowser.qutebrowser install --user --upgrade <python-module> ...
```
If the SDK runtime was needed for installation of Python modules, then you'll need to follow the same steps.

## Better video playback: The full FFmpeg extension

Some Linux distributions and organizations are stricter in regard to non-free or potentially patented software
or intellectual property.  
To comply with these restriction and have this Flatpak included in repositories of such distros, the full FFmpeg
extension `org.freedesktop.Platform.ffmpeg-full` has been made optional, even though it has more and better decoders.

You might already have the extension install. This can be easily confirmed by checking if the extension was mounted
onto `/app/lib/ffmpeg`.
```
$ flatpak run --command=ls org.qutebrowser.qutebrowser /app/lib/ffmpeg
etc
libavcodec.so
libavcodec.so.58
...
```
If it's missing, then check the needed version of the extension.
```
$ flatpak info --show-metadata org.qutebrowser.qutebrowser
...
[Extension org.freedesktop.Platform.ffmpeg-full]
directory=lib/ffmpeg
no-autodownload=true
add-ld-path=.
version=21.08
...
```
Install the `org.freedesktop.Platform.ffmpeg-full//version` extension.
```
$ flatpak install flathub org.freedesktop.Platform.ffmpeg-full//21.08
```
