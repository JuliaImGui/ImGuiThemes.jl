# Solarized — https://ethanschoonover.com/solarized
# Ported from VLBICal/FringyUI src/theme.jl (apply_solarized_style!): a constructive,
# colors-only theme over the 16-colour palette. Light mode reverses the base ramp.
# NB: `red`/`green`/`blue`/`alpha` are exported Colors accessors — never use them as local names.

const _SOL_BASE = parse.(RGBA{Float32},          # base03 base02 base01 base00 base0 base1 base2 base3
    ("#002b36", "#073642", "#586e75", "#657b83", "#839496", "#93a1a1", "#eee8d5", "#fdf6e3"))
const _SOL_BLUE   = parse(RGBA{Float32}, "#268bd2")
const _SOL_ORANGE = parse(RGBA{Float32}, "#cb4b16")

function _solarized(dark::Bool)
    base = dark ? _SOL_BASE : reverse(_SOL_BASE)  # base[1] = window bg ... base[8] = text
    colors = Dict{Symbol,RGBA{Float32}}(
        # Text & links
        :Text => base[8], :TextDisabled => base[5],
        :TextSelectedBg => withα(_SOL_BLUE, 0.4), :TextLink => _SOL_BLUE,
        # Backgrounds & borders
        :WindowBg => base[1], :ChildBg => withα(base[1], 0), :PopupBg => base[2],
        :MenuBarBg => base[2], :Border => base[4], :BorderShadow => withα(base[1], 0),
        # Title bars
        :TitleBg => base[2], :TitleBgActive => withα(_SOL_BLUE, 0.2), :TitleBgCollapsed => base[2],
        # Frame backgrounds
        :FrameBg => base[2], :FrameBgHovered => base[3], :FrameBgActive => withα(_SOL_BLUE, 0.4),
        # Headers
        :Header => base[2], :HeaderHovered => base[3], :HeaderActive => withα(_SOL_BLUE, 0.5),
        # Buttons
        :Button => base[2], :ButtonHovered => base[3], :ButtonActive => withα(_SOL_BLUE, 0.5),
        # Scrollbar
        :ScrollbarBg => withα(base[2], 0.6), :ScrollbarGrab => base[3],
        :ScrollbarGrabHovered => base[4], :ScrollbarGrabActive => _SOL_BLUE,
        # Sliders / checkmarks
        :CheckMark => _SOL_ORANGE, :SliderGrab => _SOL_BLUE, :SliderGrabActive => _SOL_ORANGE,
        # Separators
        :Separator => base[3], :SeparatorHovered => base[4], :SeparatorActive => _SOL_BLUE,
        # Resize grips
        :ResizeGrip => withα(base[3], 0.5), :ResizeGripHovered => base[4], :ResizeGripActive => _SOL_BLUE,
        # Tabs
        :Tab => base[2], :TabHovered => withα(_SOL_BLUE, 0.4), :TabSelected => withα(_SOL_BLUE, 0.2),
        :TabSelectedOverline => _SOL_ORANGE, :TabDimmed => base[1],
        :TabDimmedSelected => base[2], :TabDimmedSelectedOverline => base[4],
        # Docking
        :DockingPreview => withα(_SOL_BLUE, 0.4), :DockingEmptyBg => base[1],
        # Plots
        :PlotLines => _SOL_BLUE, :PlotLinesHovered => _SOL_ORANGE,
        :PlotHistogram => _SOL_BLUE, :PlotHistogramHovered => _SOL_ORANGE,
        # Tables
        :TableHeaderBg => base[2], :TableBorderStrong => base[4], :TableBorderLight => base[3],
        :TableRowBg => withα(base[1], 0), :TableRowBgAlt => withα(base[2], 0.5),
        # Drag/drop & nav
        :DragDropTarget => _SOL_ORANGE, :NavCursor => _SOL_ORANGE,
        :NavWindowingHighlight => withα(base[8], 0.7), :NavWindowingDimBg => withα(base[5], 0.2),
        :ModalWindowDimBg => withα(base[5], 0.35),
    )
    Theme(
        name        = dark ? "Solarized Dark" : "Solarized Light",
        author      = "Ethan Schoonover",
        description = "Solarized $(dark ? "dark" : "light")",
        tags        = [dark ? "dark" : "light", "blue"],
        colors      = colors,
    )
end

push!(_CURATED, _solarized(true), _solarized(false))
