from pathlib import Path
import subprocess

application = Path(defines["app"])
files = [str(application)]
symlinks = {"Applications": "/Applications"}
icon = str(application / "Contents/Resources/AppIcon.icns")
background = defines["background"]
format = "UDZO"
compression_level = 9
filesystem = "HFS+"
volume_name = "MacClean 安装"
window_rect = ((160, 120), (760, 550))
icon_locations = {"MacClean.app": (220, 247), "Applications": (540, 247)}
icon_size = 88
text_size = 12
arrange_by = None
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
include_icon_view_settings = True
include_list_view_settings = False
# Setting FinderInfo to hide the extension invalidates strict app signatures.
hide_extensions = []
show_item_info = False
show_icon_preview = False


def create_hook(mount_point, options):
    """Reject a damaged copy before compressing the image."""
    subprocess.run([
        "/usr/bin/codesign", "--verify", "--deep", "--strict",
        str(Path(mount_point) / "MacClean.app"),
    ], check=True)
