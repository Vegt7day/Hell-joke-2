import re

filepath = r"d:\items\godot\hell_joke_2\文字地狱重制版\system\ui\inventory\inventory_ui.tscn"

with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Insert sub_resource for debug slot style after existing StyleBoxTexture_desc
debug_style = '''[sub_resource type="StyleBoxFlat" id="StyleBox_slot_debug"]
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

'''

# Insert before first [node ...] line (after all [ext_resource] and [sub_resource] lines)
# Find the last sub_resource line and insert after it
last_sub_resource_end = content.rfind("content_margin_bottom = 4")
if last_sub_resource_end != -1:
    insert_pos = content.index("\n", last_sub_resource_end) + 1
else:
    # Fallback: insert after all ext_resource lines
    last_ext = content.rfind('[ext_resource')
    if last_ext != -1:
        insert_pos = content.index('\n\n', last_ext) + 2

content = content[:insert_pos] + debug_style + content[insert_pos:]

# 2. For each Slot0-Slot47 (grid slots) and Slot100-Slot107 (hotbar slots) PanelContainer,
#    add theme_override_styles/panel = SubResource("StyleBox_slot_debug")
#    Slot panels look like:
#    [node name="SlotN" type="PanelContainer" parent="..."]
#    custom_minimum_size = Vector2(X, X)
#    layout_mode = 2
#    mouse_filter = 1
#    (blank line)
#    [node name="Ctrl"...]

# We add the style line right before the blank line preceding [node name="Ctrl"]
# Pattern: match the Slot PanelContainer block
def add_panel_style(m):
    block = m.group(0)
    # Add theme_override_styles/panel right after mouse_filter line
    block = block.replace(
        'mouse_filter = 1\n\n[node name="Ctrl"',
        'mouse_filter = 1\ntheme_override_styles/panel = SubResource("StyleBox_slot_debug")\n\n[node name="Ctrl"'
    )
    return block

# Match grid slots: Slot0 through Slot47
pattern_grid = r'\[node name="Slot\d+" type="PanelContainer" parent="[^"]*SlotGrid"\][\s\S]*?\n\n\[node name="Ctrl"'
content = re.sub(pattern_grid, add_panel_style, content)

# Match hotbar slots: Slot100 through Slot107
pattern_hotbar = r'\[node name="Slot10\d" type="PanelContainer" parent="[^"]*HotbarRow"\][\s\S]*?\n\n\[node name="Ctrl"'
content = re.sub(pattern_hotbar, add_panel_style, content)

# 3. Add text to Char labels inside slots
# Grid slots: Char label at parent "SlotGrid/SlotN/Ctrl"
def add_char_text_grid(m):
    slot_num = m.group(1)
    return f'{m.group(0)}\ntext = "{slot_num}"'

pattern_char_grid = r'\[node name="Char" type="Label" parent="[^"]*SlotGrid/Slot(\d+)/Ctrl"\]\nlayout_mode = 0\nanchor_left = 0\.0\nanchor_top = 0\.0\nanchor_right = 1\.0\nanchor_bottom = 1\.0\nmouse_filter = 2\nhorizontal_alignment = 1\nvertical_alignment = 1'
content = re.sub(pattern_char_grid, add_char_text_grid, content)

# Hotbar slots: Char label at parent "HotbarRow/Slot10N/Ctrl"  
def add_char_text_hotbar(m):
    slot_num = m.group(1)
    return f'{m.group(0)}\ntext = "H{slot_num[-1:]}"'

pattern_char_hotbar = r'\[node name="Char" type="Label" parent="[^"]*HotbarRow/Slot(10\d)/Ctrl"\]\nlayout_mode = 0\nanchor_left = 0\.0\nanchor_top = 0\.0\nanchor_right = 1\.0\nanchor_bottom = 1\.0\nmouse_filter = 2\nhorizontal_alignment = 1\nvertical_alignment = 1'
content = re.sub(pattern_char_hotbar, add_char_text_hotbar, content)

# 4. Add count text to Count labels inside grid slots
def add_count_text_grid(m):
    slot_num = int(m.group(1))
    count = (slot_num % 9) + 1
    return f'{m.group(0)}\ntext = "{count}"'

pattern_count_grid = r'\[node name="Count" type="Label" parent="[^"]*SlotGrid/Slot(\d+)/Ctrl"\]\nlayout_mode = 0\nanchor_left = 0\.0\nanchor_top = 0\.0\nanchor_right = 1\.0\nanchor_bottom = 1\.0\nmouse_filter = 2\nhorizontal_alignment = 2\nvertical_alignment = 2\ntheme_override_fonts/font = ExtResource\("2_f12"\)\ntheme_override_font_sizes/font_size = 9'
content = re.sub(pattern_count_grid, add_count_text_grid, content)

# 5. Add hotbar key hint to Char labels (1-8)
def add_hotbar_key(m):
    slot_num = int(m.group(1))
    key = slot_num - 99  # 100->1, 101->2, etc.
    # The text was already added above, replace it
    old = f'text = "H{slot_num%10}"'
    new = f'text = "{key}"'
    return m.group(0).replace(old, new)

pattern_hotbar_char = r'\[node name="Char" type="Label" parent="[^"]*HotbarRow/Slot(10\d)/Ctrl"\][\s\S]*?vertical_alignment = 1\ntext = "H\d"'
content = re.sub(pattern_hotbar_char, add_hotbar_key, content)

with open(filepath, "w", encoding="utf-8") as f:
    f.write(content)

print("Done. Added debug panel styles and slot labels to inventory_ui.tscn")