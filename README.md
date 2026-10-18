# Aureole Cursor

Rings around your mouse cursor: a fixed ring, a global cooldown ring, a cast ring, a center dot and an optional mouse trail. Or, instead of the rings, a glow in the shape of the pointer. Sharp edges at every size, all settings on one page.

Built for Midnight (12.1.5). The timers use Blizzard's duration objects, so the rings keep working when combat values are restricted.

## Features

- **Main Ring:** a fixed ring around the cursor.
- **GCD Ring:** shows the global cooldown and drains while it runs.
- **Cast Ring:** shows casts (fills up), channels (drains) and empowered spells. Optionally it fades from one color to another while the cast progresses (color gradient).
- **Ring layout:** use every ring on its own, or only Main + Cast Ring, or only Main + GCD Ring. The options of a ring you do not use are hidden.
- **Main style:** the cursor is surrounded by the rings (default) or by the pointer glow, never both.
- **Pointer glow:** a soft halo in the shape of the game's mouse pointer, in one or two colors (as a gradient or two halves) or in your class color. It follows the game's cursor size and can be nudged by pixels. It replaces the rings and the center dot; the mouse trail still works. While the game hides the pointer (right mouse button, turning the camera) a copy of the pointer is drawn so the glow does not hang around an invisible cursor.
- **Combat color:** in combat the Main Ring or the center dot (with the pointer glow: the glow) switches to a color of your choice automatically and back afterwards.
- **Background track:** an optional faint full ring behind the GCD and Cast ring, so you can see how much is left.
- **Center mark:** a dot in the middle of the rings, or a crosshair with a gap, a dot with a ring or a sparkle. It can give a click pulse: a ring that expands from the center when you press the left, right or both mouse buttons.
- **Mouse trail:** a trail of dots behind the cursor that fades out and shrinks. Color mode: rainbow, autumn, winter, Christmas, fire, love, water, gold, class color or custom colors (up to four, blended as a gradient along the trail or picked at random per dot). Shape: dot, leaf, snowflake, star, mist (a soft tintable cloud), flame, heart, bubble or glitter (these four move: they rise or scatter, and have their own colors) or energy (a glowing energy pattern from the game files, nothing extra is shipped), so the trail can fit the season. Duration, spacing and size are adjustable, and every shape has its own defaults for them (your changes are remembered per shape). Fast mouse movements stay gap-free.
- **Sharp at any size:** the textures come in several resolutions and are picked by the size on your screen, so small rings do not turn pixelated. Ring thickness has eight steps.
- **Colors:** every element has its own color, opacity and class color option.
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
| `/aureole alpha <n>` | Overall opacity (0.05 to 1) |
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
