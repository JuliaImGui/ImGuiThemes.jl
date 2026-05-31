# Adobe Spectrum — https://github.com/adobe/imgui
# Ported from imgui_spectrum.cpp StyleColorsSpectrum() (verbatim hex values).
# NB: `red`/`green`/`blue`/`alpha` are exported Colors accessors — never use them as local names.

# Light palette (LightPalette in imgui_spectrum.cpp)
const _SPEC_LIGHT = (
    GRAY50=colorant"#FFFFFF", GRAY75=colorant"#FAFAFA", GRAY100=colorant"#F5F5F5",
    GRAY200=colorant"#EAEAEA", GRAY300=colorant"#E1E1E1", GRAY400=colorant"#CACACA",
    GRAY500=colorant"#B3B3B3", GRAY600=colorant"#8E8E8E", GRAY700=colorant"#707070",
    GRAY800=colorant"#4B4B4B", GRAY900=colorant"#2C2C2C",
    BLUE400=colorant"#2680EB", BLUE500=colorant"#1473E6", BLUE600=colorant"#0D66D0", BLUE700=colorant"#095ABA",
    RED400=colorant"#E34850", RED500=colorant"#D7373F", RED600=colorant"#C9252D", RED700=colorant"#BB121A",
    ORANGE400=colorant"#E68619", ORANGE500=colorant"#DA7B11", ORANGE600=colorant"#CB6F10", ORANGE700=colorant"#BD640D",
    GREEN400=colorant"#2D9D78", GREEN500=colorant"#268E6C", GREEN600=colorant"#12805C", GREEN700=colorant"#107154",
)

# Dark palette (DarkPalette in imgui_spectrum.cpp)
const _SPEC_DARK = (
    GRAY50=colorant"#252525", GRAY75=colorant"#2F2F2F", GRAY100=colorant"#323232",
    GRAY200=colorant"#393939", GRAY300=colorant"#3E3E3E", GRAY400=colorant"#4D4D4D",
    GRAY500=colorant"#5C5C5C", GRAY600=colorant"#7B7B7B", GRAY700=colorant"#999999",
    GRAY800=colorant"#CDCDCD", GRAY900=colorant"#FFFFFF",
    BLUE400=colorant"#2680EB", BLUE500=colorant"#378EF0", BLUE600=colorant"#4B9CF5", BLUE700=colorant"#5AA9FA",
    RED400=colorant"#E34850", RED500=colorant"#EC5B62", RED600=colorant"#F76D74", RED700=colorant"#FF7B82",
    ORANGE400=colorant"#E68619", ORANGE500=colorant"#F29423", ORANGE600=colorant"#F9A43F", ORANGE700=colorant"#FFB55B",
    GREEN400=colorant"#2D9D78", GREEN500=colorant"#33AB84", GREEN600=colorant"#39B990", GREEN700=colorant"#3FC89C",
)

function _spectrum(dark::Bool)
    p = dark ? _SPEC_DARK : _SPEC_LIGHT
    # TextSelectedBg: BLUE400 with alpha 0x33/255 (exact upstream: (Colors->BLUE400 & 0x00FFFFFF) | 0x33000000)
    # NavCursor (NavHighlight): GRAY900 with alpha 0x0A/255 (exact upstream: (Colors->GRAY900 & 0x00FFFFFF) | 0x0A000000)
    colors = Dict{Symbol,RGBA{Float32}}(
        :Text               => p.GRAY800,
        :TextDisabled       => p.GRAY500,
        :WindowBg           => p.GRAY100,
        :ChildBg            => RGBA{Float32}(0, 0, 0, 0),
        :PopupBg            => p.GRAY50,
        :Border             => p.GRAY300,
        :BorderShadow       => RGBA{Float32}(0, 0, 0, 0),
        :FrameBg            => p.GRAY75,
        :FrameBgHovered     => p.GRAY50,
        :FrameBgActive      => p.GRAY200,
        :TitleBg            => p.GRAY300,
        :TitleBgActive      => p.GRAY200,
        :TitleBgCollapsed   => p.GRAY400,
        :MenuBarBg          => p.GRAY100,
        :ScrollbarBg        => p.GRAY100,
        :ScrollbarGrab      => p.GRAY400,
        :ScrollbarGrabHovered => p.GRAY600,
        :ScrollbarGrabActive  => p.GRAY700,
        # CheckMark is set to BLUE500 then overwritten to GRAY50 in upstream — final value is GRAY50
        :CheckMark          => p.GRAY50,
        :SliderGrab         => p.GRAY700,
        :SliderGrabActive   => p.GRAY800,
        :Button             => p.GRAY75,
        :ButtonHovered      => p.GRAY50,
        :ButtonActive       => p.GRAY200,
        :Header             => p.BLUE400,
        :HeaderHovered      => p.BLUE500,
        :HeaderActive       => p.BLUE600,
        :Separator          => p.GRAY400,
        :SeparatorHovered   => p.GRAY600,
        :SeparatorActive    => p.GRAY700,
        :ResizeGrip         => p.GRAY400,
        :ResizeGripHovered  => p.GRAY600,
        :ResizeGripActive   => p.GRAY700,
        :PlotLines          => p.BLUE400,
        :PlotLinesHovered   => p.BLUE600,
        :PlotHistogram      => p.BLUE400,
        :PlotHistogramHovered => p.BLUE600,
        :TextSelectedBg     => withα(p.BLUE400, 0x33 / 255),
        :DragDropTarget     => RGBA{Float32}(1, 1, 0, 0.9),
        :NavCursor          => withα(p.GRAY900, 0x0A / 255),
        :NavWindowingHighlight => RGBA{Float32}(1, 1, 1, 0.7),
        :NavWindowingDimBg  => RGBA{Float32}(0.8, 0.8, 0.8, 0.2),
        :ModalWindowDimBg   => RGBA{Float32}(0.2, 0.2, 0.2, 0.35),
        :Tab                => p.GRAY300,
        :TabSelected        => p.BLUE500,
        :TabHovered         => p.BLUE700,
        :TabDimmed          => p.GRAY400,
        :TabDimmedSelected  => p.BLUE700,
    )
    Theme(
        name        = dark ? "Spectrum Dark" : "Spectrum Light",
        author      = "Adobe",
        description = "Adobe Spectrum $(dark ? "dark" : "light")",
        tags        = [dark ? "dark" : "light"],
        style       = Dict{Symbol,Any}(
            :windowRounding  => 4.0,
            :frameRounding   => 4.0,
            :frameBorderSize => 1.0,
            :grabRounding    => 4.0,
        ),
        colors      = colors,
    )
end

push!(_CURATED, _spectrum(false), _spectrum(true))
