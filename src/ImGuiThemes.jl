module ImGuiThemes

using CImGui
using Colors
using Accessors
import TOML
import Libdl

export THEMES, apply_theme!, theme_picker, set_app_icon!, FONTS, font_path

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

# ---------------------------------------------------------------------------
# Geometry defaults — used by the picker to reset a style's geometry to imgui's
# built-ins before applying a theme, so the result never depends on what came before.
# ---------------------------------------------------------------------------

"Every imgui `ImGuiStyle` geometry field that some theme sets (camelCase → field name, valid fields only)."
const _GEOMETRY_FIELDS = sort!(unique!(
    [Symbol(uppercasefirst(string(k))) for t in THEMES for k in keys(t.style)
     if Symbol(uppercasefirst(string(k))) in _STYLE_FIELDS]))

"imgui's canonical default for each `_GEOMETRY_FIELDS` field; filled once by [`_ensure_defaults!`](@ref)."
const _DEFAULT_GEOMETRY = Dict{Symbol,Any}()

# Fill _DEFAULT_GEOMETRY once, from a freshly default-constructed ImGuiStyle (carries imgui's
# canonical geometry defaults, independent of the live style). Idempotent.
function _ensure_defaults!()
    isempty(_DEFAULT_GEOMETRY) || return
    s = CImGui.lib.ImGuiStyle()
    try
        for F in _GEOMETRY_FIELDS
            _DEFAULT_GEOMETRY[F] = unsafe_load(getproperty(s, F))
        end
    finally
        CImGui.lib.ImGuiStyle_destroy(s)
    end
    return
end

"Reset every geometry field to its captured imgui default (call [`_ensure_defaults!`](@ref) first)."
_reset_geometry!(style) = foreach(F -> setproperty!(style, F, _DEFAULT_GEOMETRY[F]), _GEOMETRY_FIELDS)

_styleval(v::Real)           = v                              # stored into a Cfloat field (converted at the boundary)
_styleval(v::AbstractVector) = CImGui.ImVec2(v[1], v[2])
_styleval(v::AbstractString) = getfield(CImGui, Symbol("ImGuiDir_", v))

_setcolor!(style, name::Symbol, c) =
    CImGui.c_set!(style.Colors, getfield(CImGui, Symbol("ImGuiCol_", name)),
                  CImGui.ImVec4(red(c), green(c), blue(c), alpha(c)))

"""
    apply!(theme, style = CImGui.GetStyle(); geometry = true)

Apply `theme` to an imgui `style` (a `Ptr{ImGuiStyle}`): reset to the matching dark/light
base, set the theme's geometry and colors (renaming the few old color names), then derive any
newer colors the theme didn't set itself from its palette. Returns `style`. With
`geometry = false` the theme's geometry fields are left untouched and only colors are applied.
"""
function apply!(t::Theme, style = CImGui.GetStyle(); geometry::Bool = true)
    mode(t) === :light ? CImGui.StyleColorsLight(style) : CImGui.StyleColorsDark(style)
    if geometry
        for (k, v) in t.style
            F = Symbol(uppercasefirst(string(k)))
            F in _STYLE_FIELDS && setproperty!(style, F, _styleval(v))
        end
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
its colors (tweaked live), whether the export text box is shown, and the selected font plus a
lazy cache of fonts already loaded into the atlas.
"""
mutable struct PickerState
    selected::Union{Nothing,String}
    colors::Dict{Symbol,RGBA{Float32}}   # editable working copy of the selected theme's colors
    show_export::Bool
    apply_geometry::Bool                 # picker: apply theme geometry (true) or colors only (false)
    font::Tuple{Symbol,Symbol}           # selected (family, variant); (:Default, :Regular) = imgui built-in
    fonts_loaded::Dict{Tuple{Symbol,Symbol},Ptr{CImGui.lib.ImFont}}   # (family, variant) => font ptr, lazy
end
# Convenience ctor (PickerState is internal): geometry on, no font selected, empty font cache.
PickerState(selected, colors, show_export, apply_geometry = true) =
    PickerState(selected, colors, show_export, apply_geometry, (:Default, :Regular), Dict{Tuple{Symbol,Symbol},Ptr{CImGui.lib.ImFont}}())

const _picker_state = PickerState(nothing, Dict{Symbol,RGBA{Float32}}(), false, true)

"""
    theme_picker(; window = true, title = "ImGui Themes", state = _picker_state, fonts = true)

Draw a font selector (a row of radio buttons over the bundled [`FONTS`](@ref), picked one shown
first) followed by the themes as radio buttons (one click, no dropdown), split into two bordered
groups — dark and light — that each wrap to the window width. Selecting a theme applies it live;
selecting a font downloads it on first use and sets it as the global default. With `window = true`
(default) it renders in its own imgui window, so a single call anywhere in an app shows a standalone
browser; with `window = false` it draws inline. Pass `fonts = false` to hide the font selector.
Must be called inside an active imgui frame. Returns the currently-selected theme name (or `nothing`).
"""
function theme_picker(; window::Bool = true, title::AbstractString = "ImGui Themes", state::PickerState = _picker_state, fonts::Bool = true)
    opened = window ? CImGui.Begin(title) : true
    if opened
        fonts && _font_selector(state)
        geom = Ref(state.apply_geometry)
        if CImGui.Checkbox("Apply geometry", geom)
            state.apply_geometry = geom[]
            isnothing(state.selected) || _apply_working(state)
        end
        CImGui.SameLine()
        CImGui.TextDisabled("(* = also sets geometry)")
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

"True if `t` sets any imgui geometry field (so the picker marks it with ` *`)."
_has_geometry(t::Theme) = !isempty(t.style)

"Radio label for `t`: its name, suffixed with ` *` when it also sets geometry."
_label(t::Theme) = _has_geometry(t) ? "$(t.name) *" : t.name

# Radio buttons that wrap to the current content width (imgui's buttons-wrap pattern).
# `on_select(i)` handles a click on item i (first arg, so callers can use do-syntax);
# `labels` are the display strings; `is_selected(i)` marks the active item.
function _wrapping_radios(on_select, labels, is_selected)
    style = CImGui.GetStyle()
    spacing = unsafe_load(style.ItemSpacing).x
    inner = unsafe_load(style.ItemInnerSpacing).x
    frame_h = CImGui.GetFrameHeight()
    right_x = CImGui.GetCursorScreenPos().x + CImGui.GetContentRegionAvail().x
    radio_width(label) = frame_h + inner + CImGui.CalcTextSize(label).x
    for (i, label) in enumerate(labels)
        CImGui.RadioButton(label, is_selected(i)) && on_select(i)
        if i < length(labels)  # keep the next button on this line only if it fits
            next_x = CImGui.GetItemRectMax().x + spacing + radio_width(labels[i + 1])
            next_x < right_x && CImGui.SameLine()
        end
    end
end

function _theme_radios(ts, state::PickerState)
    _wrapping_radios([_label(t) for t in ts], i -> state.selected == ts[i].name) do i
        t = ts[i]
        state.selected = t.name
        state.colors = copy(t.colors)   # fresh editable copy (RGBA is immutable)
        _apply_picked!(state, t)
    end
end

# Font selector: a family row, then (if the picked family has >1 variant) a Style row of its
# variants. Families and variants are derived from keys(FONTS), sorted alphabetically. On selection
# the font is downloaded on first use, added to the atlas (cached in state.fonts_loaded), and set as
# the global default so it applies everywhere next frame (dynamic fonts, Dear ImGui >= 1.92).
_font_families() = sort(unique(fam for (fam, _) in keys(FONTS)))
_font_variants(fam) = sort([var for (f, var) in keys(FONTS) if f === fam])

function _font_selector(state::PickerState)
    CImGui.SeparatorText("Font")
    fams = [:Default; _font_families()]
    _wrapping_radios([string(f) for f in fams], i -> state.font[1] === fams[i]) do i
        _select_font!(state, fams[i], :Regular)   # picking a family resets to its Regular
    end
    fam = state.font[1]
    if fam !== :Default
        vars = _font_variants(fam)
        if length(vars) > 1
            CImGui.SeparatorText("Style")
            _wrapping_radios([string(v) for v in vars], i -> state.font[2] === vars[i]) do i
                _select_font!(state, fam, vars[i])
            end
        end
    end
end

function _select_font!(state::PickerState, fam::Symbol, var::Symbol)
    state.font = (fam, var)
    ptr = fam === :Default ? C_NULL :
          get!(() -> CImGui.AddFontFromFileTTF(FONTS[(fam, var)]), state.fonts_loaded, (fam, var))
    CImGui.GetIO().FontDefault = ptr
end

# Canonical imgui color order (by ImGuiCol_ index) — shared by the editor list and export.
_color_order(colors) = sort!(collect(keys(colors)); by = k -> getfield(CImGui, Symbol("ImGuiCol_", get(COLOR_RENAME, k, k))))

# The picker's apply path. With apply_geometry = true, first reset every geometry field to imgui
# defaults (so the result never depends on the previously-applied theme), then apply geometry +
# colors via apply!. With apply_geometry = false, geometry is left untouched (colors only).
function _apply_picked!(state::PickerState, t::Theme, style = CImGui.GetStyle())
    if state.apply_geometry
        _ensure_defaults!()
        _reset_geometry!(style)
    end
    apply!(t, style; geometry = state.apply_geometry)
end

# Apply the selected theme with the working colors swapped in — through the picker path so the
# geometry reset / colors-only flag and the color renames + NEW_COLOR_FROM derivations all apply.
function _apply_working(state::PickerState, style = CImGui.GetStyle())
    base = theme(state.selected)
    _apply_picked!(state, (@set base.colors = state.colors), style)
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

include("app_icon.jl")
include("fonts.jl")

end # module
