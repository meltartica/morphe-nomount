#!/system/bin/sh

# Setup variables
NM_BIN="/data/adb/modules/nomount/bin/nm"
MORPHE_NOMOUNT_DIR="/data/adb/modules/morphe-nomount"

ui_print "- Checking NoMount dependencies..."

# Verify if the NoMount binary is installed in the expected path
if [ ! -f "$NM_BIN" ]; then
    ui_print "! Error: NoMount binary not found at $NM_BIN"
    ui_print "! Please install the NoMount module first."
    abort ""
fi

# Test if the NoMount kernel module is loaded and responding.
# `nm version` is the documented liveness test; its exit code is the answer.
if ! "$NM_BIN" version >/dev/null 2>&1; then
    ui_print "! Error: NoMount binary execution failed."
    ui_print "! Is the kernel module properly compiled and loaded?"
    abort ""
fi

ui_print "- NoMount is installed and active."

# Load utility functions
. "$MODPATH/util.sh"

# Abort if no Morphe root-mount module is found on the system
if [ -z "$(collect_morphe)" ]; then
    ui_print "! No Morphe module found."
    ui_print "  Patch an app in Morphe's root mount mode first,"
    ui_print "  then flash this module."
    abort ""
fi

# Set proper execution permissions for our background scripts
chmod +x "$MODPATH/service.sh"
chmod +x "$MODPATH/post-fs-data.sh"

# Create a convenient shortcut for Termux users to manually re-trigger injections
REAPPLY=/data/data/com.termux/files/usr/bin/
if [ -d "$REAPPLY" ]; then
    echo "su -c 'MODDIR=$MODPATH $MORPHE_NOMOUNT_DIR/service.sh'; echo Done.;" >"$REAPPLY/morphe-nomount"
    chmod 777 "$REAPPLY/morphe-nomount"
fi

ui_print "- Done"
ui_print "  forked from rvmm-nomount by maxsteeel (github.com/maxsteeel)"
