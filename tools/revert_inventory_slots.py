# Revert debug slot fills in inventory_ui.tscn
# Removes theme_override_styles/panel = SubResource("StyleBox_slot_debug") from all slots
# Removes text = "N" from Char and Count labels, and the debug sub_resource

import re

filepath = r"d:\items\godot\hell_joke_2\文字地狱重制版\system\ui\inventory\inventory_ui.tscn"

with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Remove the debug sub_resource block
debug_block = re.escape('''[sub_resource type="StyleBoxFlat" id="StyleBox_slot_debug"]
bg_color = Color(0.15, 0.15, 0.18, 1)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.35, 0.35, 0.38, 1)
content_margin_left = 1
content_margin_top = 1
content_margin_right = 1
content_margin_bottom = 1

''')
content = re.sub(debug_block, '', content)

# 2. Remove theme_override_styles/panel = SubResource("StyleBox_slot_debug") lines
content = re.sub(
    r'\ntheme_override_styles/panel = SubResource\("StyleBox_slot_debug"\)\n',
    '\n',
    content
)

# 3. Remove text = "N" from Char labels (grid slots: "0"-"47", hotbar: "1"-"8")
content = re.sub(r'\ntext = "\d{1,2}"\n', '\n', content)

# 4. Remove text = "N" from Count labels
content = re.sub(r'\ntext = "\d"\n', '\n', content)

with open(filepath, "w", encoding="utf-8") as f:
    f.write(content)

print("Reverted. Removed all debug fills from inventory_ui.tscn")