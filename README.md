# ImGuiThemes.jl

Ready-to-apply [Dear ImGui](https://github.com/ocornut/imgui) themes for
[CImGui.jl](https://github.com/JuliaImGui/CImGui.jl): the ~47 dark and light themes from the
[ImThemes](https://github.com/Patitotective/ImThemes) community database, plus curated palette
themes (e.g. Solarized) — colors **and** geometry.

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

A `Theme` is callable, and you can target a specific style object:

```julia
ImGuiThemes.theme("Nord")(CImGui.GetStyle())
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
# one-time setup (from the repo root):
julia --project=examples -e 'import Pkg; Pkg.develop(path="."); Pkg.instantiate()'
julia --project=examples examples/theme_picker_demo.jl
```

## How it works

Themes come from a vendored copy of ImThemes' `themes.toml`, parsed at load into `THEMES`.
Colors are [Colors.jl](https://github.com/JuliaGraphics/Colors.jl) colorants. `apply!` resets
to the matching dark/light base, applies the theme's geometry and colors (renaming the few
color names imgui has changed since), then derives the newer imgui colors ImThemes predates
from the theme's own palette — using imgui's own derivation rules. Targets current imgui
(CImGui 7 / imgui 1.92). Curated themes (Solarized, …) are hand-built `Theme` values, one Julia
file each under [`src/themes/`](src/themes), appended to the same `THEMES`.

## Attribution

Themes are from [Patitotective/ImThemes](https://github.com/Patitotective/ImThemes)
(MIT, © 2022 Patitotective) — see [`data/imthemes-LICENSE`](data/imthemes-LICENSE). Each
theme keeps its original `author`. Thanks to all the theme authors and to ImThemes.
