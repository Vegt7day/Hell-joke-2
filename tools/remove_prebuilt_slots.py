import re

filepath = r"d:\items\godot\hell_joke_2\文字地狱重制版\system\ui\inventory\inventory_ui.tscn"

with open(filepath, "r", encoding="utf-8") as f:
    lines = f.readlines()

# Remove ALL lines belonging to pre-built grid slots (Slot0-Slot47 in SlotGrid)
# and hotbar slots (Slot100-Slot107 in HotbarRow).
# Each slot block = panel + Ctrl + Icon + Char + Count + trailing blank lines.

def _is_slot_line(line: str) -> bool:
    """Check if a line belongs to any pre-built slot node or its children."""
    # Grid slot panel: [node name="SlotN" type="PanelContainer" parent="...SlotGrid" ...]
    if re.search(r'\[node name="Slot\d+" type="PanelContainer" parent="[^"]*SlotGrid"', line):
        return True
    # Hotbar slot nodes: long names like ..._Slot100#Ctrl, ..._Slot100_Ctrl#Icon
    if re.search(r'Slot10[0-7]', line):
        return True
    # Child of grid slot: parent="...SlotGrid/SlotN"
    if re.search(r'parent="[^"]*SlotGrid/Slot\d+', line):
        return True
    return False

# Also remove the StyleBox_slot_debug sub_resource if still present
in_debug_block = False
result = []
for line in lines:
    if line.strip().startswith('[sub_resource type="StyleBoxFlat" id="StyleBox_slot_debug"]'):
        in_debug_block = True
        continue
    if in_debug_block:
        if line.strip() == '' or line.strip().startswith('['):
            in_debug_block = False
            # Don't append this line now, check if it's a slot line below
            # fall through
        else:
            continue  # skip content lines inside debug block

    if _is_slot_line(line):
        continue

    result.append(line)

content = "".join(result)

with open(filepath, "w", encoding="utf-8") as f:
    f.write(content)

remaining = content.count('name="Slot')
print(f"Done. Remaining 'Slot' node references: {remaining}")