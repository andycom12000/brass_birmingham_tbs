# Brass: Birmingham TTS Mod

Fully scripted Tabletop Simulator mod for Brass: Birmingham. Pure game logic lives in `src/` (no TTS dependencies); TTS bindings live in `tts/`; `scripts/inject_scripts.py` assembles everything into `brass_birmingham_scripted.json`.

## Build

After changing any Lua in `src/` or `tts/`, or `xml/UI.xml`, run `python scripts/inject_scripts.py` to regenerate and deploy the scripted save.

## Agent skills

### Issue tracker

Issues live in GitHub Issues (andycom12000/brass_birmingham_tbs), via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `CONTEXT.md` + `docs/adr/`. See `docs/agents/domain.md`.
