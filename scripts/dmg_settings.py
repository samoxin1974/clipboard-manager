import os

ROOT = os.environ.get("DMG_ROOT", os.getcwd())
APP = os.path.join(ROOT, "build", "Clipboard Manager.app")
BACKGROUND = os.path.join(ROOT, "Resources", "dmg-background.png")
ICON = os.path.join(ROOT, "Resources", "AppIcon.icns")

format = "UDZO"
filesystem = "HFS+"
compression_level = 9

files = [APP]
symlinks = {"Applications": "/Applications"}
icon_locations = {
    "Clipboard Manager.app": (165, 190),
    "Applications": (495, 190),
}

background = BACKGROUND
icon = ICON
window_rect = ((200, 180), (660, 428))
icon_size = 104
text_size = 12
label_pos = "bottom"
default_view = "icon-view"
arrange_by = None
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
show_item_info = False
