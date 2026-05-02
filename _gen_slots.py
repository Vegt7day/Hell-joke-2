# Generate tscn slot entries
SLOT_SZ = 28
ICON_SZ = 22
OFF = (SLOT_SZ - ICON_SZ) // 2

grid_parent = "Root/back/Center/MainVBox/BodyHBox/LeftGrow/PageCenter/LeftColumn/SlotGrid"
hotbar_parent = "Root/back/Center/MainVBox/BodyHBox/LeftGrow/PageCenter/LeftColumn/HotbarRow"

def slot(idx, parent, sz, icon_sz, off):
    p = parent
    name = f"Slot{idx}"
    return (
        f'[node name="{name}" type="PanelContainer" parent="{p}"]\n'
        f'custom_minimum_size = Vector2({sz}, {sz})\n'
        f'layout_mode = 2\n'
        f'mouse_filter = 1\n'
        f'\n'
        f'[node name="Ctrl" type="Control" parent="{p}/{name}"]\n'
        f'layout_mode = 0\n'
        f'anchor_left = 0.0\n'
        f'anchor_top = 0.0\n'
        f'anchor_right = 1.0\n'
        f'anchor_bottom = 1.0\n'
        f'mouse_filter = 2\n'
        f'\n'
        f'[node name="Icon" type="TextureRect" parent="{p}/{name}/Ctrl"]\n'
        f'custom_minimum_size = Vector2({icon_sz}, {icon_sz})\n'
        f'layout_mode = 0\n'
        f'offset_left = {off}.0\n'
        f'offset_top = {off}.0\n'
        f'offset_right = {off + icon_sz}.0\n'
        f'offset_bottom = {off + icon_sz}.0\n'
        f'mouse_filter = 2\n'
        f'expand_mode = 1\n'
        f'stretch_mode = 5\n'
        f'\n'
        f'[node name="Char" type="Label" parent="{p}/{name}/Ctrl"]\n'
        f'layout_mode = 0\n'
        f'anchor_left = 0.0\n'
        f'anchor_top = 0.0\n'
        f'anchor_right = 1.0\n'
        f'anchor_bottom = 1.0\n'
        f'mouse_filter = 2\n'
        f'horizontal_alignment = 1\n'
        f'vertical_alignment = 1\n'
        f'\n'
        f'[node name="Count" type="Label" parent="{p}/{name}/Ctrl"]\n'
        f'layout_mode = 0\n'
        f'anchor_left = 0.0\n'
        f'anchor_top = 0.0\n'
        f'anchor_right = 1.0\n'
        f'anchor_bottom = 1.0\n'
        f'mouse_filter = 2\n'
        f'horizontal_alignment = 2\n'
        f'vertical_alignment = 2\n'
        f'theme_override_fonts/font = ExtResource("2_f12")\n'
        f'theme_override_font_sizes/font_size = 9\n'
        f'\n'
    )

result = ""
for i in range(48):
    result += slot(i, grid_parent, SLOT_SZ, ICON_SZ, OFF)
for i in range(8):
    ri = i + 100  # use high index to avoid collision
    result += slot(ri, hotbar_parent, 30, 22, 4)

with open("d:/items/godot/hell_joke_2/文字地狱重制版/_slots_generated.txt", "w", encoding="utf-8") as f:
    f.write(result)

print(f"Generated {48 + 8} slots, {len(result)} chars")
print("Written to _slots_generated.txt")