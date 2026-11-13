#!/bin/bash
# rartool.sh — backend for the "Extract RAR" and "Compress to RAR" Quick Actions.
#
#   rartool.sh extract  <file.rar> [more.rar ...]
#   rartool.sh compress <file-or-folder> [more ...]
#
# Runs from Finder with no terminal and a minimal PATH, so it never prompts on
# stdin: passwords are asked for with a macOS dialog and results are reported
# with notifications. Details go to ~/Library/Logs/RarQuickActions.log.

set -u

TOOL_DIR="$(cd "$(dirname "$0")" && pwd)"
RAR="$TOOL_DIR/bin/rar"
UNRAR="$TOOL_DIR/bin/unrar"
LOG="$HOME/Library/Logs/RarQuickActions.log"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

mkdir -p "$(dirname "$LOG")"

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG"; }

# AppleScript string literal escaping (backslash and double quote).
as_quote() { local s=${1//\\/\\\\}; s=${s//\"/\\\"}; printf '"%s"' "$s"; }

notify() { # title, message
  osascript -e "display notification $(as_quote "$2") with title $(as_quote "$1")" >/dev/null 2>&1 || true
}

alert() { # title, message
  osascript -e "display alert $(as_quote "$1") message $(as_quote "$2") as critical" >/dev/null 2>&1 || true
}

# Ask for a password with a hidden-answer dialog. Prints it; returns 1 on Cancel.
ask_password() { # archive name
  osascript \
    -e "set r to display dialog $(as_quote "\"$1\" is password protected. Enter the password:") default answer \"\" with hidden answer with title \"Extract RAR\" with icon caution buttons {\"Cancel\", \"Extract\"} default button \"Extract\"" \
    -e 'text returned of r' 2>/dev/null
}

# Return a path that does not exist yet: "name.ext", then "name 2.ext", ...
unique_path() { # dir, stem, ext (ext may be empty or ".rar")
  local dir=$1 stem=$2 ext=$3 n=2 p
  p="$dir/$stem$ext"
  while [ -e "$p" ] || [ -L "$p" ]; do
    p="$dir/$stem $n$ext"
    n=$((n + 1))
  done
  printf '%s' "$p"
}

# ---------------------------------------------------------------- extract ---

# For multi-volume sets ("x.part2.rar") return the first volume, so a set is
# extracted once no matter which volume (or how many) the user selected.
first_volume() {
  local f=$1 base dir num first
  dir=$(dirname "$f"); base=$(basename "$f")
  if [[ "$base" =~ ^(.*)\.part([0-9]+)\.rar$ ]]; then
    num=${BASH_REMATCH[2]}
    # Same zero-padding width as the selected volume: part01, part001, ...
    first=$(printf "%s.part%0${#num}d.rar" "${BASH_REMATCH[1]}" 1)
    [ -e "$dir/$first" ] && { printf '%s' "$dir/$first"; return; }
  fi
  printf '%s' "$f"
}

# Name for the output folder: strip ".rar" and any ".partN".
archive_stem() {
  local base
  base=$(basename "$1")
  base=${base%.[rR][aA][rR]}
  if [[ "$base" =~ ^(.*)\.part[0-9]+$ ]]; then base=${BASH_REMATCH[1]}; fi
  printf '%s' "$base"
}

# Run the extractor into an empty directory. Returns its exit status.
run_extract() { # archive, destdir, password-or-empty
  local archive=$1 dest=$2 pw=$3
  if [ -x "$UNRAR" ]; then
    if [ -n "$pw" ]; then
      "$UNRAR" x -y -o- -idq "-p$pw" -- "$archive" "$dest/" >>"$LOG" 2>&1
    else
      "$UNRAR" x -y -o- -idq -p- -- "$archive" "$dest/" >>"$LOG" 2>&1
    fi
  elif command -v unar >/dev/null 2>&1; then
    # The Unarchiver's CLI (brew install unar) as a fallback extractor.
    if [ -n "$pw" ]; then
      unar -q -f -D -o "$dest" -p "$pw" -- "$archive" >>"$LOG" 2>&1
    else
      unar -q -f -D -o "$dest" -- "$archive" </dev/null >>"$LOG" 2>&1
    fi
  else
    log "no extractor found ($UNRAR missing, unar not installed)"
    return 127
  fi
}

# True when the archive needs a password (encrypted names or file data).
needs_password() {
  local archive=$1
  if [ -x "$UNRAR" ]; then
    # "lt" fails outright if the file names are encrypted, and prints
    # "*" before encrypted entries otherwise.
    local out
    out=$("$UNRAR" lt -p- -- "$archive" 2>&1) || return 0
    printf '%s\n' "$out" | grep -qE '^[[:space:]]*Name: ' || return 0
    printf '%s\n' "$out" | grep -qE '^[[:space:]]*Flags: .*encrypted' && return 0
    return 1
  elif command -v lsar >/dev/null 2>&1; then
    lsar -t -- "$archive" >/dev/null 2>&1 && return 1
    lsar -- "$archive" 2>&1 | grep -qi 'encrypt' && return 0
  fi
  return 1
}

extract_one() {
  local archive=$1 dir stem tmp pw="" status entries count top target name
  dir=$(cd "$(dirname "$archive")" && pwd)
  archive="$dir/$(basename "$archive")"
  name=$(basename "$archive")
  stem=$(archive_stem "$archive")

  if [ ! -w "$dir" ]; then
    alert "Extract RAR" "Can't write to the folder containing \"$name\"."
    return 1
  fi

  if needs_password "$archive"; then
    pw=$(ask_password "$name") || { log "cancelled: $archive"; return 1; }
  fi

  # Extract into a hidden temp folder next to the archive, then move into place.
  tmp=$(mktemp -d "$dir/.rarqa.XXXXXX") || { alert "Extract RAR" "Couldn't create a temporary folder in \"$dir\"."; return 1; }
  # mktemp makes it 0700; if it becomes the output folder, give it normal permissions.
  chmod "$(printf '%o' $(( 0777 & ~$(umask) )))" "$tmp"
  log "extract: $archive -> $tmp"

  while :; do
    run_extract "$archive" "$tmp" "$pw"
    status=$?
    # 11 = wrong password (RAR 5+), 3 = CRC error (older archives, wrong password)
    if [ -n "$pw" ] && { [ $status -eq 11 ] || [ $status -eq 3 ]; }; then
      rm -rf "$tmp"; mkdir -p "$tmp"
      pw=$(ask_password "$name (wrong password, try again)") || { rm -rf "$tmp"; log "cancelled: $archive"; return 1; }
      continue
    fi
    break
  done

  # 0 = ok, 1 = non-fatal warning (e.g. a skipped file). Anything else failed.
  if [ $status -gt 1 ]; then
    rm -rf "$tmp"
    log "extract failed ($status): $archive"
    alert "Extract RAR" "Couldn't extract \"$name\" (error $status). See ~/Library/Logs/RarQuickActions.log for details."
    return 1
  fi

  # One top-level item → put it next to the archive. Several → wrap them in a
  # folder named after the archive (same as Archive Utility / The Unarchiver).
  entries=$(cd "$tmp" && ls -A)
  count=$(printf '%s' "$entries" | grep -c '^' || true)
  if [ "$count" -eq 1 ]; then
    top=$entries
    case "$top" in
      *.*) target=$(unique_path "$dir" "${top%.*}" ".${top##*.}") ;;
      *)   target=$(unique_path "$dir" "$top" "") ;;
    esac
    [ -d "$tmp/$top" ] && target=$(unique_path "$dir" "$top" "")
    mv "$tmp/$top" "$target" && rmdir "$tmp"
  else
    target=$(unique_path "$dir" "$stem" "")
    mv "$tmp" "$target"
  fi
  log "extracted: $archive -> $target (status $status)"
  printf '%s\n' "$target"
}

cmd_extract() {
  local f first seen="" ok=0 fail=0 last=""
  for f in "$@"; do
    [ -f "$f" ] || continue
    case "$f" in *.[rR][aA][rR]) ;; *) continue ;; esac
    first=$(first_volume "$f")
    # Skip volumes of a set that was already handled in this run.
    case "$seen" in *"|$first|"*) continue ;; esac
    seen="$seen|$first|"
    if last=$(extract_one "$first"); then ok=$((ok + 1)); else fail=$((fail + 1)); fi
  done

  if [ $ok -eq 1 ] && [ $fail -eq 0 ]; then
    notify "Extract RAR" "Extracted to \"$(basename "$last")\""
  elif [ $ok -gt 1 ]; then
    notify "Extract RAR" "Extracted $ok archives$([ $fail -gt 0 ] && echo ", $fail failed")"
  elif [ $ok -eq 0 ] && [ $fail -eq 0 ]; then
    notify "Extract RAR" "No .rar files were selected"
  fi
  [ $fail -eq 0 ]
}

# --------------------------------------------------------------- compress ---

cmd_compress() {
  local dir out stem item names=() status first

  if [ ! -x "$RAR" ]; then
    alert "Compress to RAR" "The rar tool isn't installed. Run install.sh from the RarQuickActions repo again."
    return 1
  fi
  [ $# -gt 0 ] || return 0

  first=$1
  dir=$(cd "$(dirname "$first")" && pwd)
  for item in "$@"; do
    [ -e "$item" ] || continue
    if [ "$(cd "$(dirname "$item")" && pwd)" != "$dir" ]; then
      alert "Compress to RAR" "All selected items must be in the same folder."
      return 1
    fi
    names+=("$(basename "$item")")
  done
  [ ${#names[@]} -gt 0 ] || return 0

  if [ ! -w "$dir" ]; then
    alert "Compress to RAR" "Can't write to \"$dir\"."
    return 1
  fi

  if [ ${#names[@]} -eq 1 ]; then
    stem=${names[0]}
    # "report.pdf" -> "report.rar"; folders and dotfiles keep their full name.
    if [ -f "$dir/$stem" ] && [[ "$stem" == ?*.* ]]; then stem=${stem%.*}; fi
  else
    stem="Archive"
  fi
  out=$(unique_path "$dir" "$stem" ".rar")

  notify "Compress to RAR" "Compressing to \"$(basename "$out")\"…"
  log "compress: ${names[*]} in $dir -> $out"

  # Relative names (we cd into the folder) so no absolute paths are stored.
  # -ma5 RAR5 format, -m3 normal compression, -r recurse, -ol keep symlinks,
  # -x skip Finder metadata, -idq quiet, -y never prompt.
  (cd "$dir" && "$RAR" a -ma5 -m3 -r -ol -idq -y \
      -x'*.DS_Store' -x'*/.DS_Store' -x'._*' -x'*/._*' \
      -- "$out" "${names[@]}") >>"$LOG" 2>&1
  status=$?

  if [ $status -gt 1 ]; then
    rm -f "$out"
    log "compress failed ($status): $out"
    alert "Compress to RAR" "Couldn't create \"$(basename "$out")\" (error $status). See ~/Library/Logs/RarQuickActions.log for details."
    return 1
  fi
  log "compressed: $out (status $status)"
  notify "Compress to RAR" "Created \"$(basename "$out")\""
  printf '%s\n' "$out"
}

# ------------------------------------------------------------------- main ---

case "${1:-}" in
  extract)  shift; cmd_extract "$@" ;;
  compress) shift; cmd_compress "$@" ;;
  *) echo "usage: $(basename "$0") extract|compress <paths...>" >&2; exit 2 ;;
esac
