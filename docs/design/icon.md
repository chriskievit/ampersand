# App icon

`Resources/Ampersand.icon` is an Icon Composer document (macOS 26 Liquid Glass): an automatic graphite gradient fill with one glass layer, `Assets/prompt.svg`, a green `&` followed by a cursor underscore. `scripts/bundle.sh` compiles it with `actool` into `Assets.car` (default, dark and tinted appearances) plus a legacy `Ampersand.icns`; `Info.plist` names it with `CFBundleIconName` / `CFBundleIconFile`.

Chosen on 2026-10-13 from three concepts (`icon-concepts.png`: A Ink, B Run, C Prompt) — C.

Glyph credit: the ampersand outline is drawn from JetBrains Mono ExtraBold, © The JetBrains Mono Project Authors, licensed under the SIL Open Font License 1.1. SF Pro and SF Symbols are not used because Apple's licence excludes them from app icons.

To edit: open `Resources/Ampersand.icon` in Icon Composer (Xcode ▸ Open Developer Tool ▸ Icon Composer).
