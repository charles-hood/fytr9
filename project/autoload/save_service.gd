## Versioned persistence for settings and local high scores (plan §10.2, §10.8).
##
## The full implementation — atomic writes, corruption recovery, schema
## migration, and the non-blocking "saving unavailable" state for Web — lands
## in Milestone 5. This stub fixes the schema constants so no other system
## invents its own paths or versions.
##
## v1 does NOT persist input bindings or a tutorial-seen flag (§10.2): there is
## no remap UI or interactive tutorial to produce that state.
extends Node

const SETTINGS_PATH := "user://settings.json"
const SCORES_PATH := "user://high_scores.json"
const SCHEMA_VERSION := 1
