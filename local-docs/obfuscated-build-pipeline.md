# Obfuscated + Encrypted Build Pipeline

## Goal
Full CLI pipeline: obfuscate → copy+overlay → export with custom Godot + encryption → collect artifacts.

## Single Command (Uber-Phase 1 — Complete)

```bash
"C:/dad/apps/godot/godot-4.5-stable/Godot_v4.5-stable_win64.exe" --headless \
  --path "C:/dad/projects/godot/godot-4/applications/godot-valet" \
  --script res://scripts/obfuscate-cli.gd -- \
  --project-dir "C:/dad/projects/godot/godot-4/applications/suganote/suganote-main" \
  --output "C:/tmp/suganote-obfuscated" \
  --functions --no-variables --comments \
  --skip-dirs "tests,build" \
  --export "Windows Desktop" \
  --godot-path "C:/dad/projects/godot/godot-4/applications/suganote/suganote-main/build/templates/godot_custom_editor_windows_x86_64.exe" \
  --encryption-key "C:/dad/projects/godot/godot-4/applications/suganote/suganote-main/build/templates/encryption.key" \
  --export-output "C:/tmp/suganote-export/Suganote.exe"
```

The pipeline handles everything: obfuscation, project copy, file overlay, encryption key loading, Godot export, artifact collection (exe + pck + DLLs), and build dir cleanup.

---

## Key Details
- **Custom encryption**: Suganote uses a custom-compiled Godot build with custom encryption (not stock Godot)
- **Suganote source**: `C:/dad/projects/godot/godot-4/applications/suganote/suganote-main/`
- **Custom Godot editor**: `suganote-main/build/templates/godot_custom_editor_windows_x86_64.exe`
- **Export templates**: `windows_release_x86_64.exe`, `windows_debug_x86_64.exe`
- **Encryption key**: `build/templates/encryption.key`
- **Export preset**: "Windows Desktop" in `export_presets.cfg`
- **Output artifacts**: exe + pck + SQLite DLL (all copied by pipeline)

---

## Current Status (2026-03-14)

### Working
- **Full CLI pipeline** — single command obfuscates + exports + collects artifacts (commit `104225a`)
- **Functions + comments obfuscation** — works correctly in exported build
- **Encrypted export** — PCK encrypted with custom key, runs on custom Godot build
- **SQLite GDExtension** — DLL now correctly copied alongside exe by pipeline
- **All 172 godot-valet unit tests passing**
- **Exported build verified** — Suganote launches, boards load, settings work, copy/paste works, navigation works

### Known Issues

#### Variable obfuscation breaks scene property assignments
- **Status**: NOT FIXED — use `--no-variables` for now
- **Symptom**: App loads but UI is broken (no navbar, no board grid, settings/feedback don't open)
- **Root cause**: `.tscn` scene files store exported property assignments using original variable names (`my_var = true`). When variable obfuscation renames these in `.gd` files, the `.tscn` files still reference old names. Godot silently ignores unrecognized properties — no SCRIPT ERRORs logged.
- **Current .tscn processing** only handles signal connections (`[connection signal="..." method="..."]`), not property name assignments
- **Fix needed**: Extend `ObfuscateSceneFiles()` to also rename property names in `[node]` sections of `.tscn` files, matching against the global variable obfuscation map

#### Build dir cleanup sometimes partial on Windows
- **Status**: Minor — `rmdir /S /Q` occasionally leaves remnants
- **Workaround**: Pipeline still works; leftover dirs don't affect subsequent runs

---

## Uber-Phase Roadmap

| Phase | Status | Description |
|-------|--------|-------------|
| **Uber-Phase 1** | **COMPLETE** | CLI full pipeline (obfuscate → export) |
| **Uber-Phase 2** | Next | GitHub Actions workflow using the CLI |
| **Uber-Phase 3** | Later | UI updates — see `godot-valet-ui-obfuscation-plan.md` |

### Next Steps
1. **Fix variable obfuscation in .tscn files** — extend scene processing to rename property names, not just signal connections
2. **Uber-Phase 2** — GitHub Actions workflow that runs the CLI command for automated builds
3. **Add `--validate` to pipeline** — optionally run headless validation before exporting

---

## Suganote-Side Requirements for Obfuscation
1. **Test preloads removed from main.gd** — Done (commit cdc1da8)
2. **Exclude tests/ from exports** — Done via `--skip-dirs tests,build`
3. **Use `--no-variables` flag** until .tscn property obfuscation is implemented
