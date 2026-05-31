module ImGuiThemes

using CImGui
using Colors
using Accessors
import TOML

export THEMES, apply_theme!, theme_picker

# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

"""
    Theme

One ImThemes entry: metadata plus the imgui `style` geometry fields and `colors`
palette. A `Theme` value is callable: `t(style = CImGui.GetStyle())` applies it (see [`apply!`](@ref)).
"""
struct Theme
    name::String
    author::String
    description::String
    tags::Vector{String}
    date::String
    style::Dict{Symbol,Any}              # camelCase field => Float64 | Vector{Float64} | String (enum)
    colors::Dict{Symbol,RGBA{Float32}}   # ImThemes color key => colorant
end

"Keyword constructor for hand-written (curated) themes; colors-only by default."
Theme(; name, author = "", description = "", tags, date = "", style = Dict{Symbol,Any}(), colors) =
    Theme(name, author, description, tags, date, style, colors)

"`:light` if the theme is tagged light, else `:dark` — picks the base preset."
mode(t::Theme) = "light" in t.tags ? :light : :dark

# ---------------------------------------------------------------------------
# Lookup tables (target current imgui / CImGui 7 — no backward compatibility)
# ---------------------------------------------------------------------------

"ImThemes' (older-imgui) color names that imgui has since renamed → current name."
const COLOR_RENAME = Dict(
    :TabActive          => :TabSelected,        # imgui 1.90.9
    :TabUnfocused       => :TabDimmed,          # imgui 1.90.9
    :TabUnfocusedActive => :TabDimmedSelected,  # imgui 1.90.9
    :NavHighlight       => :NavCursor,          # imgui 1.91.4
)

"""
Newer imgui colors that ImThemes never specifies → `(theme color to derive from, alpha factor)`.
Transcribed from imgui's own `StyleColorsDark` derivations so they stay coherent with the
theme's palette. The other new colors are fixed/transparent literals and keep their base value.
"""
const NEW_COLOR_FROM = Dict(
    :InputTextCursor     => (:Text,         1.0f0),
    :TabSelectedOverline => (:HeaderActive, 1.0f0),
    :TextLink            => (:HeaderActive, 1.0f0),
    :DockingPreview      => (:HeaderActive, 0.7f0),
    :TreeLines           => (:Border,       1.0f0),
)

# ---------------------------------------------------------------------------
# Parsing — vendored ImThemes database (MIT, © Patitotective), parsed at load
# ---------------------------------------------------------------------------

const _DATA = joinpath(@__DIR__, "..", "data", "imthemes.toml")
include_dependency(_DATA)

function _parse_theme(d)
    sty = d["style"]
    style  = Dict{Symbol,Any}(Symbol(k) => v for (k, v) in sty if k != "colors")
    colors = Dict{Symbol,RGBA{Float32}}(Symbol(k) => parse(RGBA{Float32}, v) for (k, v) in sty["colors"])
    Theme(d["name"], get(d, "author", ""), get(d, "description", ""),
          string.(get(d, "tags", String[])), string(get(d, "date", "")), style, colors)
end

# ---------------------------------------------------------------------------
# Curated palette themes — one self-contained file per theme under src/themes/
# ---------------------------------------------------------------------------

const _CURATED = Theme[]   # each src/themes/*.jl push!es its Theme(s) here

"`withα(c, a)` → color `c` with its alpha replaced by `a` (for hover/active state colors)."
withα(c, a) = RGBA{Float32}(red(c), green(c), blue(c), Float32(a))

include("themes/solarized.jl")
include("themes/spectrum.jl")
include("themes/light_rounded.jl")
include("themes/white_is_white.jl")
include("themes/dougbinks_light.jl")
include("themes/paper_and_ink.jl")

# ---------------------------------------------------------------------------
# ktsu ThemeProvider themes — generated from seed palettes by the ported engine
# (src/ktsu/engine.jl). Defs vendored in data/ktsu_themes.toml (MIT, ktsu-dev).
# ---------------------------------------------------------------------------

include("ktsu/engine.jl")

const _KTSU_DATA = joinpath(@__DIR__, "..", "data", "ktsu_themes.toml")
include_dependency(_KTSU_DATA)

"Build one ktsu theme from a parsed `[[themes]]` toml entry: role-name strings → `SemanticMeaning`, hex strings → colorants."
function _ktsu_from_toml(d)
    roles = Dict(getfield(@__MODULE__, Symbol(role)) => [parse(RGBA{Float32}, h) for h in hexes]
                 for (role, hexes) in d["roles"])
    _ktsu_theme(; name = d["name"], author = get(d, "author", "ktsu-dev"), isdark = d["isDark"], roles)
end

const _KTSU = [_ktsu_from_toml(d) for d in TOML.parsefile(_KTSU_DATA)["themes"]]

"All themes — curated palette themes, then ktsu engine themes, then the vendored ImThemes database."
const THEMES = [_CURATED; _KTSU; [_parse_theme(d) for d in TOML.parsefile(_DATA)["themes"]]]

"`theme(name)` → the [`Theme`](@ref) with that name (`KeyError` if absent)."
function theme(name::AbstractString)
    i = findfirst(t -> t.name == name, THEMES)
    isnothing(i) && throw(KeyError(name))
    THEMES[i]
end

# ---------------------------------------------------------------------------
# Apply — mutate an imgui style in place
# ---------------------------------------------------------------------------

const _STYLE_FIELDS = Set(fieldnames(CImGui.lib.ImGuiStyle))

_styleval(v::Real)           = v                              # stored into a Cfloat field (converted at the boundary)
_styleval(v::AbstractVector) = CImGui.ImVec2(v[1], v[2])
_styleval(v::AbstractString) = getfield(CImGui, Symbol("ImGuiDir_", v))

_setcolor!(style, name::Symbol, c) =
    CImGui.c_set!(style.Colors, getfield(CImGui, Symbol("ImGuiCol_", name)),
                  CImGui.ImVec4(red(c), green(c), blue(c), alpha(c)))

"""
    apply!(theme, style = CImGui.GetStyle())

Apply `theme` to an imgui `style` (a `Ptr{ImGuiStyle}`): reset to the matching dark/light
base, set the theme's geometry and colors (renaming the few old color names), then derive any
newer colors the theme didn't set itself from its palette. Returns `style`.
"""
function apply!(t::Theme, style = CImGui.GetStyle())
    mode(t) === :light ? CImGui.StyleColorsLight(style) : CImGui.StyleColorsDark(style)
    for (k, v) in t.style
        F = Symbol(uppercasefirst(string(k)))
        F in _STYLE_FIELDS && setproperty!(style, F, _styleval(v))
    end
    for (key, c) in t.colors
        _setcolor!(style, get(COLOR_RENAME, key, key), c)
    end
    for (new, (src, αf)) in NEW_COLOR_FROM
        haskey(t.colors, new) && continue  # theme set this newer color explicitly → keep it
        c = t.colors[src]
        _setcolor!(style, new, RGBA{Float32}(red(c), green(c), blue(c), alpha(c) * αf))
    end
    style
end

(t::Theme)(style = CImGui.GetStyle()) = apply!(t, style)

"`apply_theme!(name, style = CImGui.GetStyle())` — apply the named theme."
apply_theme!(name::AbstractString, style = CImGui.GetStyle()) = apply!(theme(name), style)

# ---------------------------------------------------------------------------
# Live picker
# ---------------------------------------------------------------------------

"""
Mutable state for [`theme_picker`](@ref): the selected theme name, an editable working copy of
its colors (tweaked live), and whether the export text box is shown.
"""
mutable struct PickerState
    selected::Union{Nothing,String}
    colors::Dict{Symbol,RGBA{Float32}}   # editable working copy of the selected theme's colors
    show_export::Bool
end
const _picker_state = PickerState(nothing, Dict{Symbol,RGBA{Float32}}(), false)

"""
    theme_picker(; window = true, title = "ImGui Themes", state = _picker_state)

Draw the themes as radio buttons (one click, no dropdown), split into two bordered groups —
dark and light — that each wrap to the window width. Selecting one applies it live. With
`window = true` (default) it renders in its own imgui window, so a single call anywhere in an
app shows a standalone theme browser; with `window = false` it draws inline. Must be called
inside an active imgui frame. Returns the currently-selected theme name (or `nothing`).
"""
function theme_picker(; window::Bool = true, title::AbstractString = "ImGui Themes", state::PickerState = _picker_state)
    opened = window ? CImGui.Begin(title) : true
    if opened
        _theme_group("Dark", :dark, state)
        _theme_group("Light", :light, state)
        isnothing(state.selected) || _color_editors(state)
    end
    window && CImGui.End()
    state.selected
end

# One bordered, auto-height child per mode, holding that mode's wrapping radio buttons.
function _theme_group(title, m::Symbol, state::PickerState)
    flags = CImGui.ImGuiChildFlags_Borders | CImGui.ImGuiChildFlags_AutoResizeY
    if CImGui.BeginChild(title, CImGui.ImVec2(0, 0), flags)
        CImGui.SeparatorText(title)
        _theme_radios([t for t in THEMES if mode(t) === m], state)
    end
    CImGui.EndChild()
end

# Radio buttons that wrap to the current content width (imgui's buttons-wrap pattern).
function _theme_radios(ts, state::PickerState)
    style = CImGui.GetStyle()
    spacing = unsafe_load(style.ItemSpacing).x
    inner = unsafe_load(style.ItemInnerSpacing).x
    frame_h = CImGui.GetFrameHeight()
    right_x = CImGui.GetCursorScreenPos().x + CImGui.GetContentRegionAvail().x
    radio_width(name) = frame_h + inner + CImGui.CalcTextSize(name).x
    for (i, t) in enumerate(ts)
        if CImGui.RadioButton(t.name, state.selected == t.name)
            state.selected = t.name
            state.colors = copy(t.colors)   # fresh editable copy (RGBA is immutable)
            apply!(t)
        end
        if i < length(ts)  # keep the next button on this line only if it fits
            next_x = CImGui.GetItemRectMax().x + spacing + radio_width(ts[i + 1].name)
            next_x < right_x && CImGui.SameLine()
        end
    end
end

# Canonical imgui color order (by ImGuiCol_ index) — shared by the editor list and export.
_color_order(colors) = sort!(collect(keys(colors)); by = k -> getfield(CImGui, Symbol("ImGuiCol_", get(COLOR_RENAME, k, k))))

# Apply the selected theme with the working colors swapped in — through apply! so renames,
# geometry and NEW_COLOR_FROM derivations stay coherent with the tweaked palette.
function _apply_working(state::PickerState)
    base = theme(state.selected)
    apply!(@set base.colors = state.colors)
end

"""
    export_string(colors)

Minimal, pasteable `Dict(:Key => colorant"#RRGGBBAA", …)` representation of a color dict, in
canonical imgui order. 8-digit hex always carries alpha and round-trips via `colorant`/`parse`.
"""
function export_string(colors)
    ks = _color_order(colors)
    w = maximum(length ∘ string, ks)
    body = join(("  :$(rpad(string(k), w)) => colorant\"#$(hex(colors[k]))\"," for k in ks), "\n")
    "Dict(\n$body\n)"
end

# Editable swatch per color plus Reset/Export, drawn below the theme groups.
function _color_editors(state::PickerState)
    CImGui.SeparatorText("Colors")
    if CImGui.Button("Reset")
        state.colors = copy(theme(state.selected).colors)
        _apply_working(state)
    end
    CImGui.SameLine()
    CImGui.Button("Export") && (state.show_export = !state.show_export)
    if state.show_export
        buf = push!(Vector{UInt8}(export_string(state.colors)), 0x00)   # NUL-terminated, rebuilt each frame
        CImGui.InputTextMultiline("##export", buf, length(buf), CImGui.ImVec2(-1, 200), CImGui.ImGuiInputTextFlags_ReadOnly)
    end
    # NoInputs → just a labeled color swatch; the R/G/B/A inputs + alpha bar open in the click popup.
    flags = CImGui.ImGuiColorEditFlags_NoInputs | CImGui.ImGuiColorEditFlags_AlphaBar
    for key in _color_order(state.colors)
        c = state.colors[key]
        col = Cfloat[red(c), green(c), blue(c), alpha(c)]
        if CImGui.ColorEdit4(string(key), col, flags)
            state.colors[key] = RGBA{Float32}(col...)
            _apply_working(state)
        end
    end
end

end # module
