# Aureole Cursor

Highlight your mouse cursor with rings or a glow, plus an optional mouse trail. Sharp at every size, all settings on one page.

For World of Warcraft: Midnight (12.1.5). English and German. The timers use Blizzard's duration objects, so the rings keep working when combat values are restricted.

**Author:** Nightwalker559 · **License:** MIT with AI restriction

---

## Features

- **Rings:** a fixed **Main Ring**, a **GCD Ring** that drains while the global cooldown runs, and a **Cast Ring** that fills for casts, drains for channels and handles empowered spells. GCD and Cast Ring can fade between two colors. Use every ring, only Main + Cast or only Main + GCD; unused options are hidden.
- **Line style:** solid, dashed, dotted, ticks or segments, with eight thickness steps and an optional faint background track.
- **Pointer glow:** instead of the rings, a soft halo and/or crisp border in the shape of the game's pointer, in one or two colors. A copy of the pointer is drawn while the game hides it (mouse-looking). Only the glow follows the opacity settings.
- **Center mark:** dot, crosshair, double ring, corner brackets, sparkle, diamond, arrowhead, hexagon and more. Optional click pulse and **click wave** on left, right or both mouse buttons.
- **Combat color:** the Main Ring, dot or glow switches color in combat and back afterwards.
- **Mouse trail:** dots, leaves, snowflakes, stars, hearts, flames, paw prints, lightning, runes, confetti, energy and many more shapes. Color modes (rainbow, seasons, fire, water, arcane, custom gradients) and per-shape defaults for duration, spacing and size. Fast mouse movement stays gap-free.
- **Color themes:** one dropdown colors everything at once (class, faction, fire, ice, nature, arcane, shadow, void, holy, fel, blood, aurora, sunset, silver, lagoon). Halloween, Anniversary, Christmas and New Year's Eve also change the trail (falling pumpkins, rising balloons, baubles, rockets). A button takes a theme over as your own colors.
- **Visibility:** overall opacity, a separate opacity out of combat, show in combat only, hide while mouse-looking, frame layer.
- **Sharp at any size:** PNG textures in several resolutions, about half a MB in total.

## Usage

Open the settings with `/ac` or `/aureole` (`/aureolecursor` works too). Options that depend on another one are greyed out while they do not apply.

| Command | What it does |
| --- | --- |
| `/ac`, `/aureole` | Open the settings |
| `/aureole help` | Show the current state and the commands |
| `/aureole scale <n>` | Overall scale |
| `/aureole alpha <n>` | Overall opacity (0.1 to 1) |
| `/aureole combat on\|off` | Show only in combat |
| `/aureole ring main\|gcd\|cast\|dot\|trail on\|off` | Switch an element on or off |
| `/aureole ring <element> size <n>` | Change the size of an element |
| `/aureole reset` | Reset all settings |

## Good to know

- There are no health or power rings. Since Midnight those values are restricted for addons.
- The trail uses a fixed pool of textures with engine-driven animations, so it costs almost nothing per frame.

---

## Feedback

Found a bug or have an idea? [Open an issue on GitHub](https://github.com/Nightwalker559/AureoleCursor/issues).

## License

MIT with AI restriction (no use for AI or machine learning), see [LICENSE.md](https://github.com/Nightwalker559/AureoleCursor/blob/main/LICENSE.md).
