# Weather emoji font

`Twemoji.Mozilla.ttf` is the unmodified font from
[Twemoji Mozilla v0.7.0](https://github.com/mozilla/twemoji-colr/releases/tag/v0.7.0),
using Twemoji 14 artwork. See `Twemoji-LICENSE.md` for licensing and attribution.

The weather item loads this font into SketchyBar at startup. No system-wide font
installation is required. Weather glyphs use `Twemoji Mozilla:Regular:15.0`;
temperature text uses `JetBrains Mono:Bold:15.0`.

The emoji slot has a fixed 20-point width because Core Text reports zero path
bounds for this font's COLR glyphs, which clips them under SketchyBar's automatic
text sizing.
