# ---------------------------------------------------------------------------
# ktsu ThemeProvider engine — Julia port (on Colors.jl's Oklab)
# ---------------------------------------------------------------------------
#
# Ports ktsu.dev's ThemeProvider palette→Dear-ImGui mapper (MIT,
# https://github.com/ktsu-dev/ThemeProvider). A theme is a small seed palette
# assigned to abstract semantic roles; a two-stage engine turns it into a full
# imgui color set:
#
#   Stage A (`_KTSU_SLOTS`): ImGuiCol name → (SemanticMeaning, Priority)
#                            — from ImGuiPaletteMapper.MapTheme.
#   Stage B (`_ktsu_make_palette`): place each role's seed color(s) at a target
#                            Oklab lightness — from MakeCompletePalette.
#
# Color math reuses Colors.jl's `Oklab`; out-of-gamut results are clamped by the
# RGB conversion. (ktsu's own code skips the sRGB transfer; Colors applies it, so
# colors are close to — not bit-identical with — ktsu's, which is fine here.)

@enum SemanticMeaning::Int begin
    Neutral = 0
    Primary
    Alternate
    Success
    CallToAction
    Information
    Caution
    Warning
    Error
    Failure
    Debug
end

@enum Priority::Int begin
    VeryLow = 0
    Low
    MediumLow
    Medium
    MediumHigh
    High
    VeryHigh
end

# Stage A — ImGuiCol(Symbol) => (SemanticMeaning, Priority), verbatim from
# ThemeProvider.ImGui/ImGuiPaletteMapper.cs (current imgui 1.92 color names).
const _KTSU_SLOTS = Dict{Symbol,Tuple{SemanticMeaning,Priority}}(
    :WindowBg              => (Neutral,   VeryLow),
    :ChildBg               => (Neutral,   Low),
    :PopupBg               => (Neutral,   Low),
    :MenuBarBg             => (Neutral,   Low),
    :FrameBg               => (Neutral,   MediumLow),
    :FrameBgHovered        => (Neutral,   Medium),
    :FrameBgActive         => (Neutral,   MediumHigh),
    :TextDisabled          => (Neutral,   High),
    :Text                  => (Neutral,   VeryHigh),
    :ScrollbarBg           => (Neutral,   Low),
    :ScrollbarGrab         => (Neutral,   Medium),
    :ScrollbarGrabHovered  => (Neutral,   MediumHigh),
    :ScrollbarGrabActive   => (Neutral,   High),
    :Button                => (Primary,   Medium),
    :ButtonHovered         => (Primary,   High),
    :ButtonActive          => (Primary,   VeryHigh),
    :Header                => (Primary,   Medium),
    :HeaderHovered         => (Primary,   High),
    :HeaderActive          => (Primary,   VeryHigh),
    :CheckMark             => (Primary,   High),
    :ResizeGrip            => (Neutral,   MediumHigh),
    :ResizeGripHovered     => (Neutral,   High),
    :ResizeGripActive      => (Neutral,   VeryHigh),
    :NavWindowingHighlight => (Primary,   VeryHigh),
    :SliderGrab            => (Primary,   MediumLow),
    :SliderGrabActive      => (Primary,   High),
    :Separator             => (Neutral,   MediumHigh),
    :SeparatorHovered      => (Neutral,   High),
    :SeparatorActive       => (Neutral,   VeryHigh),
    :Tab                   => (Neutral,   Medium),
    :TabSelected           => (Primary,   Medium),
    :TabHovered            => (Primary,   High),
    :PlotLines             => (Alternate, Medium),
    :PlotLinesHovered      => (Alternate, High),
    :PlotHistogram         => (Alternate, Medium),
    :PlotHistogramHovered  => (Alternate, High),
    :TableHeaderBg         => (Neutral,   Medium),
    :TableBorderStrong     => (Neutral,   Medium),
    :TableBorderLight      => (Neutral,   Medium),
    :TableRowBg            => (Neutral,   VeryLow),
    :TableRowBgAlt         => (Neutral,   Low),
    :TextSelectedBg        => (Alternate, High),
    :TitleBg               => (Neutral,   Medium),
    :TitleBgActive         => (Primary,   Medium),
    :TitleBgCollapsed      => (Neutral,   MediumLow),
    :Border                => (Neutral,   Medium),
    :BorderShadow          => (Neutral,   Low),
)

# ---------------------------------------------------------------------------
# Stage B — place a role's seeds at the target Oklab lightness for each priority
# ---------------------------------------------------------------------------

# a seed color shifted to a given Oklab lightness (keeping its hue/chroma); the RGB conversion clamps to gamut
_at_lightness(seed::Oklab, target::Real) = convert(RGB{Float32}, @set seed.l = target)

# the role's seed color(s) evaluated at `target` lightness (interpolate within range, extrapolate outside)
function _color_at_lightness(seeds::Vector{Oklab{Float32}}, target::Float32)
    s = sort(seeds; by = c -> c.l)
    target ≤ first(s).l && return _at_lightness(first(s), target)
    target ≥ last(s).l  && return _at_lightness(last(s), target)
    j = findfirst(i -> target ≤ s[i + 1].l, eachindex(s)[1:end-1])
    lo, hi = s[j], s[j + 1]
    t = (target - lo.l) / (hi.l - lo.l)
    convert(RGB{Float32}, weighted_color_mean(1 - t, lo, hi))
end

# CalculateTargetLightnessForSemantic: neutrals span the seeds' full lightness
# range; accents compress to a 0.5–0.9 sub-band. Light themes run the priority
# scale bright→dark, dark themes dark→bright.
function _target_lightness(priority::Priority, meaning::SemanticMeaning, gmin::Float32, gmax::Float32, isdark::Bool)
    n = length(instances(Priority))
    n == 1 && return (gmin + gmax) / 2f0
    pos = Float32(Int(priority)) / (n - 1)
    minL, maxL = meaning == Neutral ? (gmin, gmax) :
                 (gmin + (gmax - gmin) * 0.5f0, gmin + (gmax - gmin) * 0.9f0)
    clamp(isdark ? minL + pos * (maxL - minL) : maxL - pos * (maxL - minL), 0f0, 1f0)
end

"""
    _ktsu_make_palette(seeds_by_meaning, isdark)

Stage B. For every `(meaning, priority)` of the meanings present, place that
role's seeds at the priority's target Oklab lightness. Returns
`Dict{Tuple{SemanticMeaning,Priority},RGBA{Float32}}` (alpha 1).
"""
function _ktsu_make_palette(seeds_by_meaning, isdark::Bool)
    ls = [c.l for c in Iterators.flatten(values(seeds_by_meaning))]
    gmin, gmax = isempty(ls) ? (0f0, 1f0) : extrema(ls)
    out = Dict{Tuple{SemanticMeaning,Priority},RGBA{Float32}}()
    for (meaning, seeds) in seeds_by_meaning, priority in instances(Priority)
        isempty(seeds) && continue
        rgb = _color_at_lightness(seeds, _target_lightness(priority, meaning, gmin, gmax, isdark))
        out[(meaning, priority)] = RGBA{Float32}(rgb)
    end
    out
end

"""
    _ktsu_theme(; name, author="", isdark, roles)

Build a [`Theme`](@ref) with the ktsu engine. `roles::AbstractDict{SemanticMeaning,<:AbstractVector{<:Colorant}}`
gives the seed colors per role. Runs Stage B, then resolves each `_KTSU_SLOTS`
entry's `(meaning, priority)` to a color. `tags = [isdark ? "dark" : "light"]`.
"""
function _ktsu_theme(; name::AbstractString, author::AbstractString = "", isdark::Bool, roles)
    seeds = Dict(m => convert.(Oklab{Float32}, cs) for (m, cs) in roles)
    palette = _ktsu_make_palette(seeds, isdark)
    colors = Dict{Symbol,RGBA{Float32}}(slot => palette[key] for (slot, key) in _KTSU_SLOTS if haskey(palette, key))
    Theme(; name, author, tags = [isdark ? "dark" : "light"], colors)
end
