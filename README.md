# ImGuiThemes.jl

Ready-to-apply [Dear ImGui](https://github.com/ocornut/imgui) themes for
[CImGui.jl](https://github.com/JuliaImGui/CImGui.jl): ~93 dark and light themes from
multiple sources.

## Usage

Apply a theme by name to the current imgui style (call once, e.g. during setup):

```julia
using ImGuiThemes
ImGuiThemes.apply_theme!("Cherry")        # or "Dracula", "Nord", "Photoshop", ...
```

Browse what's available:

```julia
THEMES                                     # Vector of all themes
[t.name for t in THEMES]                    # their names
ImGuiThemes.theme("Cherry")                 # one Theme (has .author, .tags, .colors, .style)
```

### Live picker

Drop this single call anywhere inside your imgui frame and it shows a standalone window with
two bordered groups — dark and light — of radio buttons (one per theme, wrapping to the
window width) to switch themes in one click:

```julia
ImGuiThemes.theme_picker()                  # window = true by default
ImGuiThemes.theme_picker(; window = false)  # or render the buttons inline
```

### Demo

A runnable demo opens a real window with the picker next to imgui's demo window:

```bash
julia --project=examples examples/theme_picker_demo.jl
```

## Theme sources

The catalogue (~93 themes, ≈22 light) is assembled from three sources:

**ImThemes** (47 themes) — the community database from
[Patitotective/ImThemes](https://github.com/Patitotective/ImThemes) (MIT, © 2022 Patitotective),
vendored in `data/imthemes.toml`. Each theme keeps its original `author`.

**Curated hand-authored themes** (8 themes, in `src/themes/`) — imgui-native Julia files, each
transcribed or ported from a known upstream source:
- **Solarized** Light & Dark — palette by Ethan Schoonover
- **Spectrum** Light & Dark — Adobe Design System palette
- **Light Rounded** & **White is White** — Pascal Thomet / [HelloImGui](https://github.com/pthom/hello_imgui) (MIT)
- **Doug Binks Light** — Doug Binks / Pacôme Danhiez
- **Paper and Ink** — TheAncientOwl ([imgui issue #707](https://github.com/ocornut/imgui/issues/707#issuecomment-4107169777))

**ktsu themes** (38 themes) — Catppuccin, Gruvbox, Everforest, Tokyo Night, Nord, Dracula, and
more, generated at load time by a Julia port of
[ktsu-dev/ThemeProvider](https://github.com/ktsu-dev/ThemeProvider)'s palette→imgui engine
(`src/ktsu/engine.jl`). Seed palettes are vendored in `data/ktsu_themes.toml`
(MIT, © ktsu-dev — see [`data/ktsu-LICENSE`](data/ktsu-LICENSE)).

