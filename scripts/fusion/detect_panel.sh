#!/usr/bin/env bash
# detect_panel.sh — figure out which panelist CLIs are installed and recommend a Fusion panel.
#
# Fusion fans a prompt out to a panel of models in parallel, then the session model (nominally Opus)
# judges. The Opus panelist + judge run via the Agent tool (in-process subagents, the session model) and
# need no CLI check. This script only probes the *external* panelist CLIs (GPT via codex, Gemini via agy /
# Antigravity) — each runs on its OWN configured default model — and prints the richest panel available.
#
# Output: human-readable lines + a final `SLUG=...` line the orchestrator can grep.

have() { command -v "$1" >/dev/null 2>&1; }

codex_ok=false; agy_ok=false
have codex && codex_ok=true
have agy   && agy_ok=true

echo "panelist availability (Opus is always a panelist + the judge, via Agent subagents):"
echo "  opus   : yes (Agent subagents — always available)"
printf "  gpt    : %s (codex CLI)\n" "$([ "$codex_ok" = true ] && echo yes || echo NO)"
printf "  gemini : %s (agy CLI)\n"   "$([ "$agy_ok"   = true ] && echo yes || echo NO)"
echo

if   $codex_ok && $agy_ok; then slug="opus-gpt-gemini"
elif $agy_ok;              then slug="opus-gemini"
elif $codex_ok;            then slug="opus-gpt"
else                            slug="opus-opus"
fi

echo "recommended panel: $slug"
echo "SLUG=$slug"
