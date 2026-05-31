module ImGuiThemes

using CImGui
using Colors
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

"All themes from the vendored ImThemes database, in file order."
const THEMES = [_parse_theme(d) for d in TOML.parsefile(_DATA)["themes"]]

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
base, set the theme's geometry and colors (renaming the few old color names), then derive the
newer colors ImThemes lacks from the theme's palette. Returns `style`.
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

const _picker_state = Ref{Union{Nothing,String}}(nothing)

"""
    theme_picker(; window = true, title = "ImGui Themes", state = _picker_state)

Draw all themes as radio buttons that wrap to the window width; selecting one applies it
live (one click, no dropdown). With `window = true` (default) it renders in its own imgui
window, so a single call anywhere in an app shows a standalone theme browser; with
`window = false` it draws the buttons inline. Must be called inside an active imgui frame.
Returns the currently-selected theme name (or `nothing`).
"""
function theme_picker(; window::Bool = true, title::AbstractString = "ImGui Themes", state::Ref = _picker_state)
    opened = window ? CImGui.Begin(title) : true
    if opened
        style = CImGui.GetStyle()
        spacing = unsafe_load(style.ItemSpacing).x
        inner = unsafe_load(style.ItemInnerSpacing).x
        frame_h = CImGui.GetFrameHeight()
        right_x = CImGui.GetCursorScreenPos().x + CImGui.GetContentRegionAvail().x
        radio_width(name) = frame_h + inner + CImGui.CalcTextSize(name).x
        for (i, t) in enumerate(THEMES)
            if CImGui.RadioButton(t.name, state[] == t.name)
                state[] = t.name
                apply_theme!(t.name)
            end
            if i < length(THEMES)  # keep the next button on this line only if it fits
                next_x = CImGui.GetItemRectMax().x + spacing + radio_width(THEMES[i + 1].name)
                next_x < right_x && CImGui.SameLine()
            end
        end
    end
    window && CImGui.End()
    state[]
end

end # module
