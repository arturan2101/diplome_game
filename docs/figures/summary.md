# Bot experiment

180 runs, 2024 sections. Death section counts from 1 (dying in the first section = 1).

| Mode | Bot | Runs | Sections cleared (mean) | Depth reached (mean) | Died | Death section: median (25-75%) | HP on exit (mean) | HP on exit, sections 1-6 | Sections in HP 30-70 | Damage per section (mean) | Damage spread in a run (std) | Skill S (run mean) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RANDOM | weak | 30 | 5.3 | 2.2 | 100% | 6 (5-7) | 49 | 46 | 52% | 25.9 | 15.4 | 0.55 |
| RANDOM | mid | 30 | 9.8 | 3.4 | 100% | 10 (8-13) | 55 | 62 | 59% | 22.3 | 16.5 | 0.64 |
| RANDOM | strong | 30 | 10.5 | 3.7 | 100% | 12 (9-15) | 60 | 69 | 51% | 20.4 | 16.5 | 0.65 |
| RULES | weak | 30 | 9.1 | 3.1 | 100% | 10 (6-14) | 52 | 57 | 75% | 24.7 | 20.0 | 0.59 |
| RULES | mid | 30 | 14.4 | 4.5 | 100% | 15 (12-18) | 58 | 68 | 70% | 25.5 | 22.1 | 0.64 |
| RULES | strong | 30 | 12.5 | 3.9 | 97% | 12 (10-16) | 63 | 72 | 60% | 24.7 | 23.5 | 0.67 |

HP on exit counts finished sections only (not the one the bot died in); the sections 1-6 column counts a death there as HP 0, so it compares the same sections for every bot.

## Spread of HP on exit between bots

Smaller = the director keeps players of different skill closer to the same state.

| Mode | All finished sections: max - min of bot means | std | Sections 1-6: max - min | std |
| --- | --- | --- | --- | --- |
| RANDOM | 11.2 | 4.6 | 22.6 | 9.5 |
| RULES | 11.3 | 4.6 | 15.1 | 6.4 |

## Damage by source

Share of all damage taken; in brackets: in how many deaths this source dealt the most damage of the death section.

| Mode | Bot | archer | beetle | pit | skeleton | spikes |
| --- | --- | --- | --- | --- | --- | --- |
| RANDOM | weak | 29% (2) | 25% (3) | 23% (14) | 19% (11) | 5% (0) |
| RANDOM | mid | 51% (17) | 15% (2) | 7% (4) | 25% (7) | 3% (0) |
| RANDOM | strong | 70% (22) | 10% (0) | 8% (5) | 11% (2) | 2% (1) |
| RULES | weak | 30% (7) | 22% (1) | 23% (19) | 20% (3) | 5% (0) |
| RULES | mid | 53% (18) | 19% (4) | 7% (5) | 18% (3) | 2% (0) |
| RULES | strong | 76% (27) | 11% (0) | 4% (1) | 8% (1) | 1% (0) |

## Figures

![bots_overview.png](bots_overview.png)
![skill_by_section.png](skill_by_section.png)
![budget_by_section.png](budget_by_section.png)
![hp_by_section.png](hp_by_section.png)
