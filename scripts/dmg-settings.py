# dmgbuild settings for the drag-to-install DMG. Called by scripts/dmg.sh,
# which passes -D app=<path to Ampersand.app>.
# Layout must match scripts/dmg-background.swift (window 660x400, icons at y=180).
import os.path

app = defines["app"]  # noqa: F821 (injected by dmgbuild)
app_name = os.path.basename(app)

format = "ULMO"
filesystem = "APFS"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = os.path.join(app, "Contents/Resources/Ampersand.icns")

# dmgbuild combines background.png and background@2x.png into a HiDPI image.
background = "Resources/dmg/background.png"
window_rect = ((200, 120), (660, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 128
text_size = 13
icon_locations = {app_name: (165, 180), "Applications": (495, 180)}
