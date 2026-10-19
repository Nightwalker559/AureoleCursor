# Aureole Cursor – Changelog

---

## 1.0.4

### Mouse trail
- Two new shapes for spring and summer: **Blossom** (five petals that tumble down while they fade, spring colors in pink and white with a touch of green) and **Butterfly** (small butterflies that flutter up and sideways, summer colors in yellow, orange, blue and green). Both come with matching color modes **Spring** and **Summer**, and every shape remembers its own settings like the other themed shapes.

### Ghost
- New **Ghost** section: while you are dead (corpse or spirit) a ghost floats above the cursor and bobs gently up and down. Off by default. Size, height above the cursor, color (or class color), opacity and the floating motion can be set. It works with the rings and with the pointer glow and follows the overall scale and opacity. It has a frame of its own, so it also shows when "Show in combat only" is on (you are not in combat when you are dead). Feigning death does not count. The bobbing is played by the engine.

### Pointer glow
- The copy of the pointer shown while the game hides the cursor (right mouse button held, camera turned) is now always fully opaque. It no longer follows the overall opacity, only the glow does. It is still hidden when everything else is invisible (overall opacity 0).

### Slash commands
- The shortcuts `/aureole scale`, `alpha` and `ring <element> size` now accept the same ranges as the sliders on the settings page (scale 0.5 to 3, opacity 0.1 to 1, size 8 to 400, mouse trail 4 to 64). Before, they could set values the slider could not show.

---

## 1.0.3

### Mouse trail
- Four new themed shapes: **Flame** (rises and glows, fire colors), **Heart** (floats up, pink and red), **Bubble** (a ring with a highlight that rises, blue tones) and **Glitter** (small four-point sparks scattered around the cursor that spin and glow, gold). Flame and glitter use additive blending so overlapping dots glow brighter. The motion is played by the engine like the fading, so it costs next to nothing per frame.
- Four matching color modes: **Fire**, **Love**, **Water** and **Gold** pick a color of the palette for every dot, like Autumn, Winter and Christmas.
- Every shape now remembers its own color mode (like its size, duration and spacing). Flame, heart, bubble and glitter start with their own palette, all other shapes keep the color mode you have.

### Pointer glow
- New **Main style** option in General: the cursor is surrounded either by the **Main Ring** (as before, still the default) or by the new **pointer glow**, a soft halo in the shape of the game's mouse pointer. With the glow there are no rings and no center dot: Main, GCD and Cast Ring, the center dot, the ring layout and their options are hidden. The mouse trail works independently of it. The settings of the hidden elements are kept, so switching back restores them.
- The glow is slightly larger than the pointer and follows the game's cursor size automatically (Options > Accessibility > Cursor Size), has its own color, class color and opacity, and a horizontal and vertical offset to fine-tune how it sits around the pointer.
- The glow can use **one or two colors**, set up like the custom colors of the mouse trail (number of colors and a color row). With two colors they blend smoothly from top to bottom or from left to right (**Gradient** on) or fill one half each (off). The opacity setting applies to both colors; class color replaces color 1.
- In combat the glow takes the combat color automatically (if "Tint automatically in combat" is on); the gradient is replaced by that color until the fight ends.
- While the game hides the pointer (right mouse button held, camera turned with the mouse) a copy of the pointer is shown at the same spot, so the glow does not hang around an invisible cursor. It can be switched off ("Show pointer while turning").
- The glow always has the shape of the normal pointer, also when the game shows a sword, a bag or a pickaxe; the game does not tell addons about those cursors.

### Code
- Release check: the display-change events (UI scale, resolution) moved from the rings to the core because they serve every element; shared helpers for the color rows in the settings and for stopping and shrinking trail dots; clearer option names and comments.

---

## 1.0.2

### Mouse trail
- "Custom color" now supports up to four colors. With **Gradient** on, the trail blends smoothly from one color to the next and back to the first; with it off, every dot picks one of the colors at random. The colors sit side by side in one row, as many as you choose. The opacity setting applies to all colors. Existing settings keep working (one color, as before).

### Rings
- New **Ring layout** option in General: "Individual rings" (as before), "Main + Cast Ring" or "Main + GCD Ring". The ring that is not used is turned off and its options are hidden in the settings. Its own settings are kept, so switching back restores them.
- The Cast Ring can now use a **color gradient** between two colors: it starts with color 1 and moves to color 2 while the cast progresses (works for casts, channels and empowered spells). The opacity applies to both colors, class color is ignored while the gradient is on.

### General
- The combat color moved to General and can now be applied to either the **Main Ring** or the **center dot** (including its click pulse). Your existing Main Ring combat color settings are carried over.

### Code
- All code comments are now in English.
- Cleanup: removed settings migrations from versions before the first release, merged duplicated code in the settings page.

---

## 1.0.1

### Mouse trail
- Two new shapes: **Mist**, a soft cloud that you can tint with every color mode, and **Energy**, a glowing energy pattern taken from the game files (nothing extra is shipped). Energy keeps its original colors, so color mode and color are disabled while it is selected; only the opacity applies.
- Every shape now has its own default size, duration and spacing. Values you set yourself are remembered per shape, like the sizes of the center mark.

### Defaults
- New defaults for the rings and the center mark: thicker rings, a larger white Cast Ring, a more visible background track, combat tint off, a bigger center dot and click pulse on both mouse buttons. Your existing settings stay as they are, only new installs and "Reset" use the new defaults.

---

## 1.0.0

First release.

### Rings
- Main Ring around the mouse cursor. In combat it can switch to a combat color automatically and back afterwards (on by default, the color is adjustable).
- GCD Ring that shows the global cooldown and drains while it runs.
- Cast Ring for casts (fills up), channels (drains) and empowered spells.
- Optional background track behind the GCD and Cast ring, so you can see how much is left.
- Ring thickness in eight steps. The ring textures come in several resolutions and are chosen by the on-screen size, so small rings stay sharp.

### Center mark
- Shapes: dot, crosshair with a gap, dot with a ring or a four-point sparkle. Every shape has its own default size, and a size you set yourself is remembered for that shape.
- Click pulse: a ring expands from the center and fades out when you press a mouse button. Options: on/off, mouse button (left, right or both) and the final size.

### Mouse trail
- A trail of dots that fades out and shrinks, with adjustable size, duration and spacing. Fast mouse movements stay gap-free.
- Shapes: dot, leaf, snowflake or star. Leaves, snowflakes and stars are rotated randomly.
- Color mode: rainbow, autumn, winter, Christmas, class color or a custom color.

### Settings and commands
- One settings page with a section per element. Options that depend on another one are greyed out while they do not apply.
- Every element has its own color, opacity and class color option. The color picker is greyed out while class color is active.
- Visibility: overall opacity, a separate opacity out of combat, "show in combat only", hide while mouse-looking and the frame layer.
- Open the settings with `/ac` or `/aureole`. `/aureole help` lists the other commands.
- English and German.
