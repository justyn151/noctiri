#!/bin/sh
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/noctiri/dwl"
mkdir -p "$state_dir"

# Save DWL's status pipe before starting any asynchronous jobs. POSIX shells
# otherwise attach /dev/null to a background command's standard input.
exec 3<&0

swaybg -c '#302c32' >"$state_dir/swaybg.log" 2>&1 &
background_pid=$!
somebar <&3 >"$state_dir/somebar.log" 2>&1 &
bar_pid=$!

# Give Somebar a moment to create its control FIFO. Someblocks also retries if
# the FIFO is not ready on its first update.
sleep 0.2
someblocks >"$state_dir/someblocks.log" 2>&1 &
blocks_pid=$!

cleanup() {
    kill "$blocks_pid" "$bar_pid" "$background_pid" 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM
wait "$bar_pid"
