Asset naming guide for automatic loading

1) Card Art (used by battle hand buttons)
Folder:
- res://assets/placeholders/cards/

Recommended size:
- Render size in game: 240x360 (2:3)
- Source art size: 512x768 (2:3)

Supported formats:
- .png, .webp, .jpg, .jpeg

File name rule:
- <card_id>.<ext>

Example (from current card IDs):
- water_pump.png
- flood_barrier.png
- solar_flare.png
- mangrove_wall.png
- policy_strike.png
- green_bomb.png
- carbon_tax.png
- ev_initiative.png
- reforestation.png
- green_new_deal.png
- climate_pact.png

2) Character Art (used in battle scene sprites)
Folder:
- res://assets/placeholders/characters/

Recommended source size:
- 512x768 or 768x1024

Player candidates (first existing file will be loaded):
- mc.png
- player.png

Enemy candidates:
- enemy_flood.png (Flood battle)
- enemy_heatwave.png (Heatwave battle)
- enemy_boss.png (Boss battle)
- enemy.png (fallback for all)

3) Font
Font file path used by runtime UI style:
- res://assets/placeholders/ui/fonts/main_font.ttf

If the font file does not exist yet, game still runs with default font.
