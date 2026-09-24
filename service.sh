#!/system/bin/sh
#
# service.sh - re-inject each Morphe module's patched APK through NoMount.
#
# Runs at late_start, after boot_completed, before the launcher is up. That
# ordering matters: the rule must not appear AFTER the app has resolved its APK
# and had resource state built for it, or Resources construction returns null and
# the app dies in ActivityThread.handleBindApplication with
#   NullPointerException: Resources.getConfiguration() on a null object reference
#
# NoMount rules are RUNTIME ONLY and GLOBAL. There is no per-uid rule form, and
# `nm uid add <uid>` is the opposite operation (it EXCLUDES that uid from VFS).

until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 1; done
until [ -d "/sdcard/Android" ]; do sleep 1; done
sleep 5

MODDIR=${0%/*}
. "$MODDIR/util.sh"

# Resolve the binary once, in the parent shell. Upstream relied on
# `alias nm=...`, which does not survive into the `collect_morphe | while`
# subshell below - so the first app would inject and the rest would silently not.
NM_BIN="$(command -v nm 2>/dev/null)"
if [ -z "$NM_BIN" ] || [ ! -x "$NM_BIN" ]; then
    NM_BIN=/data/adb/modules/nomount/bin/nm
fi

if [ ! -x "$NM_BIN" ]; then
    exit 0
fi

collect_morphe | while IFS= read -r MORPHE_PATH; do
    PKG="$(morphe_pkg "$MORPHE_PATH")"
    if [ -z "$PKG" ]; then
        set_morphe_desc "$MORPHE_PATH" "Needs reflash: cannot determine package name"
        continue
    fi

    RVPATH="$(morphe_apk "$MORPHE_PATH")"
    if [ -z "$RVPATH" ] || [ ! -f "$RVPATH" ]; then
        set_morphe_desc "$MORPHE_PATH" "Needs reflash: patched APK missing"
        continue
    fi

    BASEPATH="$(pm path "$PKG" 2>&1 </dev/null)"
    if [ $? != 0 ] || [ -z "$BASEPATH" ]; then
        set_morphe_desc "$MORPHE_PATH" "Needs reflash: app not installed"
        continue
    fi

    BASEPATH="${BASEPATH##*:}"
    BASEDIR="${BASEPATH%/*}"

    if [ ! -d "$BASEDIR/lib" ]; then
        set_morphe_desc "$MORPHE_PATH" "Injection failed: corrupted base app"
        continue
    fi

    # The stock app and the patched APK must be the same release, or the app
    # crashes on launch. The module records what its APK was built for in
    # `version=`; Morphe's own service.sh refuses to mount on the same mismatch.
    WANT="$(morphe_ver "$MORPHE_PATH")"
    HAVE="$(dumpsys package "$PKG" 2>&1 | grep -m1 versionName)"
    HAVE="${HAVE#*=}"
    if [ -n "$WANT" ] && [ -n "$HAVE" ] && [ "$HAVE" != "$WANT" ]; then
        set_morphe_desc "$MORPHE_PATH" "Needs reflash: version mismatch (installed:${HAVE}, module:${WANT})"
        continue
    fi

    if ! chcon u:object_r:apk_data_file:s0 "$RVPATH" 2>/dev/null; then
        set_morphe_desc "$MORPHE_PATH" "Needs reflash: cannot label $RVPATH"
        continue
    fi

    unmount_target "$BASEPATH"
    am force-stop "$PKG"

    if "$NM_BIN" rule add "$BASEPATH" "$RVPATH"; then
        set_morphe_desc "$MORPHE_PATH" "Keep disabled. Injected natively via NoMount."
    else
        set_morphe_desc "$MORPHE_PATH" "Injection failed: $NM_BIN rule add rejected"
    fi
done
