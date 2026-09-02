# Wanderer's Village — working agreement

Godot 4 2D JRPG. **ASCII/text-only visual style is a deliberate, permanent
design choice** — no sprites, no tilesets, not now, not later, unless the
user explicitly changes this. **Target platform is Windows, windowed**
(not fullscreen). Full architecture notes and the current checklist live
in `PROGRESS.md` — always read that first, it's the source of truth for
what's done and what's next.

## Autonomy

Make judgment calls yourself; don't ask the user. Only stop and ask when:
- something is genuinely ambiguous and you have no reasonable default,
- an action is risky/hard to reverse and wasn't already authorized,
- you need a credential or account the user hasn't given you (e.g. a
  GitHub token) — and before offering a choice, first confirm every
  option you're about to present is actually feasible (check size
  limits, required auth, etc.) rather than handing over an option that
  turns out to be impossible.

Whatever you decide, write the reasoning into PROGRESS.md's
"Notes / decisions" section so the next session (or the next hourly run)
has full context without needing to ask again.

## Verification before every commit

Both must exit 0 with no `SCRIPT ERROR` / `push_error` output:

```
~/.local/bin/godot4 --headless --path . --import
~/.local/bin/godot4 --headless --path . --quit-after 2
```

That 2-frame smoke test only catches import/parse errors and `_ready()`
crashes — it does NOT exercise anything that only runs later at runtime
(a Tween, a scene transition, a dialogue flow, a battle loop). For that
kind of change, add a temporary env-var-gated test hook directly in the
relevant script (e.g. `if OS.get_environment("GODOT_TEST_X") == "1":
...`), run it headlessly with that env var set and a generous
`--quit-after` frame count, confirm no errors, then **remove the hook
before committing**. Don't skip this just because the smoke test passed.

## Branching

- Unattended work triggered by the hourly `CronCreate` job → commit and
  push to `auto-progress`, never `main`.
- Live interactive work with the user present → commit directly to
  `main`.
- Never force-push, `reset --hard`, or rewrite history on either branch.

## The hourly CronCreate job

It only lives in session memory — it disappears when the session ends
and is NOT restored automatically. If `CronList` shows it's gone,
recreate a recurring hourly job whose prompt tells it to: checkout
`auto-progress`, pull, merge `main`, read `PROGRESS.md`, do one
unchecked item, verify, update `PROGRESS.md`, commit, push to
`auto-progress` — never ask the user questions, never touch `main`,
never force anything. This also depends on `autoContinueAtUsageLimit:
true` being set in the user's global `~/.claude/settings.json` so a
run that hits a usage limit waits and resumes instead of just failing.

## Permissions

`.claude/settings.json` in this repo is a deliberately narrow allowlist
(common git operations, `godot4`, file ops scoped to this directory) —
not a blanket bypass. If something legitimate keeps needing manual
approval, add it to the allowlist specifically; don't switch to a
bypass-everything mode.

## Godot toolchain (local machine, not version-controlled)

- Editor/CLI binary: `~/.local/bin/godot4` (Godot 4.7.2 headless-capable
  Linux build).
- Windows export templates: `~/.local/share/godot/export_templates/4.7.2.stable/`
  — only the `windows_*` files were extracted from the official
  `Godot_v4.7.2-stable_export_templates.tpz` release asset (android/ios/
  macos/web were skipped to save space). Re-extract from that same
  release asset if this directory is ever missing.

## Windows build

`export_presets.cfg` (committed) defines a "Windows Desktop" x86_64
preset. Build with:

```
~/.local/bin/godot4 --headless --path . --export-release "Windows Desktop" build/windows/WanderersVillage.exe
```

`build/` is gitignored — don't commit the binary. It's also irrelevant
whether you'd want to: at ~100MB it exceeds GitHub's 100MB hard push
limit anyway, so it has to reach the user some other way (they build it
locally, or a future release pipeline handles it — not solved yet).
