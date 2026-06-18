# TODO

## High Priority

- Fix the icon export pipeline. The current "Focus Then Hide" source artwork is clear, but the resized iconset/`.icns` output appears blurry at app-icon sizes.
- Test DockToggle across Dock positions: bottom, left, and right.
- Test with Dock magnification enabled and disabled.
- Verify behavior with multiple displays and different primary-display settings.
- Exercise common edge cases: full-screen apps, minimized-only apps, apps with no normal windows, and apps with helper processes.

## Medium Priority

- Add an app exclusion list for tools where repeated Dock clicks should always pass through.
- Add a diagnostic export button that copies recent logs and permission state into a support bundle.
- Replace duplicated PID extraction helpers in `DockInspector` and `DockIconCache` with one shared resolver.
- Decide whether `DecisionEngine` should be removed or revived as a fallback path.

## Low Priority

- Add an optional modifier-key requirement, such as Option-click to hide/minimize.
- Add a preference for debounce duration.
- Add a short troubleshooting screencast or GIF once behavior is stable.
