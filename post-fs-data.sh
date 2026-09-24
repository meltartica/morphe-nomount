#!/system/bin/sh
#
# post-fs-data.sh - disable each Morphe module's own mount stage.
#
# This runs before the mount stages, so writing `disable` here stops Morphe's
# post-fs-data.sh and service.sh from running on this boot. That is the whole
# mechanism: nothing is ever bind-mounted, so there is nothing to override.
#
# `disable` also makes NoMount's metamount.sh skip the module, since it tests for
# disable/remove/skip_mount before walking a module's partitions.
#
# It has to be re-asserted every boot rather than once at install, because
# re-patching an app in Morphe rewrites the module directory.

MODDIR=${0%/*}
. "$MODDIR/util.sh"

collect_morphe | while IFS= read -r MORPHE_PATH; do
    : >"$MORPHE_PATH/disable"
    set_morphe_desc "$MORPHE_PATH" "Keep disabled. Injected natively via NoMount."
done
