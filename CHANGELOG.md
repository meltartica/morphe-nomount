# Changelog

## v1.0.0

First release. A fork of [rvmm-nomount](https://github.com/maxsteeel/rvmm-nomount)
retargeted from `revanced-magisk-module` to Morphe.

- **Morphe discovery.** Upstream keys on `j-hc` in `module.prop` plus a `config`
  file carrying `PKG_NAME`/`PKG_VER`, and hardcodes the payload at
  `/data/adb/rvhc/<id>.apk`. Morphe writes `/data/adb/modules/<pkg>-morphe/`
  with the patched APK as `<pkg>.apk` beside a `<pkg>-stock.apk`, and records the
  app version in `module.prop`'s `version=`. The stock copy is deliberately never
  picked — serving it would "work" while silently reverting every patch.
- **Unmount before injecting**, in the root namespace and in each zygote
  namespace. Morphe mounts twice (`post-fs-data.sh` for the stock baseline,
  `service.sh` for the patched APK), and the zygote one is the one an app
  actually inherits.
- **`nm rule add`** rather than `nm add`, matching NoMount's documented CLI.

Fixes over upstream:

- The NoMount binary was resolved with `alias nm=...` in the parent shell, which
  does not survive into the `collect_rvmm | while ...` subshell — so only the
  first app could inject. It is now resolved once and called by absolute path.
- The installer wrapper sat at `META-INF/google/android/`, which Magisk does not
  read. Moved to `META-INF/com/google/android/`.
- `.gitattributes` pins `eol=lf`. Under `core.autocrlf=true` the Windows worktree
  checked out CRLF, and a ZIP built there would ship a module whose shebangs are
  `#!/system/bin/sh\r` — which does not execute.
