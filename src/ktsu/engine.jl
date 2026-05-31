# ---------------------------------------------------------------------------
# ktsu ThemeProvider engine — faithful Julia port
# ---------------------------------------------------------------------------
#
# Ports ktsu.dev's ThemeProvider palette→Dear-ImGui color mapper
# (https://github.com/ktsu-dev/ThemeProvider, MIT). A theme is a small seed
# palette assigned to abstract semantic roles; a two-stage engine turns it into
# a full imgui color set:
#
#   Stage A (`_KTSU_SLOTS`): ImGuiCol name → (SemanticMeaning, Priority).
#                            Verbatim translation of ImGuiPaletteMapper.MapTheme.
#   Stage B (`_ktsu_make_palette`): for every (meaning, priority), spread the
#                            role's seed color(s) across an Oklab lightness band
#                            (SemanticColorMapper.MakeCompletePalette).
#
# IMPORTANT FIDELITY NOTE — gamma handling:
#   ktsu's `RgbColor.FromHex` does `byte/255` with NO sRGB→linear conversion, and
#   feeds those values straight into the Oklab matrices (and back). It is therefore
#   colorimetrically "wrong" (it Oklab-transforms gamma-encoded values), but to
#   reproduce ktsu's exact numbers we MUST do the same. Hence this file implements
#   the raw Oklab matrix math directly on 0..1 sRGB-encoded values and does NOT use
#   Colors.jl's `Oklab`/`Oklch` (which correctly apply the sRGB transfer function and
#   would give different results). All arithmetic mirrors C# `float` math.

# ---------------------------------------------------------------------------
# Enums (match ktsu SemanticMeaning.cs / Priority.cs, in declaration order)
# ---------------------------------------------------------------------------

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

const _KTSU_PRIORITIES = (VeryLow, Low, MediumLow, Medium, MediumHigh, High, VeryHigh)

# ---------------------------------------------------------------------------
# Stage A — ImGuiCol(Symbol) => (SemanticMeaning, Priority)
# Verbatim from ThemeProvider.ImGui/ImGuiPaletteMapper.cs `colorMapping`.
# imgui color names are current (1.92) names, as used by the rest of the package.
# ---------------------------------------------------------------------------

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
# Oklab color math — verbatim ports of ktsu ColorMath.cs / OklabColor.cs.
# Float32 throughout, matching C# `float`. NO sRGB gamma (see note above).
# ---------------------------------------------------------------------------

# An Oklab triple stored as (L, a, b) in Float32.
struct _Oklab
    L::Float32
    A::Float32
    B::Float32
end

# signed cube root, matching C#'s `Math.Sign(x) * Math.Pow(Math.Abs(x), 1/3)`.
_signcbrt(x::Float32)::Float32 = Float32(sign(x) * abs(Float64(x))^(1f0 / 3f0))

# ColorMath.RgbToOklab — input is the raw 0..1 (sRGB-encoded) rgb, treated as "linear".
function _rgb_to_oklab(r::Float32, g::Float32, b::Float32)::_Oklab
    l = 0.4122214708f0 * r + 0.5363325363f0 * g + 0.0514459929f0 * b
    m = 0.2119034982f0 * r + 0.6806995451f0 * g + 0.1073969566f0 * b
    s = 0.0883024619f0 * r + 0.2817188376f0 * g + 0.6299787005f0 * b
    l_ = _signcbrt(l); m_ = _signcbrt(m); s_ = _signcbrt(s)
    _Oklab(
        0.2104542553f0 * l_ + 0.7936177850f0 * m_ - 0.0040720468f0 * s_,
        1.9779984951f0 * l_ - 2.4285922050f0 * m_ + 0.4505937099f0 * s_,
        0.0259040371f0 * l_ + 0.7827717662f0 * m_ - 0.8086757660f0 * s_,
    )
end

# ColorMath.OklabToRgb — returns raw (possibly out-of-[0,1]) rgb, no gamma applied.
function _oklab_to_rgb(c::_Oklab)::NTuple{3,Float32}
    l_ = c.L + 0.3963377774f0 * c.A + 0.2158037573f0 * c.B
    m_ = c.L - 0.1055613458f0 * c.A - 0.0638541728f0 * c.B
    s_ = c.L - 0.0894841775f0 * c.A - 1.2914855480f0 * c.B
    l = l_ * l_ * l_; m = m_ * m_ * m_; s = s_ * s_ * s_
    (
        4.0767416621f0 * l - 3.3077115913f0 * m + 0.2309699292f0 * s,
        -1.2684380046f0 * l + 2.6097574011f0 * m - 0.3413193965f0 * s,
        -0.0041960863f0 * l - 0.7034186147f0 * m + 1.7076147010f0 * s,
    )
end

# OklabColor.Lerp
_oklab_lerp(from::_Oklab, to::_Oklab, t::Float32)::_Oklab =
    _Oklab((from.L * (1f0 - t)) + (to.L * t),
           (from.A * (1f0 - t)) + (to.A * t),
           (from.B * (1f0 - t)) + (to.B * t))

_in_gamut(rgb::NTuple{3,Float32})::Bool =
    all(0f0 .<= rgb .<= 1f0)

_clamp01(x::Float32)::Float32 = max(0f0, min(x, 1f0))
_clamp_rgb(rgb::NTuple{3,Float32})::NTuple{3,Float32} = map(_clamp01, rgb)

# ---------------------------------------------------------------------------
# Stage B — SemanticColorMapper.cs
# ---------------------------------------------------------------------------

# A seed color, carrying its Oklab value and lightness (PerceptualColor).
struct _Seed
    oklab::_Oklab
    lightness::Float32
end
_seed(rgb::NTuple{3,Float32}) = (o = _rgb_to_oklab(rgb...); _Seed(o, o.L))

# CalculateGlobalLightnessRange: min/max Oklab L over ALL seed colors of ALL roles.
function _global_lightness_range(seeds_by_meaning)::Tuple{Float32,Float32}
    lightnesses = [sd.lightness for sd in Iterators.flatten(values(seeds_by_meaning))]
    isempty(lightnesses) && return (0f0, 1f0)
    extrema(lightnesses)
end

# CalculateTargetLightnessForSemantic
function _target_lightness(priority::Priority, meaning::SemanticMeaning,
                           gmin::Float32, gmax::Float32, isdark::Bool)::Float32
    n = length(_KTSU_PRIORITIES)
    pidx = findfirst(==(priority), _KTSU_PRIORITIES) - 1   # 0-based, matches Array.IndexOf
    if n == 1
        return (gmin + gmax) / 2f0
    end
    position = Float32(pidx) / Float32(n - 1)
    if meaning == Neutral
        minL, maxL = gmin, gmax
    else
        grange = gmax - gmin
        minL = gmin + grange * 0.5f0
        maxL = gmin + grange * 0.9f0
    end
    lrange = maxL - minL
    target = isdark ? minL + position * lrange : maxL - position * lrange
    _clamp01(target)
end

# ExtrapolateColorToLightness
function _extrapolate(base::_Seed, target::Float32)::NTuple{3,Float32}
    bo = base.oklab
    tgt = _Oklab(_clamp01(target), bo.A, bo.B)
    rgb = _oklab_to_rgb(tgt)
    _in_gamut(rgb) && return rgb   # in gamut → used directly (UNCLAMPED, as in C#)

    # out of gamut: binary-search max chroma (keeping hue) that fits, at the *unclamped* target L
    orig_chroma = Float32(sqrt(Float64(bo.A) * bo.A + Float64(bo.B) * bo.B))
    hue = Float32(atan(Float64(bo.B), Float64(bo.A)))
    minC = 0f0; maxC = orig_chroma
    tol = 0.001f0
    best = tgt
    i = 0
    while i < 20 && (maxC - minC) > tol
        testC = (minC + maxC) / 2f0
        test = _Oklab(target, testC * Float32(cos(Float64(hue))), testC * Float32(sin(Float64(hue))))
        if _in_gamut(_oklab_to_rgb(test))
            minC = testC
            best = test
        else
            maxC = testC
        end
        i += 1
    end
    _clamp_rgb(_oklab_to_rgb(best))
end

# InterpolateBetweenColors (sortedColors sorted ascending by lightness)
function _interpolate_between(sorted::Vector{_Seed}, target::Float32)::NTuple{3,Float32}
    lower = sorted[1]; upper = sorted[end]
    for i in 1:length(sorted)-1
        if target >= sorted[i].lightness && target <= sorted[i+1].lightness
            lower = sorted[i]; upper = sorted[i+1]
            break
        end
    end
    lrange = upper.lightness - lower.lightness
    t = lrange == 0f0 ? 0.5f0 : (target - lower.lightness) / lrange
    t = _clamp01(t)
    _clamp_rgb(_oklab_to_rgb(_oklab_lerp(lower.oklab, upper.oklab, t)))
end

# InterpolateToTargetLightness
function _interpolate_to_target(seeds::Vector{_Seed}, target::Float32)::NTuple{3,Float32}
    isempty(seeds) && throw(ArgumentError("No colors available"))
    length(seeds) == 1 && return _extrapolate(seeds[1], target)
    sorted = sort(seeds; by = s -> s.lightness)
    minL = sorted[1].lightness; maxL = sorted[end].lightness
    if target >= minL && target <= maxL
        return _interpolate_between(sorted, target)
    elseif target < minL
        return _extrapolate(sorted[1], target)
    else
        return _extrapolate(sorted[end], target)
    end
end

"""
    _ktsu_make_palette(seeds_by_meaning, isdark)

Stage B. `seeds_by_meaning::AbstractDict{SemanticMeaning,<:AbstractVector{_Seed}}`.
Returns `Dict{Tuple{SemanticMeaning,Priority},RGBA{Float32}}` covering every
(meaning, priority) for the meanings present in `seeds_by_meaning`
(MakeCompletePalette over all priority levels). Alpha is forced to 1.
"""
function _ktsu_make_palette(seeds_by_meaning, isdark::Bool)::Dict{Tuple{SemanticMeaning,Priority},RGBA{Float32}}
    gmin, gmax = _global_lightness_range(seeds_by_meaning)
    out = Dict{Tuple{SemanticMeaning,Priority},RGBA{Float32}}()
    for (meaning, seeds) in seeds_by_meaning
        isempty(seeds) && continue
        for priority in _KTSU_PRIORITIES
            target = _target_lightness(priority, meaning, gmin, gmax, isdark)
            r, g, b = _interpolate_to_target(seeds, target)
            out[(meaning, priority)] = RGBA{Float32}(r, g, b, 1f0)
        end
    end
    out
end

# ---------------------------------------------------------------------------
# Theme assembly (Stage A + Stage B)
# ---------------------------------------------------------------------------

# Convert a Colorant seed to its raw 0..1 sRGB-encoded rgb tuple (no gamma),
# matching ktsu's `byte/255` -> RgbColor. We go through RGB24 so the value is
# quantized to 8-bit exactly as ktsu's hex parsing does.
function _ktsu_seed(c::Colorant)::_Seed
    c8 = convert(RGB24, c)
    _seed((Float32(red(c8)), Float32(green(c8)), Float32(blue(c8))))
end

"""
    _ktsu_theme(; name, author="", isdark, roles)

Build a [`Theme`](@ref) using the ktsu engine. `roles::AbstractDict{SemanticMeaning,<:AbstractVector{<:Colorant}}`
gives the seed colors for each role. Runs Stage B, then resolves each `_KTSU_SLOTS`
entry's (meaning, priority) to a color. `tags = [isdark ? "dark" : "light"]`; alpha 1.
"""
function _ktsu_theme(; name::AbstractString, author::AbstractString = "", isdark::Bool,
                     roles)
    seeds_by_meaning = Dict(m => [_ktsu_seed(c) for c in cs] for (m, cs) in roles)
    palette = _ktsu_make_palette(seeds_by_meaning, isdark)
    colors = Dict{Symbol,RGBA{Float32}}(slot => palette[key] for (slot, key) in _KTSU_SLOTS if haskey(palette, key))
    Theme(; name, author, tags = [isdark ? "dark" : "light"], colors)
end
