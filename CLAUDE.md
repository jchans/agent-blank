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
- This repo can have more than one Claude session working on it at the
  same time (interactive, the hourly cron job, others). Before starting
  a nontrivial diagnosis, `git fetch origin main` and check recent
  commits / `git worktree list` — another session may already be mid-
  investigation or have just pushed a fix for the same issue. Fetch
  again immediately before pushing, to catch a race instead of creating
  a duplicate/conflicting commit.

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

### Windows filesystem boundary (WSL ↔ `/mnt/c`)

This dev environment is WSL2, sharing a machine with the user's Windows
install, reachable at `/mnt/c/...`. **Reading** from there for analysis
(Windows Error Reporting, Event Log, crash dumps, etc.) is fine any
time, no need to ask. **Writing there — creating or modifying anything
under `/mnt/c`, including dropping build artifacts on the user's
Desktop — needs the user's real-time, in-the-moment consent, every
single time.** Doing it once in a live interactive session is not
standing permission for next time. Never write to the Windows side
during unattended/autonomous work (the hourly cron job) — there is no
one there to give that consent.

## Godot toolchain (local machine, not version-controlled)

- Editor/CLI binary: `~/.local/bin/godot4` (Godot 4.7.2 headless-capable
  Linux build).
- Windows export templates: `~/.local/share/godot/export_templates/4.7.2.stable/`
  — only the `windows_*` files were extracted from the official
  `Godot_v4.7.2-stable_export_templates.tpz` release asset (android/ios/
  macos/web were skipped to save space). Re-extract from that same
  release asset if this directory is ever missing.
- **Godot silently ignores unrecognized property names** in
  `project.godot` / `export_presets.cfg` — no warning at import or
  export time, the setting just does nothing (this cost a full cycle
  once: `debug/export_console_wizard` isn't a real key, the real one is
  `debug/export_console_wrapper`). Before setting any property you're
  not 100% sure of the exact name for, confirm it actually exists:
  `strings ~/.local/bin/godot4 | grep -i <keyword>`. Don't rely on
  memory or on docs that might be for a different Godot version.
- **A mingw-w64 cross-compiler and the matching Godot source are already
  set up for building custom export templates** (e.g. a smaller
  template with unused modules disabled — see PROGRESS.md's 2026-09-03
  "Custom minimal Windows export template" entry for the full recipe
  and reasoning): the toolchain lives at `~/.local/mingw64` (extracted
  from `.deb`s via `apt-get download` + `dpkg -x`, no root needed — see
  the sudo note below), and the Godot 4.7.2 source is checked out at
  `~/godot-src/godot`. Reuse these rather than redoing the setup; a
  rebuild is just `cd ~/godot-src/godot && export PATH="$HOME/.local/mingw64/usr/bin:$PATH" && scons ...`.
  The currently-shipped default template is still the stock official
  one — `export_presets.cfg`'s `custom_template/release` is
  deliberately left empty; wiring in the smaller custom template as the
  standing default is a decision for the user to make, not to bake in
  silently.

## Windows build

`export_presets.cfg` (committed) defines a "Windows Desktop" x86_64
preset. Build with:

```
~/.local/bin/godot4 --headless --path . --export-release "Windows Desktop" build/windows/WanderersVillage.exe
```

**Always call `change_scene_to_file` via `.bind(path).call_deferred()`,
never directly** (see `title_screen.gd`/`dialogue_manager.gd`/`battle.gd`
for the pattern) — this is load-bearing, not stylistic. The official
Godot 4.7.2 release export template has a reproducible engine-level
crash (`STATUS_ACCESS_VIOLATION`, identical faulting offset regardless of
renderer backend) triggered by calling `change_scene_to_file` directly
from an input/signal callback during this project's scene transitions —
see PROGRESS.md's 2026-09-03 entries for the full investigation. Calling
it deferred instead (so the scene swap happens strictly after the
current input/signal-processing phase, not racing whatever's still
pending in the engine's internal call queue) fixed it — confirmed on the
user's real Windows/NVIDIA hardware with a plain `--export-release`
build. Any new scene-change call site must follow the same pattern.

`build/` is gitignored — don't commit the binary. It's also irrelevant
whether you'd want to: at ~100MB it exceeds GitHub's 100MB hard push
limit anyway, so it has to reach the user some other way (they build it
locally, or a future release pipeline handles it — not solved yet).

## Debugging Windows-only crashes

When a bug only reproduces on the user's real Windows machine (not
headless, not in the editor), in this order:

1. **Get the OS's own crash diagnostics before theorizing about
   drivers/renderers/GPU compatibility.** Read what Windows actually
   recorded rather than guessing. If this session shares the machine
   with the user (WSL2, `/mnt/c/Users/...`), query it directly instead
   of walking the user through Event Viewer by hand:
   ```
   /mnt/c/Windows/System32/wevtutil.exe qe Application "/q:*[System[Provider[@Name='Application Error']]]" /c:5 /rd:true /f:text
   ```
   Also worth checking: `C:\ProgramData\Microsoft\Windows\WER\ReportArchive\`
   and `%LOCALAPPDATA%\CrashDumps\`. The faulting module name and offset
   are usually the single most useful facts available — an identical
   offset across builds that differ only in renderer/backend points at
   shared/generic engine code, not a driver-specific bug, and can save
   an entire wrong-theory detour (this cost real time once: two renderer
   switches were tried before this data was actually looked at).

2. **Search for how others have already solved this before inventing a
   fix.** If the symptom looks like a known engine bug class (e.g.
   "crashes only in release builds"), search the engine's own issue
   tracker and community forums for the standard/most common workaround
   first. Prefer an established, widely-recommended fix over a bespoke
   one (switching rendering backends, shipping a debug build instead of
   release, etc.) — save the exotic options for after the normal ones
   are checked and ruled out.

3. **Set up Wine to test Windows builds directly**, rather than relying
   on repeated manual round-trips with the user testing candidate
   builds by hand:
   ```
   sudo dpkg --add-architecture i386 && sudo apt-get update && sudo apt-get install -y wine wine64 wine32:i386
   pip3 install --user python-xlib Pillow   # scripted key input + screenshots of the Wine window
   ```
   **`sudo` needs an interactive password prompt** — a background/
   automated session (e.g. the hourly cron job) has no TTY to supply
   one and `sudo` just fails silently-ish (asks for a password, gets
   none, errors). This install step needs a live interactive session.
   When root isn't available and a tool needs installing anyway, try
   `apt-get download <pkg>` + `dpkg -x <pkg>.deb <local-dir>` first —
   that doesn't need root and worked for pulling in a full mingw-w64
   cross-compiler without sudo (see "Godot toolchain" above).

   Set this up as soon as a fix needs runtime verification beyond the
   headless smoke test — not only after the user has already had to
   manually test several candidate builds. **Limitation**: this
   environment's Wine only has software rasterizers available (Mesa
   llvmpipe/Lavapipe) — a clean Wine run rules out a general
   engine/script-level bug, but does NOT rule out a real GPU-driver-
   specific one. If something can only be confirmed on the user's real
   hardware and the user isn't available to test it, don't block and
   wait — work on something else useful in the meantime (another angle
   of the same investigation, another `PROGRESS.md` item) and come back
   to it.
   **As of 2026-09-03, Wine is broken in this environment for an
   unrelated reason**: it crashes immediately on *any* build, including
   an already-known-good one from before that date (identical fault
   address on a stock build and this session's new custom-template
   build both) — isolated to a drifted Mesa package mix
   (`libgl1-mesa-dri` newer than `libglapi-mesa`), not a code
   regression. See PROGRESS.md's "Wine verification is currently
   broken" note for the diagnosis and a possible fix
   (`apt-get install --reinstall libglapi-mesa`, untried). **Before
   trusting any new Wine crash as meaningful, first re-run a build from
   before that date** (or check PROGRESS.md for whether this has since
   been fixed) to rule out this same environment issue.
