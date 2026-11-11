# Room templates

Each `*.txt` file in this folder is one room drawn as a text map. The generator
(`generation/section_builder.gd`) picks rooms from here, connects their doors with
tunnels and fills the slots according to the director's plan. Files are read by
`generation/room_library.gd` and checked by `generation/room_template.gd`; a map
with mistakes is reported in the Output panel and not used.

## File format

Lines starting with `;` are settings, the rest is the map (one character = one 16x16 tile).

```
; name: small_hall          name used in logs (default: the file name)
; tags: combat, small       free words; "treasure" marks a side room with a chest
; ref_time: 8               reference time to clear the room, in seconds (director's T_ref)
#############
#...........#
D.....C.....D
```

## Legend

| Symbol | Meaning |
| --- | --- |
| `#` or space | wall |
| `.` | floor |
| `~` | pit (falling costs 30% of max HP) |
| `^` | spikes |
| `%` | cover that is always there (gravestone) |
| `D` | door cell; a door is exactly 3 cells in a row on the border of the map |
| `E` | enemy slot (floor; the generator may spawn one enemy or one beetle pack here) |
| `C` | cover slot (floor; the generator may put cover here) |
| `I` | item slot (floor; health pack or coins) |
| `T` | chest slot (floor; only in treasure rooms) |

## Rules checked by the loader

- All map lines have the same length; the border is made of walls and doors only.
- A door is exactly 3 tiles wide, at most one door per side.
- Ordinary rooms have a door on the left (west) and on the right (east) side: sections run left to right.
  Doors at the top or bottom are optional and are used for side branches.
- Treasure rooms (`tags: treasure`) have doors at the top and at the bottom and a `T` slot.
- Every door and every slot can be reached from the other doors over plain floor
  (pits and spikes may not cut a slot off).

Fixed parts of a room (pits, spikes, `%` cover, inner walls) are never changed by the
director; it only decides what goes into the `E`, `C`, `I` and `T` slots.

To look at a room in the game: run `tools/room_viewer.tscn` (F6) and set the room name
on its root node.
