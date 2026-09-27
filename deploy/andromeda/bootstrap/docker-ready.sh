#!/bin/sh
set -eu

pinned=ghcr.io/ayaka-notes/texlive-full@sha256:78f172648c2740bf9fe838863c2123bb043e4283cc3ec424e77733054dca47aa
selected=ghcr.io/ayaka-notes/texlive-full:2026.1

docker info >/dev/null 2>&1
pinned_id=$(docker image inspect --format '{{.Id}}' "$pinned" 2>/dev/null || true)
if [ -z "$pinned_id" ]; then
  docker pull "$pinned"
  pinned_id=$(docker image inspect --format '{{.Id}}' "$pinned")
fi
selected_id=$(docker image inspect --format '{{.Id}}' "$selected" 2>/dev/null || true)
if [ "$pinned_id" != "$selected_id" ]; then
  docker tag "$pinned" "$selected"
fi
