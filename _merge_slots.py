import os, re

tscn_path = 'd:/items/godot/hell_joke_2/文字地狱重制版/system/ui/inventory/inventory_ui.tscn'
slots_path = 'd:/items/godot/hell_joke_2/文字地狱重制版/_slots_generated.txt'

with open(tscn_path, 'r', encoding='utf-8') as f:
    tscn = f.read()

with open(slots_path, 'r', encoding='utf-8') as f:
    slots = f.read()

# Find the HotbarRow definition and add hotbar slots after it
hotbar_pattern = r'(\[node name="HotbarRow".*?alignment = 1\])\n'
# Find the SlotGrid definition and add grid slots after it  
grid_pattern = r'(\[node name="SlotGrid".*?columns = 8\])\n'

# Read all slot blocks
all_slot_names = re.findall(r'\[node name="Slot(\d+)"', slots)
print(f"Found {len(all_slot_names)} slot blocks")

# Separate grid slots (first 48) from hotbar slots (last 8)
lines = slots.strip().split('\n')
grid_slots_text = ''
hotbar_slots_text = ''
current_block = ''
block_idx = 0

for line in lines:
    if line.startswith('[node name="Slot') and current_block:
        if block_idx < 48:
            grid_slots_text += current_block + '\n'
        else:
            hotbar_slots_text += current_block + '\n'
        current_block = line + '\n'
        block_idx += 1
    else:
        current_block += line + '\n'

# Add the last block
if current_block:
    if block_idx < 48:
        grid_slots_text += current_block
    else:
        hotbar_slots_text += current_block

print(f"Grid slots: {len(grid_slots_text)} chars")
print(f"Hotbar slots: {len(hotbar_slots_text)} chars")

# Insert hotbar slots after HotbarRow definition
marker_hb = 'alignment = 1\n'
idx_hb = tscn.find(marker_hb)
if idx_hb >= 0:
    pos_hb = idx_hb + len(marker_hb)
    tscn = tscn[:pos_hb] + '\n' + hotbar_slots_text + tscn[pos_hb:]
    print(f"Inserted hotbar slots at position {pos_hb}")
else:
    print("ERROR: HotbarRow marker not found!")

# Insert grid slots after SlotGrid definition
marker_sg = 'columns = 8\n'
idx_sg = tscn.find(marker_sg)
if idx_sg >= 0:
    pos_sg = idx_sg + len(marker_sg)
    tscn = tscn[:pos_sg] + '\n' + grid_slots_text + tscn[pos_sg:]
    print(f"Inserted grid slots at position {pos_sg}")
else:
    print("ERROR: SlotGrid marker not found!")

# Write result
with open(tscn_path, 'w', encoding='utf-8') as f:
    f.write(tscn)

print(f"Done! New file size: {len(tscn)} chars")