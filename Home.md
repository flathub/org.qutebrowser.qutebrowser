# qutebrowser Flatpak documentation

The documnetation here focuses on the challenges presented to the user when running qutebrowser in a Flatpak sandbox,
and the possible workarounds.

**For any other information about qutebrowser, please visit the [official website](https://qutebrowser.org/).**


## Sandbox and challenges

### Filesystem access

Flatpak set user namespaces as part of the sandbox creation.  
In particular, a mount namespace is created for each application instance, and by default, very limited host resources
are bind mounted into this mount namespace.  
Flatpak provided a way to access host files and folders using the [Document Portal](https://flatpak.github.io/xdg-desktop-portal/#gdbus-org.freedesktop.portal.Documents),
which the user usually interacts with through the [FileChooser Portal](https://flatpak.github.io/xdg-desktop-portal/#gdbus-org.freedesktop.portal.FileChooser)
that runs on the host system.  
qutebrowser has its own filechooser dialog, which cannot use the `Document Portal`, as it's in the same sandboxed process.

This means that any host resource (files, folders) that needs to be access by qutebrowser will needed to be bind mounted
into the sandbox.  
A few XDG dirs are already set to be accessible in the sandbox, and the user can add others (or remove) by adding a
`filesystem` override.

### Running external applications

It's not possible to directly run host or Flatpak applications from the sandbox without some ugly workarounds.  
Thankfully, the Flatpak runtime includes `flatpak-spawn`, which given the permission needed, can run applications
outside of the sandbox, and even connect the standard streams from the spawned application to its own process, which
runs inside the sandbox.

It's should be noted that environment of the spawned host or Flatpak applications is not inherited from the qutebrowser
Flatpak instance, nor from the process that started the qutebrowser app.  
Instead, the environment inherited from the systemd user unit `flatpak-session-helper.service`.

A `flatpak-spwan` wrapper is packaged with the qutebrowser Flatpak to help using host applications and other Flatpak
apps with qutebrowser and userscripts.

### Adding userscripts dependencies

Official and popular userscripts require Python modules with their shared libraries requirements, and different
utilities.  
These needs to be accessible to the sandbox, and depending on runtime or app provided libraries and modules.  
While it's possible to install Python modules into a different location than `/usr`, instructing users to compile shared
libraries and utilities is not an acceptable solution.

To solve this, the Flatpak extension [org.qutebrowser.qutebrowser.Userscripts](https://github.com/flathub/org.qutebrowser.qutebrowser.Userscripts)
packages dependencies for all the offical userscripts, and for most popular userscripts.


## Userscripts: Make them work

Depending on the specific userscript, one or more of the following is needed in order to successfully run the userscript.

* Install the Userscripts extension
* Enable host access for flatpak-spwan
* Add filesystem access
* Setting environment of spawned applications
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

### Setting environment of spawned applications

The environment of host and Flatpak applications that were started by `flatpak-spawn` will be derived from the
environment of the system user unit `flatpak-session-helper.service`.

Some of these environment variables are user defined.  
Others are important for the current running graphical session, and application might not be started correctly without
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

Yes, it's actually possible, though it will require maintenance after a runtime update that bumps Python version,
which only happens once a year.  
You might not need this, as the Userscripts extension provides already a good number of Python modules.

**Important facts**

* The default Python user scheme installation is `XDG_DATA_HOME/python`
* `XDG_DATA_HOME=$HOME/.var/app/org.qutebrowser.qutebrowser/data`
* `XDG_DATA_HOME` is mounted on `/var/data`
* `PATH` includes `/var/data/python/bin`

#### Initial setup

We need first to install the Flatpak SDK, as the Platform runtime is missing `pip`.
```
$ flatpak install flathub $(flatpak info --show-sdk org.qutebrowser.qutebrowser)
```
The next step is to install `pip` and `wheel` in the user Python installation.  
Notice the `--devel` option that instructs Flatpak to mount the SDK as runtime.
```
$ flatpak run --devel --command=pip3 org.qutebrowser.qutebrowser install --user --ignore-installed pip wheel
```
Now it's safe to remove the SDK.
```
$ flatpak uninstall flathub $(flatpak info --show-sdk org.qutebrowser.qutebrowser)
```

#### Installing modules

You can run `pip` now without `--user` option, as there's only the one from the user installation.
```
$ flatpak run --command=pip org.qutebrowser.qutebrowser install <python-module> ...
```
Or if you choose, you can enter the sandbox, and then run the pip.
```
$ flatpak run --command=bash org.qutebrowser.qutebrowser
$ pip install <python-module> ...
```

#### Upgrading

The upgrade process is very similar to the initial setup.

Install the SDK after the application was updated and switched to the new runtime.
```
$ flatpak install flathub $(flatpak info --show-sdk org.qutebrowser.qutebrowser)
```
Upgrade `pip` and `wheel` in the user Python installation.
```
$ flatpak run --devel --command=pip3 org.qutebrowser.qutebrowser install --user --ignore-installed --upgrade pip wheel
```
Now it's safe to remove the SDK.
```
$ flatpak uninstall flathub $(flatpak info --show-sdk org.qutebrowser.qutebrowser)
```
Upgrade the rest of the installed Python modules.
```
$ flatpak run --command=pip org.qutebrowser.qutebrowser install --upgrade <python-module> ...
```

## Better video playback: The full FFmpeg extension

Some Linux distributions and organizations are more strict with regrads to non-free or potentially patented software
or intellectual property.  
To comply with these restriction and have this Flatpak included in repositories of such distros, the full FFmpeg
extension `org.freedesktop.Platform.ffmpeg-full` has been made optional, even though it have more and better decoders.

You might already have the extension install. This can be easily confirmed by checking if the extension was mounted
onto `/app/lib/ffmpeg`.
```
$ flatpak run --command=ls org.qutebrowser.qutebrowser /app/lib/ffmpeg
etc
libavcodec.so
libavcodec.so.58
...
```
If it's missing then check the needed version of the extension.
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
