# World visual repair (#178)

The arrival train retains its native 124×40 and detail 496×160 canvas and existing carriage spacing. Only the unrelated sedan above the train was removed. The component audit combines body/detail layers before checking complete vehicle silhouettes; small antialiasing specks and emission masks are not second vehicles.

Street exits retain the canonical city graph and walking-minute costs. Outer corridors are 64px wide, or 160px where parallel destinations need separate paths. North gateways occupy y=304–320 and south gateways y=544–560, immediately beyond the respective pavement. Returning spawns remain on that pavement, outside every trigger. East/west exits stay at the map edge. The checker now explicitly validates these street gateway positions and rejects overlapping triggers; no arbitrary interior exit is accepted.

Each exit has one muted street sign with bounded translated text and an arrow rotated in its own slot. The tutorial resolves all four cardinal directions and uses a quiet ring over the current exit instead of a duplicate named arrow. The minimap retains cardinal arrows and removes indiscriminate gold spokes.

All 44 building definitions and 126 configured interactions were audited. Industry actions registered by Manufacturing, Real Estate, Media, Hotel, Energy, Automotive and International Trade follow their existing `os_<industry>` presentation gates. Running businesses retain access, including old saves. Leasing, public services, scheduled counters and NPCs remain reachable; hours, tenancy and transaction checks remain authoritative. No economy or save key changed. The dynamically created lease control now has a valid Home icon.

Locked Helio Supply is scenery until its energy gate opens; Helio Warehouse keeps its leasing entrance. Once unlocked, both energy desks show startup prerequisites and one next action without inactive statistics or operating tabs. Actual startup still uses Company registration, a funded business account, a paid warehouse lease and Energy.start(). This is presentation work, not a new unlock rule.

Evidence and commands: `evidence/2026-10-11_178/README.md`. Session I files are excluded from the diff.
