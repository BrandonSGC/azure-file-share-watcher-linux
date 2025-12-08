#!/usr/bin/env bash
# /usr/local/bin/az-files-watcher.sh
# Watch an Azure File Share mount and append create/delete/move events to a log file inside the share.

MOUNT_DIR="/media/az-linux-files" 
LOGFILE="$MOUNT_DIR/changes.log"
TMPLOG="/var/log/az-files-watcher-local.log" # local fallback log (optional)

# Ensure mount directory exists
if [ ! -d "$MOUNT_DIR" ]; then
  echo "$(date -u +"%Y-%m-%d %H:%M:%S UTC") - ERROR - Mount directory $MOUNT_DIR does not exist" >> "$TMPLOG"
  exit 1
fi

# Ensure logfile exists and is writable
touch "$LOGFILE" 2>/dev/null || {
  echo "$(date -u +"%Y-%m-%d %H:%M:%S UTC") - ERROR - Cannot write to $LOGFILE" >> "$TMPLOG"
  exit 1
}

# The inotifywait command: recursively watch for creates, deletes and moves
# -m  => monitor continuously
# -r  => recursive
# -e  => events to watch
# --format => control output format
inotifywait -m -r -e create -e moved_to -e delete -e moved_from --format '%w|%e|%f|%T' --timefmt '%Y-%m-%d %H:%M:%S' "$MOUNT_DIR" \
| while IFS='|' read -r _path event filename evtime; do
  # Normalize fields and create a log line
  # Example log line:
  # 2025-12-08 14:00:00 UTC | CREATE | /media/az-linux-files/subdir | myfile.txt

  # Compose full path
  fullpath="${_path}${filename}"

  # Convert inotify event tokens into a single human event
  # inotify can return multiple tokens like "MOVED_TO,ISDIR", so take first token
  # and map it to friendly name
  case "$event" in
    CREATE*|MOVED_TO*)
      action="CREATE"
      ;;
    DELETE*|MOVED_FROM*)
      action="DELETE"
      ;;
    *)
      action="$event"
      ;;
  esac

  # Timestamp in UTC for consistency
  timestamp="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"

  # Write one line to the Azure file share log (append)
  echo "$timestamp | $action | $fullpath" >> "$LOGFILE" 2>>"$TMPLOG"

  # Also write a local copy for debugging (optional)
  echo "$timestamp | $action | $fullpath" >> "$TMPLOG"
done
