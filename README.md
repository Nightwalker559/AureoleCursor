# Aureole Cursor

Highlight your mouse cursor with rings or with a glow. The rings are a fixed ring, a global cooldown ring, a cast ring and a center dot; the glow is a soft halo in the shape of the pointer. Add an optional mouse trail to either. Sharp edges at every size, all settings on one page.

Built for Midnight (12.1.5). The timers use Blizzard's duration objects, so the rings keep working when combat values are restricted.

## Features

- **Main Ring:** a fixed ring around the cursor.
- **GCD Ring:** shows the global cooldown and drains while it runs. Optionally it fades from one color to another while the GCD runs (color gradient).
- **Cast Ring:** shows casts (fills up), channels (drains) and empowered spells. Optionally it fades from one color to another while the cast progresses (color gradient).
- **Ring layout:** use every ring on its own, or only Main + Cast Ring, or only Main + GCD Ring. The options of a ring you do not use are hidden.
- **Main style:** the cursor is surrounded by the rings (default) or by the pointer glow, never both.
- **Pointer glow:** a soft halo in the shape of the game's mouse pointer, in one or two colors (as a gradient or two halves). It follows the game's cursor size and can be nudged by pixels. It replaces the rings and the center dot; the mouse trail still works. While the game hides the pointer (right mouse button, turning the camera) a copy of the pointer is drawn so the glow does not hang around an invisible cursor. The pointer is always fully opaque; only the glow follows the opacity settings.
- **Combat color:** in combat the Main Ring or the center dot (with the pointer glow: the glow) switches to a color of your choice automatically and back afterwards.
- **Background track:** an optional faint full ring behind the GCD and Cast ring, so you can see how much is left.
- **Center mark:** a dot in the middle of the rings, a crosshair with a gap, a crosshair with a dot, a dot with a ring, a double ring, corner brackets, a sparkle, a diamond, an arrowhead or a hexagon. It can give a click pulse: a ring that expands from the center when you press the left, right or both mouse buttons.
- **Mouse trail:** a trail of dots behind the cursor that fades out and shrinks. Color mode: rainbow, spring, summer, autumn, winter, Christmas, fire, love, water, gold, arcane, storm or custom colors (up to four, blended as a gradient along the trail or picked at random per dot). Shape: dot, leaf, snowflake, star, mist (a soft tintable cloud), flame, heart, bubble, glitter, blossom, butterfly, ember, raindrop, feather, lightning, crystal, coin, rune or confetti (these fourteen move: they rise, sink or scatter, and have their own colors) or energy (a glowing energy pattern from the game files, nothing extra is shipped), so the trail can fit the season. Duration, spacing and size are adjustable, and every shape has its own defaults for them (your changes are remembered per shape). Fast mouse movements stay gap-free.
- **Sharp at any size:** the textures come in several resolutions and are picked by the size on your screen, so small rings do not turn pixelated. Ring thickness has eight steps.
- **Color themes:** one dropdown in General sets the colors of everything at once: class color, fire, ice, nature, arcane, shadow, holy, sunset, silver or Halloween (orange and purple, and the trail turns into falling pumpkins, a shape that only exists with that theme). A theme colors the Main Ring, the center dot, the pointer glow and the trail, and the GCD and Cast Ring fade through it as a gradient. While a theme is active the color settings show its colors and are greyed out (the combat color still applies); a button takes a theme over as your own colors so you can adjust it.
- **Colors:** every element has its own color in its section (the GCD and Cast Ring, the pointer glow and the trail take several colors). "Custom colors" keeps them while a theme is chosen. There is one overall opacity (and one for the background tracks of the rings) instead of an opacity per element.
- **Visibility:** overall opacity, a separate opacity out of combat, "show in combat only", hide while mouse-looking, and the frame layer.
- **Languages:** English and German.

## Usage

Open the settings with `/ac` or `/aureole` (`/aureolecursor` works too). Everything is on one page with a section per element. Options that depend on another one are greyed out while they do not apply.

### Commands

| Command | What it does |
| --- | --- |
| `/ac` or `/aureole` | Open the settings |
| `/aureole help` | Show the current state and the command list |
| `/aureole scale <n>` | Overall scale |
| `/aureole alpha <n>` | Overall opacity (0.1 to 1) |
| `/aureole combat on\|off` | Show only in combat |
| `/aureole ring main\|gcd\|cast\|dot\|trail on\|off` | Switch an element on or off |
| `/aureole ring <element> size <n>` | Change the size of an element |
| `/aureole reset` | Reset all settings |

## Good to know

- There are no health or power rings. Since Midnight those values are restricted for addons and cannot be drawn reliably.
- The GCD and cast rings read Blizzard's duration objects instead of doing their own time math. Behavior in boss fights, Mythic+ and PvP has not been measured yet.
- The trail uses a fixed pool of textures with engine-driven animations, so it costs almost nothing per frame.

## Feedback

Found a bug or have an idea? Open an issue on GitHub.

## License

MIT, see [LICENSE.md](LICENSE.md).
