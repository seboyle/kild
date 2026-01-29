# Feature: peek diff --diff-output

## Summary

Add a `--diff-output <path>` option to the `kild-peek diff` command that saves a visual diff image highlighting pixel differences between two compared images. Both images are already loaded via the `image` crate for SSIM comparison — we compute per-pixel absolute differences and save the result as PNG. No new dependencies, no reliance on `image-compare`'s visualization API.

## User Story

As a developer using kild-peek for visual verification
I want to save a visual diff image when comparing screenshots
So that I can see exactly where UI differences are and debug failing visual tests

## Problem Statement

The `diff` command currently only outputs a similarity score. When images differ, there's no way to see *where* they differ without manual inspection.

## Solution Statement

After SSIM comparison, if `--diff-output` is specified, compute per-pixel absolute differences using the two images already loaded via the `image` crate, and save the result as PNG. Bright pixels = differences, dark pixels = identical. No new dependencies, no reliance on `image-compare`'s visualization API.

## Metadata

| Field            | Value                              |
| ---------------- | ---------------------------------- |
| Type             | ENHANCEMENT                        |
| Complexity       | LOW                                |
| Systems Affected | kild-peek-core/diff, kild-peek CLI |
| Dependencies     | image-compare 0.5, image 0.25      |
| Estimated Tasks  | 6                                  |

---

## UX Design

### Before State

```
╔═══════════════════════════════════════════════════════════════════╗
║  $ kild-peek diff before.png after.png --threshold 95           ║
║                                                                   ║
║  Image comparison: DIFFERENT                                      ║
║    Similarity: 87.3%                                              ║
║    Threshold: 95%                                                 ║
║    Image 1: 1920x1080                                             ║
║    Image 2: 1920x1080                                             ║
║                                                                   ║
║  → User knows images differ but NOT where                        ║
║  → Must visually compare images manually                         ║
╚═══════════════════════════════════════════════════════════════════╝
```

### After State

```
╔═══════════════════════════════════════════════════════════════════╗
║  $ kild-peek diff before.png after.png --diff-output diff.png   ║
║                                                                   ║
║  Image comparison: DIFFERENT                                      ║
║    Similarity: 87.3%                                              ║
║    Threshold: 95%                                                 ║
║    Image 1: 1920x1080                                             ║
║    Image 2: 1920x1080                                             ║
║    Diff saved: diff.png                                           ║
║                                                                   ║
║  → diff.png is a color-map image where bright areas = changes    ║
║  → Can open diff.png to see exactly where UI changed             ║
╚═══════════════════════════════════════════════════════════════════╝
```

### Interaction Changes

| Location      | Before                     | After                          | User Impact                        |
| ------------- | -------------------------- | ------------------------------ | ---------------------------------- |
| `diff` CLI    | Score-only output          | Optional `--diff-output` flag  | Can save visual diff image         |
| `diff` output | No file output             | Prints "Diff saved: path"     | Confirms where diff was written    |
| JSON output   | No diff_output_path field  | Includes diff_output_path      | Scripting can reference the file   |

---

## Mandatory Reading

| Priority | File                                                     | Lines   | Why Read This                               |
| -------- | -------------------------------------------------------- | ------- | ------------------------------------------- |
| P0       | `crates/kild-peek-core/src/diff/handler.rs`              | 18-76   | Current compare_images — add diff image gen |
| P0       | `crates/kild-peek-core/src/diff/types.rs`                | 1-105   | DiffRequest + DiffResult — extend both      |
| P0       | `crates/kild-peek-core/src/diff/errors.rs`               | 1-46    | DiffError — already has DiffGenerationFailed |
| P1       | `crates/kild-peek/src/commands.rs`                       | 230-284 | handle_diff_command — add --diff-output arg  |
| P1       | `crates/kild-peek/src/app.rs`                            | 114-142 | Diff CLI arg defs — add new arg              |
| P2       | `crates/kild-peek-core/src/screenshot/handler.rs`        | 34-60   | save_to_file pattern — mirror for diff save  |

---

## Patterns to Mirror

**ERROR_HANDLING:**
```rust
// SOURCE: crates/kild-peek-core/src/diff/errors.rs:19-20
// DiffGenerationFailed already exists — use it for pixel diff generation failures
#[error("Failed to generate diff image: {0}")]
DiffGenerationFailed(String),
```

**FILE_SAVING:**
```rust
// SOURCE: crates/kild-peek-core/src/screenshot/handler.rs:34-60
// Mirror this pattern for saving diff images
pub fn save_to_file(result: &CaptureResult, path: &Path) -> Result<(), ScreenshotError> {
    info!(event = "core.screenshot.save_started", path = %path.display());
    if let Some(parent) = path.parent()
        && !parent.as_os_str().is_empty()
        && !parent.exists()
    {
        debug!(event = "core.screenshot.creating_parent_directory", path = %parent.display());
        std::fs::create_dir_all(parent).map_err(|source| { /* ... */ })?;
    }
    std::fs::write(path, result.data())?;
    info!(event = "core.screenshot.save_completed", path = %path.display());
    Ok(())
}
```

**CLI_ARG_PATTERN:**
```rust
// SOURCE: crates/kild-peek/src/app.rs:86-89
// Mirror existing optional path args
.arg(
    Arg::new("output")
        .long("output")
        .short('o')
        .help("Save to file path (default: output base64 to stdout)"),
)
```

**LOGGING_PATTERN:**
```rust
// SOURCE: crates/kild-peek-core/src/diff/handler.rs:19-24
info!(
    event = "core.diff.compare_started",
    image1 = %request.image1_path.display(),
    image2 = %request.image2_path.display(),
    threshold = request.threshold
);
```

---

## Files to Change

| File                                            | Action | Justification                                       |
| ----------------------------------------------- | ------ | --------------------------------------------------- |
| `crates/kild-peek-core/src/diff/types.rs`       | UPDATE | Add diff_output_path to DiffRequest, diff_output_path to DiffResult |
| `crates/kild-peek-core/src/diff/handler.rs`     | UPDATE | Generate diff image when output path requested      |
| `crates/kild-peek/src/app.rs`                   | UPDATE | Add --diff-output arg to diff subcommand            |
| `crates/kild-peek/src/commands.rs`              | UPDATE | Wire --diff-output through to DiffRequest, print save confirmation |

---

## NOT Building (Scope Limits)

- **Side-by-side composite image** — Out of scope. The issue suggests it as an option but the absolute-difference image is the simplest and most useful approach. Side-by-side can be a separate follow-up.
- **Checkerboard blend** — Out of scope. Same rationale.
- **Custom highlight colors** — Out of scope. Absolute pixel difference is clear and self-explanatory.
- **Base64 diff output** — Out of scope. Diff images are always saved to file via `--diff-output`.

---

## Step-by-Step Tasks

### Task 1: UPDATE `crates/kild-peek-core/src/diff/types.rs` — Add diff output path to DiffRequest

- **ACTION**: Add `diff_output_path: Option<PathBuf>` field to `DiffRequest` and builder method
- **IMPLEMENT**:
  - Add `diff_output_path: Option<PathBuf>` field to `DiffRequest`
  - Initialize to `None` in `new()`
  - Add `.with_diff_output(path: impl Into<PathBuf>) -> Self` builder method
  - Add `diff_output_path: Option<String>` field to `DiffResult` (serializable for JSON output)
  - Pass it through `DiffResult::new()` — add parameter
  - Add getter `pub fn diff_output_path(&self) -> Option<&str>`
- **MIRROR**: Existing builder pattern in `DiffRequest::with_threshold()` (types.rs:26-29)
- **GOTCHA**: `DiffResult` derives `Serialize, Deserialize` — `Option<String>` is fine for the path. Use `String` not `PathBuf` because `DiffResult` is a serializable output type.
- **VALIDATE**: `cargo build -p kild-peek-core`

### Task 2: UPDATE `crates/kild-peek-core/src/diff/handler.rs` — Generate and save diff image

- **ACTION**: After SSIM comparison, if `diff_output_path` is set, compute pixel diff and save
- **IMPLEMENT**:
  - If `request.diff_output_path.is_some()`:
    - Use the two `DynamicImage`s already loaded (`img1`, `img2`) — convert to `rgba8()`
    - Compute per-pixel absolute difference:
      ```rust
      let img1_rgba = img1.to_rgba8();
      let img2_rgba = img2.to_rgba8();
      let mut diff_img = image::RgbImage::new(width1, height1);
      for (x, y, p1) in img1_rgba.enumerate_pixels() {
          let p2 = img2_rgba.get_pixel(x, y);
          diff_img.put_pixel(x, y, image::Rgb([
              p1[0].abs_diff(p2[0]),
              p1[1].abs_diff(p2[1]),
              p1[2].abs_diff(p2[2]),
          ]));
      }
      ```
    - Create parent directory if needed (mirror `save_to_file` pattern)
    - Save via `image::DynamicImage::ImageRgb8(diff_img).save(path)`
    - Log events: `core.diff.save_started`, `core.diff.save_completed`
  - Pass `diff_output_path` through to `DiffResult::new()`
  - Use `DiffError::DiffGenerationFailed` for save failures
  - Use `DiffError::IoError` for file write failures (already has `#[from] std::io::Error`)
- **MIRROR**: `save_to_file` in `screenshot/handler.rs:34-60` for directory creation and file writing
- **GOTCHA**: Images are already loaded and dimension-checked before this point. Use `to_rgba8()` (not `to_luma8()` which is only for SSIM).
- **VALIDATE**: `cargo build -p kild-peek-core && cargo test -p kild-peek-core`

### Task 3: UPDATE `crates/kild-peek/src/app.rs` — Add --diff-output CLI arg

- **ACTION**: Add `--diff-output` arg to the diff subcommand
- **IMPLEMENT**:
  - Add new `Arg::new("diff-output")` to the diff subcommand
  - Long flag: `--diff-output`
  - Help text: `"Save visual diff image highlighting differences"`
  - No short flag (keep it explicit)
  - No default value (optional)
- **MIRROR**: `Arg::new("output")` pattern from screenshot subcommand (app.rs:86-89)
- **VALIDATE**: `cargo build -p kild-peek`

### Task 4: UPDATE `crates/kild-peek/src/commands.rs` — Wire --diff-output through handler

- **ACTION**: Parse `--diff-output` arg and pass to DiffRequest, print save confirmation
- **IMPLEMENT**:
  - In `handle_diff_command()`, parse `matches.get_one::<String>("diff-output")`
  - Chain `.with_diff_output(path)` on `DiffRequest` when provided
  - After successful comparison, if diff output was saved:
    - Print `"  Diff saved: {path}"` in human-readable mode
    - The JSON output already includes `diff_output_path` via DiffResult serialization
  - Add `diff_output` field to logging events
- **MIRROR**: How `output_path` is handled in `handle_screenshot_command()` (commands.rs:151, 183-188)
- **VALIDATE**: `cargo build -p kild-peek`

### Task 5: Add tests for diff output functionality

- **ACTION**: Add unit tests in types.rs and handler.rs
- **IMPLEMENT**:
  - `test_diff_request_with_diff_output()` — builder test
  - `test_diff_request_default_no_diff_output()` — default is None
  - `test_diff_result_with_diff_output_path()` — result getter
  - `test_diff_result_without_diff_output_path()` — None case
  - `test_cli_diff_with_diff_output()` — CLI arg parsing test in app.rs
- **MIRROR**: Existing test patterns in `types.rs:112-168` and `app.rs:308-346`
- **VALIDATE**: `cargo test -p kild-peek-core && cargo test -p kild-peek`

### Task 6: Run full validation

- **ACTION**: Verify everything compiles, passes tests, passes lints
- **VALIDATE**:
  ```bash
  cargo fmt --check
  cargo clippy --all -- -D warnings
  cargo test --all
  cargo build --all
  ```

---

## Testing Strategy

### Unit Tests to Write

| Test File                                       | Test Cases                                     | Validates                     |
| ----------------------------------------------- | ---------------------------------------------- | ----------------------------- |
| `crates/kild-peek-core/src/diff/types.rs`       | builder with/without diff_output, result getter | DiffRequest/DiffResult types  |
| `crates/kild-peek-core/src/diff/handler.rs`     | compare with nonexistent image (existing test)  | Error handling preserved      |
| `crates/kild-peek/src/app.rs`                   | CLI parsing with --diff-output                  | Arg wiring                    |

### Edge Cases Checklist

- [x] `--diff-output` not provided → no diff image generated, existing behavior unchanged
- [ ] `--diff-output` with nonexistent parent directory → auto-create parents
- [ ] `--diff-output` points to unwritable path → DiffError::IoError surfaced
- [ ] `--diff-output` combined with `--json` → JSON includes diff_output_path
- [ ] `--diff-output` combined with `--threshold` → both work together
- [ ] Images are identical → diff image still generated (shows all-black image)

---

## Validation Commands

### Level 1: STATIC_ANALYSIS

```bash
cargo fmt --check && cargo clippy --all -- -D warnings
```

**EXPECT**: Exit 0, no errors or warnings

### Level 2: UNIT_TESTS

```bash
cargo test -p kild-peek-core && cargo test -p kild-peek
```

**EXPECT**: All tests pass

### Level 3: FULL_SUITE

```bash
cargo test --all && cargo build --all
```

**EXPECT**: All tests pass, build succeeds

### Level 6: MANUAL_VALIDATION

1. Take two different screenshots
2. Run `kild-peek diff img1.png img2.png --diff-output /tmp/diff.png`
3. Verify diff.png exists and highlights differences
4. Run same command with `--json` and verify `diff_output_path` in output
5. Run without `--diff-output` and verify behavior unchanged

---

## Acceptance Criteria

- [ ] `kild-peek diff a.png b.png --diff-output diff.png` saves a visual diff image
- [ ] Output prints "Diff saved: diff.png" in human-readable mode
- [ ] JSON output includes `diff_output_path` field
- [ ] Parent directories are auto-created for diff output path
- [ ] Omitting `--diff-output` preserves existing behavior exactly
- [ ] All validation levels (1-3) pass
- [ ] No new dependencies added

---

## Completion Checklist

- [ ] All tasks completed in dependency order
- [ ] Each task validated immediately after completion
- [ ] Level 1: Static analysis passes
- [ ] Level 2: Unit tests pass
- [ ] Level 3: Full test suite + build succeeds
- [ ] All acceptance criteria met

---

## Risks and Mitigations

| Risk                                           | Likelihood | Impact | Mitigation                                                              |
| ---------------------------------------------- | ---------- | ------ | ----------------------------------------------------------------------- |
| Large images produce large diff files          | LOW        | LOW    | PNG compression handles this; same as screenshot output                 |

---

## Notes

- The `DiffError::DiffGenerationFailed` variant already exists in `errors.rs:19-20` with error code `DIFF_GENERATION_FAILED`. It was added proactively — this feature is its first real use.
- The visual diff uses manual per-pixel absolute difference via the `image` crate (already a dependency). We intentionally avoid `image-compare`'s `to_color_map()` — it's a pre-1.0 crate with thin documentation, and for the most user-visible part of this feature we want transparent, controllable code.
- The `image` crate's `DynamicImage::save()` method auto-detects format from file extension, so saving as `.png` works automatically.
- Both images are already loaded via `image::open()` and dimensions already verified before SSIM runs — the pixel diff reuses these loaded images.
