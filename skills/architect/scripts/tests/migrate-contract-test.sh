#!/usr/bin/env bash
# migrate-contract-test.sh — keep the deliberately small spike migration boundary explicit.
set -u
DIR="$(CDPATH='' cd "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd "$DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$DIR/lib.sh"

text="$(cat "$SKILL/verbs/migrate.md")"
expect_match "current spike schema is owned" 'architect/spike@1' "$text"
expect_match "current spike selection is a no-op" 'selected valid current spike is a reported no-op' "$text"
expect_match "unknown schemas refuse" 'any other declared schema refuses' "$text"
expect_match "schema-less spikes refuse" 'schema-less would-be spike refuses' "$text"
expect_match "no legacy spike upgrade exists" 'There is no schema-less spike upgrade' "$text"
expect_match "workspace drafts never migrate" 'Workspace drafts are never migration sources or destinations' "$text"

finish
