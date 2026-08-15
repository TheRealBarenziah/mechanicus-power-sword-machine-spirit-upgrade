#!/usr/bin/env bash
# Syntax-check the mod, then copy it into the Darktide mods folder if one exists here.
# On a machine without the game, this is just the syntax check. Non-standard install:
# set DARKTIDE_MODS to the game's mods directory.
set -euo pipefail

cd "$(dirname "$0")"

MOD=machine_spirit_upgrade
MODS_DIR="${DARKTIDE_MODS:-/mnt/c/Program Files (x86)/Steam/steamapps/common/Warhammer 40,000 DARKTIDE/mods}"

if command -v luajit > /dev/null 2>&1; then
	for f in "$MOD"/*.mod "$MOD"/scripts/mods/"$MOD"/*.lua; do
		luajit -bl "$f" > /dev/null
	done
	echo "syntax OK"
else
	echo "luajit not found - skipping syntax check"
fi

if [ ! -d "$MODS_DIR" ]; then
	echo "no Darktide mods folder at: $MODS_DIR"
	echo "dev machine? nothing to deploy - push and pull on the game machine instead"
	exit 0
fi

mkdir -p "$MODS_DIR/$MOD"
if command -v rsync > /dev/null 2>&1; then
	# --delete clears files removed from the repo; stale leftovers have bitten before
	rsync -a --delete "$MOD/" "$MODS_DIR/$MOD/"
else
	cp -r "$MOD/." "$MODS_DIR/$MOD/"
fi
echo "deployed to: $MODS_DIR/$MOD"
echo "in game: Ctrl+Shift+R reloads mods (needs developer_mode = true under mod_manager_settings in user_settings.config)"
