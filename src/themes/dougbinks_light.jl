# Doug Binks / Pacôme Danhiez light style
# Upstream: https://gist.githubusercontent.com/dougbinks/8089b4bbaccaaf6fa204236978d165a9/raw
# Light style from Pacôme Danhiez (user itamago), extended by Doug Binks.
# Transcribed verbatim (light path, alpha_ = 1.0 → identity).
#
# Color name mapping from imgui ~1.49 → modern (1.92):
#   ChildWindowBg       → ChildBg
#   Column              → Separator
#   ColumnHovered       → SeparatorHovered
#   ColumnActive        → SeparatorActive
#   ModalWindowDarkening → ModalWindowDimBg
#   ComboBg             → DROPPED (PopupBg is set explicitly in this theme)
#   CloseButton         → DROPPED (removed from imgui)
#   CloseButtonHovered  → DROPPED
#   CloseButtonActive   → DROPPED

push!(_CURATED, Theme(
    name        = "Doug Binks Light",
    author      = "Doug Binks / Pacôme Danhiez",
    description = "Light style from Pacôme Danhiez (itamago), extended by Doug Binks",
    tags        = ["light"],
    style       = Dict{Symbol,Any}(
        :alpha         => 1.0,
        :frameRounding => 3.0,
    ),
    colors      = Dict{Symbol,RGBA{Float32}}(
        :Text                   => RGBA{Float32}(0.00f0, 0.00f0, 0.00f0, 1.00f0),
        :TextDisabled           => RGBA{Float32}(0.60f0, 0.60f0, 0.60f0, 1.00f0),
        :WindowBg               => RGBA{Float32}(0.94f0, 0.94f0, 0.94f0, 0.94f0),
        :ChildBg                => RGBA{Float32}(0.00f0, 0.00f0, 0.00f0, 0.00f0),
        :PopupBg                => RGBA{Float32}(1.00f0, 1.00f0, 1.00f0, 0.94f0),
        :Border                 => RGBA{Float32}(0.00f0, 0.00f0, 0.00f0, 0.39f0),
        :BorderShadow           => RGBA{Float32}(1.00f0, 1.00f0, 1.00f0, 0.10f0),
        :FrameBg                => RGBA{Float32}(1.00f0, 1.00f0, 1.00f0, 0.94f0),
        :FrameBgHovered         => RGBA{Float32}(0.26f0, 0.59f0, 0.98f0, 0.40f0),
        :FrameBgActive          => RGBA{Float32}(0.26f0, 0.59f0, 0.98f0, 0.67f0),
        :TitleBg                => RGBA{Float32}(0.96f0, 0.96f0, 0.96f0, 1.00f0),
        :TitleBgCollapsed       => RGBA{Float32}(1.00f0, 1.00f0, 1.00f0, 0.51f0),
        :TitleBgActive          => RGBA{Float32}(0.82f0, 0.82f0, 0.82f0, 1.00f0),
        :MenuBarBg              => RGBA{Float32}(0.86f0, 0.86f0, 0.86f0, 1.00f0),
        :ScrollbarBg            => RGBA{Float32}(0.98f0, 0.98f0, 0.98f0, 0.53f0),
        :ScrollbarGrab          => RGBA{Float32}(0.69f0, 0.69f0, 0.69f0, 1.00f0),
        :ScrollbarGrabHovered   => RGBA{Float32}(0.59f0, 0.59f0, 0.59f0, 1.00f0),
        :ScrollbarGrabActive    => RGBA{Float32}(0.49f0, 0.49f0, 0.49f0, 1.00f0),
        # ComboBg (0.86, 0.86, 0.86, 0.99) DROPPED — PopupBg is set explicitly above
        :CheckMark              => RGBA{Float32}(0.26f0, 0.59f0, 0.98f0, 1.00f0),
        :SliderGrab             => RGBA{Float32}(0.24f0, 0.52f0, 0.88f0, 1.00f0),
        :SliderGrabActive       => RGBA{Float32}(0.26f0, 0.59f0, 0.98f0, 1.00f0),
        :Button                 => RGBA{Float32}(0.26f0, 0.59f0, 0.98f0, 0.40f0),
        :ButtonHovered          => RGBA{Float32}(0.26f0, 0.59f0, 0.98f0, 1.00f0),
        :ButtonActive           => RGBA{Float32}(0.06f0, 0.53f0, 0.98f0, 1.00f0),
        :Header                 => RGBA{Float32}(0.26f0, 0.59f0, 0.98f0, 0.31f0),
        :HeaderHovered          => RGBA{Float32}(0.26f0, 0.59f0, 0.98f0, 0.80f0),
        :HeaderActive           => RGBA{Float32}(0.26f0, 0.59f0, 0.98f0, 1.00f0),
        :Separator              => RGBA{Float32}(0.39f0, 0.39f0, 0.39f0, 1.00f0),
        :SeparatorHovered       => RGBA{Float32}(0.26f0, 0.59f0, 0.98f0, 0.78f0),
        :SeparatorActive        => RGBA{Float32}(0.26f0, 0.59f0, 0.98f0, 1.00f0),
        :ResizeGrip             => RGBA{Float32}(1.00f0, 1.00f0, 1.00f0, 0.50f0),
        :ResizeGripHovered      => RGBA{Float32}(0.26f0, 0.59f0, 0.98f0, 0.67f0),
        :ResizeGripActive       => RGBA{Float32}(0.26f0, 0.59f0, 0.98f0, 0.95f0),
        # CloseButton / CloseButtonHovered / CloseButtonActive → DROPPED (removed from imgui)
        :PlotLines              => RGBA{Float32}(0.39f0, 0.39f0, 0.39f0, 1.00f0),
        :PlotLinesHovered       => RGBA{Float32}(1.00f0, 0.43f0, 0.35f0, 1.00f0),
        :PlotHistogram          => RGBA{Float32}(0.90f0, 0.70f0, 0.00f0, 1.00f0),
        :PlotHistogramHovered   => RGBA{Float32}(1.00f0, 0.60f0, 0.00f0, 1.00f0),
        :TextSelectedBg         => RGBA{Float32}(0.26f0, 0.59f0, 0.98f0, 0.35f0),
        :ModalWindowDimBg       => RGBA{Float32}(0.20f0, 0.20f0, 0.20f0, 0.35f0),
    ),
))
