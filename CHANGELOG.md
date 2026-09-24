# Changelog

## v1.0.0

First release.

[rvmm-nomount](https://github.com/maxsteeel/rvmm-nomount) retargeted from
[revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module) to
Morphe. The patched APK is injected through NoMount rather than bind-mounted, so
nothing appears in `/proc/mounts`.

### Morphe support

- Recognises `/data/adb/modules/<pkg>-morphe/`, taking the patched APK from
  `<pkg>.apk` and the expected app version from `module.prop`. The
  `<pkg>-stock.apk` beside it is never chosen: serving the stock copy would look
  like success while reverting every patch.
- Unmounts before injecting, in the root namespace and in each zygote namespace.
  Morphe mounts twice, and the zygote mount is the one an app inherits.
- Injects with `nm rule add`, NoMount's documented form.

### Fixed from upstream

- `alias nm=...` did not survive into the `collect_rvmm | while ...` subshell, so
  only the first app could ever be injected.
- The installer wrapper sat at `META-INF/google/android/`, a path Magisk does not
  read.
- `.gitattributes` pins `eol=lf`; a ZIP built from a CRLF worktree would ship
  shebangs that cannot execute.
