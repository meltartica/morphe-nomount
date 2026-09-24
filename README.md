# morphe-nomount

Inject the Morphe root-mount modules using [NoMount](https://github.com/maxsteeel/nomount),
eliminating traditional mounts.

Morphe's root-mount mode does not install a patched app — it leaves the stock app
in place and `mount -o bind`s the patched APK over it, in the root namespace and
again inside each zygote namespace. That mount is visible in `/proc/mounts`, and
root detectors look for exactly that.

This module keeps the patched APK and throws the mount away. It disables the
Morphe module's own scripts and re-injects the same APK through NoMount's VFS
layer, which redirects path resolution in RAM and creates no mount at all.

## Usage

- Patch the app in Morphe in **root mount mode**, so Morphe writes its module to
  `/data/adb/modules/<package>-morphe/`.
- Make sure you have [NoMount](https://github.com/maxsteeel/nomount) integrated
  into your kernel and its module installed.
- Flash this module and reboot.

Nothing else to configure. The Morphe module stays **installed** — it holds the
patched APK — but is switched off, and re-switched-off on every boot so that
re-patching an app is picked up automatically.

If Termux is installed, a `morphe-nomount` command is created there to re-run the
injection without rebooting.

## What changed from rvmm-nomount

This is a fork of [rvmm-nomount](https://github.com/maxsteeel/rvmm-nomount),
which targets j-hc's
[revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module). The
mechanism is unchanged — disable the other module, re-inject via NoMount — but
the discovery had to be rewritten, because Morphe's modules share none of j-hc's
conventions:

| | revanced-magisk-module | Morphe |
| --- | --- | --- |
| How it identifies itself | `j-hc` in `module.prop` | `Morphe` in `module.prop`, dir suffixed `-morphe` |
| Patched APK | `/data/adb/rvhc/<id>.apk` | `<module dir>/<pkg>.apk` |
| Stock APK alongside | not kept | `<pkg>-stock.apk` (must never be picked) |
| App version | `config` file's `PKG_VER` | `module.prop`'s `version=` |
| Mount stages | `service.sh` | `post-fs-data.sh` **and** `service.sh` |

Upstream would find **nothing** on a Morphe setup: its `is_valid_rvmm()` requires
`j-hc` in `module.prop` and a `config` file, and its payload path is hardcoded to
`/data/adb/rvhc/`.

Two further fixes over upstream:

- **The NoMount binary is resolved once, in the parent shell.** Upstream used
  `alias nm=...`, which does not survive into the
  `collect_rvmm | while ...` subshell — so only the first app would have been
  injected.
- **`nm rule add`** rather than `nm add`, matching NoMount's documented CLI.

It also unmounts before injecting, in the root namespace *and* in each zygote
namespace. That is normally a no-op, since the Morphe module is already disabled
before its scripts can run — but it covers Morphe's own Mount/Remount button, and
the single boot after you re-enable the module by hand.

## Credits

- [rvmm-nomount](https://github.com/maxsteeel/rvmm-nomount) by
  [maxsteeel](https://github.com/maxsteeel) — this module is a fork of it, and
  the disable-then-reinject approach is entirely theirs.
- [NoMount](https://github.com/maxsteeel/nomount) — the VFS provider that makes
  the whole thing possible.
- [rvmm-zygisk-mount](https://github.com/j-hc/rvmm-zygisk-mount) — the Zygisk
  approach to the same problem, credited by upstream.
- [Morphe](https://github.com/MorpheApp) — patches the APK and writes the modules
  this injects.

## Licence

GPL-3.0, inherited from rvmm-nomount. See `LICENSE`.
