# Audio credits and source provenance

All delivered issue 97 audio is original project material synthesized from written compositions and foley equations by `tools/media/compose_city_audio.py`. It uses the project's original instrument functions in `tools/media/make_game_audio.py` (electric piano, bass, brushed percussion, filtered noise and reverberation). No external recordings, samples, voices, copyrighted melodies or third-party music were imported. This is the self-made-material route allowed by issue 97; no external attribution or royalty license is required for these project assets. It does not dedicate the project's intellectual property to a new public license.

Sixteen distinct eight-bar compositions specify their tempo, tonic, chord sequence, melody motif and arrangement in `SCORES`. Each has a harmonic/melodic base, bass/percussion pulse and ornament lift. All three stems share sample rate and exact loop duration and are normalized together. Crisis uses a minor palette; roadshow and victory are presentation cues. Day/night ambience uses individual district foley signatures: water at Riverside/Harbor, machines at Industrial, birds at University/residential, market/cup sounds and airport PA chimes. Airport cues contain no intelligible speech or real-world flight announcement. Four room beds cover factory, hotel lobby, office and cafe.

The original five legacy loops and twelve UI effects remain project-generated fallback material from `make_game_audio.py`; the new set supplements them. All assets are Ogg Vorbis at 24,000 Hz (new set) or 44,100 Hz (legacy set). Mono layers are mixed through Music; Ambient routes into SFX so the existing SFX slider also controls it. The generator is deterministic and does not overwrite legacy tracks. Total OGG bytes: **6,841,147** (6.84 decimal MB), including legacy assets, below the 25 MB budget. Exported Web PCK size is measured separately in evidence and must remain below 160,000,000 bytes.

| File under game/assets/audio | Bytes |
|---|---:|
| `ambient/airport_day.ogg` | 58,309 |
| `ambient/airport_night.ogg` | 56,022 |
| `ambient/cafe.ogg` | 74,570 |
| `ambient/civic_center_day.ogg` | 74,683 |
| `ambient/civic_center_night.ogg` | 70,885 |
| `ambient/factory.ogg` | 60,212 |
| `ambient/financial_day.ogg` | 74,675 |
| `ambient/financial_night.ogg` | 70,829 |
| `ambient/harbor_day.ogg` | 76,491 |
| `ambient/harbor_night.ogg` | 73,618 |
| `ambient/hotel.ogg` | 74,873 |
| `ambient/industrial_day.ogg` | 60,224 |
| `ambient/industrial_night.ogg` | 57,436 |
| `ambient/luxury_heights_day.ogg` | 74,812 |
| `ambient/luxury_heights_night.ogg` | 71,324 |
| `ambient/office.ogg` | 74,540 |
| `ambient/old_town_day.ogg` | 76,053 |
| `ambient/old_town_night.ogg` | 72,928 |
| `ambient/residential_day.ogg` | 75,074 |
| `ambient/residential_night.ogg` | 71,419 |
| `ambient/riverside_day.ogg` | 76,310 |
| `ambient/riverside_night.ogg` | 73,336 |
| `ambient/shopping_street_day.ogg` | 74,724 |
| `ambient/shopping_street_night.ogg` | 71,169 |
| `ambient/startup_hub_day.ogg` | 74,518 |
| `ambient/startup_hub_night.ogg` | 71,049 |
| `ambient/university_day.ogg` | 75,083 |
| `ambient/university_night.ogg` | 71,334 |
| `music/auto_work.ogg` | 33,730 |
| `music/auto_work_lift.ogg` | 48,449 |
| `music/auto_work_pulse.ogg` | 48,589 |
| `music/cafe_work.ogg` | 44,353 |
| `music/cafe_work_lift.ogg` | 51,167 |
| `music/cafe_work_pulse.ogg` | 52,560 |
| `music/city_night.ogg` | 49,610 |
| `music/city_night_lift.ogg` | 62,356 |
| `music/city_night_pulse.ogg` | 60,636 |
| `music/consulting.ogg` | 39,593 |
| `music/consulting_lift.ogg` | 50,461 |
| `music/consulting_pulse.ogg` | 50,933 |
| `music/crisis.ogg` | 30,624 |
| `music/crisis_lift.ogg` | 44,474 |
| `music/crisis_pulse.ogg` | 46,322 |
| `music/energy_work.ogg` | 38,913 |
| `music/energy_work_lift.ogg` | 45,305 |
| `music/energy_work_pulse.ogg` | 48,504 |
| `music/factory_work.ogg` | 32,949 |
| `music/factory_work_lift.ogg` | 50,644 |
| `music/factory_work_pulse.ogg` | 49,959 |
| `music/founders.ogg` | 36,583 |
| `music/founders_lift.ogg` | 48,622 |
| `music/founders_pulse.ogg` | 49,395 |
| `music/hotel_work.ogg` | 46,437 |
| `music/hotel_work_lift.ogg` | 58,999 |
| `music/hotel_work_pulse.ogg` | 57,081 |
| `music/logistics_work.ogg` | 36,213 |
| `music/logistics_work_lift.ogg` | 50,750 |
| `music/logistics_work_pulse.ogg` | 50,679 |
| `music/media_work.ogg` | 34,072 |
| `music/media_work_lift.ogg` | 43,667 |
| `music/media_work_pulse.ogg` | 47,313 |
| `music/property_work.ogg` | 41,457 |
| `music/property_work_lift.ogg` | 50,897 |
| `music/property_work_pulse.ogg` | 51,024 |
| `music/roadshow.ogg` | 34,436 |
| `music/roadshow_lift.ogg` | 44,749 |
| `music/roadshow_pulse.ogg` | 47,741 |
| `music/saas_work.ogg` | 34,273 |
| `music/saas_work_lift.ogg` | 47,125 |
| `music/saas_work_pulse.ogg` | 47,961 |
| `music/season_festival.ogg` | 37,336 |
| `music/season_festival_lift.ogg` | 44,529 |
| `music/season_festival_pulse.ogg` | 47,774 |
| `music/victory.ogg` | 39,862 |
| `music/victory_lift.ogg` | 47,419 |
| `music/victory_pulse.ogg` | 49,614 |
| `sfx/auction.ogg` | 4,239 |
| `sfx/campaign_mixer.ogg` | 4,264 |
| `sfx/creative_pitch.ogg` | 4,265 |
| `sfx/line_planner.ogg` | 4,187 |
| `sfx/matchmaker.ogg` | 4,208 |
| `sfx/rate_board.ogg` | 4,217 |
| `sfx/roof_survey.ogg` | 4,236 |
