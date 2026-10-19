# Scenario design sheets

One sheet per scenery, written before any detail modeling (greybox -> final, untextured, UV-unwrapped).

| Scene | Prompt | Sheet (written by the agent) |
|---|---|---|
| Main Street | `prompts/main_street.md` | `main_street.md` |
| Saloon | `prompts/saloon.md` | `saloon.md` |
| Canyon | `prompts/canyon.md` | `canyon.md` |
| Train Rooftop | `prompts/train_rooftop.md` | `train_rooftop.md` |
| Practice Hub | `prompts/practice_hub.md` | `practice_hub.md` |

## Workflow

1. Run each prompt on Fable 5.1 `high`. Do **Main Street first**: its global rules (wear, value logic, bevels, plank width, detail density) are inherited by the other four. Saloon, Train Rooftop, and Practice Hub reuse its pieces.
2. Answer the sheet's open questions (section F), then have the agent revise the sheet.
3. Approve the sheet. Build the sheet's hero asset on Fable 5.1 `high`, review it in Godot with the shaders on, then build the rest from the approved hero and the sheet.
4. Only one agent may drive Blender at a time (single live Blender on `localhost:9876`).
