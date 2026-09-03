# Iam - hero

Private Flutter storybook app. See `docs/CODEBASE.md` for the file-by-file
codebase map and `docs/LOCAL_AI_INTEGRATION.md` for the local AI boundary.

## Agent skills

### Issue tracker

Issues live as GitHub issues in `Youssefhikal93/Miko-hero`, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, used verbatim as label strings. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Branching

`dev` is the trunk. **Never push, commit, or merge to `main`.** A push to
`main` triggers the production Vercel deploy that the family reads on. Branch
from `dev`, commit to `dev`, push `dev`. Merging `dev` into `main` is the
owner's decision, tracked as its own ticket.

## Working tickets

The September 2026 effort (illustration quality, story quality, remote family
access, and the phone redesign) shipped; its map was **issue #3** and its
decisions are recorded there. New work starts as a new issue.

Every ticket is labelled with the machine it runs on:

- `machine:ai-pc` — needs Ollama, ComfyUI, and the bridge. The models live
  only on the AI PC, so only the AI PC can do these.
- `machine:dev-pc` — repo, code, and gates. No models involved.
- `machine:owner` — a browser or a conversation; neither machine.

**Do not attempt a ticket labelled for a machine you are not on.** Simulating
a model download, a GPU render, or a Tailscale install in code is worse than
leaving the ticket open, and it will read as done when it is not.

To work a ticket: assign it to yourself first — that assignment *is* the
claim, and it stops a second session duplicating you. Then follow the work
order the ticket points at, comment the outcome on the ticket, and close it.

The three completed work orders stay as the record of what runs on the AI PC:
`docs/ILLUSTRATION_QUALITY_UPGRADE.md`, `docs/STORY_QUALITY_UPGRADE.md`,
`docs/REMOTE_FAMILY_ACCESS.md`. Keep `docs/CODEBASE.md` current whenever a
file is added, removed, or changes responsibility.

## AI PC resources

Ollama and ComfyUI share one 4 GB GPU with everything else on the PC. Generate
a real story or picture only when a change needs it, one run per change, and
unload the model (`ollama stop <model>`) when you are done.

## Gate order

Run `dart pub get` inside `bridge/` **first**, or the root `flutter analyze`
reports around 1400 phantom errors. Then bridge `dart analyze` and
`dart test`; then root `dart format`, `flutter analyze`, `flutter test`; then
`flutter build web --release` for anything touching the app.
