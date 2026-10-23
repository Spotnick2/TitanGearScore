# Titan Panel [GearScore]

TitanGearScore shows your GearScore and equipped average item level on Titan Panel in **World of Warcraft: Forever**. It scores your equipped gear locally; it does not need a separate GearScore addon or library.

## Features

- GearScore and average item level on the Titan bar, refreshed when equipment changes.
- A smooth score color ramp from gray through orange, using Classic GearScore brackets of 200 points per tier.
- A tooltip with your total score, item count, and a per-slot breakdown. Scored items show their score and item level; other slots show their status.
- Hunter weighting for melee and ranged weapons.
- Shift+Left-click to print your score to chat.
- An option in the plugin's right-click menu to show or hide average item level on the bar.

If an equipped item's data is still loading or cannot be read, the displayed score includes a **`?`**. The tooltip identifies the affected slots. The addon updates when item data arrives and after combat; it does not count an unknown item as a zero-score item.

The average item level comes from Blizzard's equipped-item calculation. GearScore uses the GearScoreLite formula by Mirrikat45 with item-level thresholds from TacoTip by kebabstorm.

## Requirements and installation

- WoW: Forever 1.60.1 (Interface `16001`).
- A [Titan Panel](https://www.curseforge.com/wow/addons/titan-panel) version that supports Forever. Titan Panel is the only addon dependency.

Install with a WoW: Forever profile in your addon manager, or extract the release ZIP so the files are at:

```text
World of Warcraft/_classic_beta_/Interface/AddOns/TitanGearScore/TitanGearScore.toc
```

Enable **GearScore** in Titan Panel's plugin list under **Interface**.

## Commands

| Command | Action |
| --- | --- |
| `/tgs` | Print your GearScore and average item level to chat. |
| `/titangs` | Same as `/tgs`. |

## Compatibility and feedback

Version 2.1.1 is a Forever port with the Classic 200-point score scale. It no longer targets TBC Classic Anniversary, and it does not select Wrath or other client scales automatically. The Forever port passed offline Lua syntax and smoke tests, but has not yet been verified in game.

Report load errors or incorrect scores in [GitHub Issues](https://github.com/Spotnick2/TitanGearScore/issues) or on the CurseForge project page.
