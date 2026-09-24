#!/system/bin/sh
#
# util.sh - shared helpers.
#
# Forked from rvmm-nomount (https://github.com/maxsteeel/rvmm-nomount, GPL-3.0).
#
# WHAT CHANGED FROM UPSTREAM, AND WHY
# -----------------------------------
# Upstream targets j-hc's revanced-magisk-module, which identifies itself with
# "j-hc" in module.prop, keeps a `config` file carrying PKG_NAME/PKG_VER, and
# stores the patched APK at /data/adb/rvhc/<id>.apk.
#
# Morphe's modules (written by MorpheApp/morphe-manager) do none of those:
#
#   module dir    /data/adb/modules/<pkg>-morphe/
#   payload       <module dir>/<pkg>.apk          (NOT /data/adb/rvhc/)
#   stock copy    <module dir>/<pkg>-stock.apk    (must never be picked)
#   version       module.prop's `version=` field  (no config file exists)
#   target hint   stock-paths.txt
#   mounts        BOTH post-fs-data.sh (stock APK) and service.sh (patched APK)
#
# So is_valid_rvmm()/collect_rvmm() are reimplemented, not merely renamed.
#
# NOTE: POSIX sh has no `local`, so every helper here deliberately prefixes its
# variables to avoid clobbering a caller's. Keep those prefixes.

# Package name a Morphe module patches, e.g. com.google.android.youtube.
#
# From the module id, which is always <pkg>-morphe. Falls back to the payload's
# own filename, which is also <pkg>.apk.
morphe_pkg() {
    _mp_id="$(sed -n 's/^id=//p' "$1/module.prop" 2>/dev/null | head -1 | tr -d ' \r')"
    case "$_mp_id" in
        *-morphe)
            printf '%s\n' "${_mp_id%-morphe}"
            return 0
            ;;
    esac
    _mp_apk="$(morphe_apk "$1")" || return 1
    _mp_base="${_mp_apk##*/}"
    printf '%s\n' "${_mp_base%.apk}"
}

# Patched APK inside <module dir>.
#
# <pkg>-stock.apk sits next to it and must never be picked: serving the stock
# copy would "work" while silently reverting every patch.
morphe_apk() {
    _ma_dir="$1"
    for _ma_c in "$_ma_dir"/*.apk; do
        [ -f "$_ma_c" ] || continue
        case "${_ma_c##*/}" in
            *-stock.apk) continue ;;
        esac
        printf '%s\n' "$_ma_c"
        return 0
    done
    return 1
}

# The app version the module says its APK was built for, e.g. 21.16.256.
morphe_ver() {
    sed -n 's/^version=//p' "$1/module.prop" 2>/dev/null | head -1 | tr -d ' \r'
}

is_valid_morphe() {
    [ -d "$1" ] || return 1
    [ -f "$1/module.prop" ] || return 1
    grep -Fq "Morphe" "$1/module.prop" || return 1
    morphe_apk "$1" >/dev/null 2>&1 || return 1
    return 0
}

collect_morphe() {
    for _cm_dir in /data/adb/modules/*-morphe; do
        [ -d "$_cm_dir" ] || continue
        is_valid_morphe "$_cm_dir" || continue
        [ -f "$_cm_dir/remove" ] && continue
        printf '%s\n' "$_cm_dir"
    done
}

# Report status by rewriting the target module's description, as upstream does.
# The original module.prop is kept beside it as `err` the first time.
# Only the description line is touched, so the `version=` field this module reads
# is never disturbed.
set_morphe_desc() {
    _sd_path="$1"
    _sd_msg="$2"
    [ -f "$_sd_path/module.prop" ] || return 0
    if [ ! -f "$_sd_path/err" ]; then
        cp -f "$_sd_path/module.prop" "$_sd_path/err"
    fi
    sed -i "s|^des.*|description=⚠️ ${_sd_msg}|g" "$_sd_path/module.prop"
}

# Remove a bind mount sitting on <target>.
#
# Morphe mounts TWICE: its post-fs-data.sh binds the STOCK apk over the target to
# establish a known baseline, then its service.sh replaces that with the patched
# APK - in the root namespace AND inside each zygote namespace, via
# `nsenter -t <zygote pid> -m mount -o bind ...`.
#
# That second one is the one that matters: an app is forked from zygote and
# inherits zygote's namespace, so undoing only the root-namespace mount leaves
# the effective mount in place. And a mount is followed AFTER dentry resolution,
# so it wins over an `nm rule` on the same path and reappears in /proc/mounts.
#
# Normally there is nothing to undo here, because post-fs-data.sh disables the
# module before any of its scripts run. This covers the two cases where that is
# not enough: Morphe's own Mount/Remount button, and the single boot after you
# re-enable the module by hand (KernelSU builds its module list before our
# disable file lands).
unmount_target() {
    _ut_t="$1"
    [ -n "$_ut_t" ] || return 0

    if grep -qF "$_ut_t" /proc/self/mounts 2>/dev/null; then
        umount -l "$_ut_t" 2>/dev/null && echo "  unmounted root-namespace mount on $_ut_t"
    fi

    for _ut_z in $(pidof zygote64) $(pidof zygote); do
        if nsenter -t "$_ut_z" -m umount -l "$_ut_t" 2>/dev/null; then
            echo "  unmounted $_ut_t in zygote namespace $_ut_z"
        fi
    done
}
