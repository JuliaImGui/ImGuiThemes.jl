using TestItems
using TestItemRunner
@run_package_tests


@testitem "_" begin
    import Aqua
    Aqua.test_all(ImGuiThemes)

    import CompatHelperLocal as CHL
    CHL.@check()
end

@testitem "registry" begin
    @test length(ImGuiThemes.THEMES) >= 49
    @test allunique(t.name for t in ImGuiThemes.THEMES)
    @test length(ImGuiThemes.theme("Cherry").colors) == 53    # ImThemes themes carry all 53 keys
    @test length(ImGuiThemes.theme("Darcula").colors) == 53
    @test ImGuiThemes.theme("Classic").author == "ocornut"
    @test_throws KeyError ImGuiThemes.theme("nope")
end

@testitem "solarized (curated, palette-built)" begin
    using CImGui, Colors
    rgb(v) = (v.x, v.y, v.z)                   # ImVec4 components
    crgb(c) = (red(c), green(c), blue(c))       # Colors accessors (functions, not local names)

    sd = ImGuiThemes.theme("Solarized Dark")
    @test ImGuiThemes.mode(sd) === :dark
    @test ImGuiThemes.mode(ImGuiThemes.theme("Solarized Light")) === :light
    @test length(sd.colors) == 58

    ctx = CImGui.CreateContext()
    try
        style = CImGui.GetStyle()
        ImGuiThemes.apply!(sd, style)
        wb = CImGui.c_get(style.Colors, CImGui.ImGuiCol_WindowBg)
        @test rgb(wb) == crgb(parse(RGBA{Float32}, "#002b36"))         # base03
        tl = CImGui.c_get(style.Colors, CImGui.ImGuiCol_TextLink)
        @test rgb(tl) == crgb(parse(RGBA{Float32}, "#268bd2"))         # explicit blue, NOT derived (apply! guard)
        ic = CImGui.c_get(style.Colors, CImGui.ImGuiCol_InputTextCursor)
        txt = CImGui.c_get(style.Colors, CImGui.ImGuiCol_Text)
        @test (ic.x, ic.y, ic.z, ic.w) == (txt.x, txt.y, txt.z, txt.w) # derived from Text (Solarized omits it)
    finally
        CImGui.DestroyContext(ctx)
    end
end

@testitem "spectrum (curated, Adobe palette)" begin
    using CImGui, Colors
    rgb(v) = (v.x, v.y, v.z)                   # ImVec4 components
    crgb(c) = (red(c), green(c), blue(c))       # Colors accessors (functions, not local names)

    sl = ImGuiThemes.theme("Spectrum Light")
    sd = ImGuiThemes.theme("Spectrum Dark")
    @test ImGuiThemes.mode(sl) === :light
    @test ImGuiThemes.mode(sd) === :dark

    ctx = CImGui.CreateContext()
    try
        style = CImGui.GetStyle()
        ImGuiThemes.apply!(sl, style)
        # WindowBg = Colors->GRAY100 = #F5F5F5 in light palette
        wb = CImGui.c_get(style.Colors, CImGui.ImGuiCol_WindowBg)
        @test rgb(wb) == crgb(colorant"#F5F5F5")
        # CheckMark final value = GRAY50 = #FFFFFF in light palette (overwritten from BLUE500 in upstream)
        ck = CImGui.c_get(style.Colors, CImGui.ImGuiCol_CheckMark)
        @test rgb(ck) == crgb(colorant"#FFFFFF")
    finally
        CImGui.DestroyContext(ctx)
    end
end

@testitem "lookup tables resolve to real ImGuiCol_" begin
    using CImGui
    hascol(n) = isdefined(CImGui, Symbol("ImGuiCol_", n))
    for t in ImGuiThemes.THEMES, key in keys(t.colors)
        @test hascol(get(ImGuiThemes.COLOR_RENAME, key, key))
    end
    for (new, (src, _)) in ImGuiThemes.NEW_COLOR_FROM
        @test hascol(new)
    end
end

@testitem "export_string + live edit" begin
    using CImGui, Colors

    # export_string: minimal colorant-hex dict, canonical order, round-trips
    d = Dict{Symbol,RGBA{Float32}}(
        :WindowBg => parse(RGBA{Float32}, "#000000D9"),
        :Text     => parse(RGBA{Float32}, "#E5E5E5FF"),
    )
    s = ImGuiThemes.export_string(d)
    @test startswith(s, "Dict(\n")
    @test occursin("colorant\"#E5E5E5FF\"", s)
    @test occursin("colorant\"#000000D9\"", s)
    @test findfirst(":Text", s) < findfirst(":WindowBg", s)   # canonical imgui order, not dict order
    for (_, c) in d
        @test parse(RGBA{Float32}, "#" * Colors.hex(c)) == c   # every emitted hex round-trips
    end

    # _apply_working pushes an edited working color to the live style
    ctx = CImGui.CreateContext()
    try
        st = ImGuiThemes.PickerState("Cherry", copy(ImGuiThemes.theme("Cherry").colors), false)
        st.colors[:WindowBg] = parse(RGBA{Float32}, "#112233FF")
        ImGuiThemes._apply_working(st)
        wb = CImGui.c_get(CImGui.GetStyle().Colors, CImGui.ImGuiCol_WindowBg)
        c = st.colors[:WindowBg]
        @test (wb.x, wb.y, wb.z, wb.w) == (red(c), green(c), blue(c), alpha(c))
    finally
        CImGui.DestroyContext(ctx)
    end
end

@testitem "helloimgui (light)" begin
    using CImGui, Colors

    lr = ImGuiThemes.theme("Light Rounded")
    ww = ImGuiThemes.theme("White is White")
    @test ImGuiThemes.mode(lr) === :light
    @test ImGuiThemes.mode(ww) === :light

    ctx = CImGui.CreateContext()
    try
        style = CImGui.GetStyle()

        # Light Rounded: apply and check all components in [0,1]
        ImGuiThemes.apply!(lr, style)
        for i in 0:(Int(CImGui.ImGuiCol_COUNT) - 1)
            c = CImGui.c_get(style.Colors, i)
            for comp in (c.x, c.y, c.z, c.w)
                @test isfinite(comp) && 0 ≤ comp ≤ 1
            end
        end
        # WindowBg is the distinctive pinkish-white (0.9614, 0.9531, 0.9531)
        wb = CImGui.c_get(style.Colors, CImGui.ImGuiCol_WindowBg)
        @test wb.x ≈ 0.9613733888f0  atol=1e-6
        @test wb.y ≈ 0.9531213045f0  atol=1e-6

        # White is White: apply and check all components in [0,1]
        ImGuiThemes.apply!(ww, style)
        for i in 0:(Int(CImGui.ImGuiCol_COUNT) - 1)
            c = CImGui.c_get(style.Colors, i)
            for comp in (c.x, c.y, c.z, c.w)
                @test isfinite(comp) && 0 ≤ comp ≤ 1
            end
        end
        # WindowBg should be pure white (clamped from upstream's >1 value)
        wb2 = CImGui.c_get(style.Colors, CImGui.ImGuiCol_WindowBg)
        @test wb2.x ≈ 1.0f0  atol=1e-6
        @test wb2.y ≈ 1.0f0  atol=1e-6
        @test wb2.z ≈ 1.0f0  atol=1e-6
    finally
        CImGui.DestroyContext(ctx)
    end
end

@testitem "dougbinks (light)" begin
    using CImGui, Colors

    db = ImGuiThemes.theme("Doug Binks Light")
    @test ImGuiThemes.mode(db) === :light

    ctx = CImGui.CreateContext()
    try
        style = CImGui.GetStyle()
        ImGuiThemes.apply!(db, style)
        for i in 0:(Int(CImGui.ImGuiCol_COUNT) - 1)
            c = CImGui.c_get(style.Colors, i)
            for comp in (c.x, c.y, c.z, c.w)
                @test isfinite(comp) && 0 ≤ comp ≤ 1
            end
        end
        # WindowBg = (0.94, 0.94, 0.94, 0.94) verbatim from upstream
        wb = CImGui.c_get(style.Colors, CImGui.ImGuiCol_WindowBg)
        @test wb.x ≈ 0.94f0  atol=1e-6
        @test wb.y ≈ 0.94f0  atol=1e-6
        @test wb.z ≈ 0.94f0  atol=1e-6
        @test wb.w ≈ 0.94f0  atol=1e-6
    finally
        CImGui.DestroyContext(ctx)
    end
end

@testitem "apply all themes headless" begin
    using CImGui, Colors
    ctx = CImGui.CreateContext()
    try
        style = CImGui.GetStyle()
        for t in ImGuiThemes.THEMES
            ImGuiThemes.apply!(t, style)
            for i in 0:(Int(CImGui.ImGuiCol_COUNT) - 1)
                c = CImGui.c_get(style.Colors, i)
                for comp in (c.x, c.y, c.z, c.w)
                    @test isfinite(comp) && 0 ≤ comp ≤ 1
                end
            end
        end
        # geometry + new-color derivation spot-checks on a known theme
        cherry = ImGuiThemes.theme("Cherry")
        ImGuiThemes.apply!(cherry, style)
        @test unsafe_load(style.WindowRounding) == Float32(cherry.style[:windowRounding])
        ha = cherry.colors[:HeaderActive]
        tl = CImGui.c_get(style.Colors, CImGui.ImGuiCol_TextLink)
        @test (tl.x, tl.y, tl.z) == (red(ha), green(ha), blue(ha))
    finally
        CImGui.DestroyContext(ctx)
    end
end

@testitem "ktsu engine (palette→imgui port)" begin
    using Colors
    import ImGuiThemes: Theme

    # The ktsu engine lives in src/ktsu/engine.jl and is intentionally NOT yet
    # wired into the ImGuiThemes module (themes are a later task). Load it here
    # into this testitem's module, which already has Colors + Theme in scope.
    K = @__MODULE__
    include(joinpath(pkgdir(ImGuiThemes), "src", "ktsu", "engine.jl"))

    # Stage-A table fully translated.
    @test length(K._KTSU_SLOTS) == 47

    # Catppuccin Latte (light) — seeds + roles transcribed from ktsu Themes/Catppuccin/Latte.cs
    latte = K._ktsu_theme(; name = "Catppuccin Latte", isdark = false, roles = Dict(
        K.Neutral      => [colorant"#4c4f69", colorant"#dce0e8"],  # Text, Crust
        K.Primary      => [colorant"#1e66f5"],
        K.Alternate    => [colorant"#ea76cb"],
        K.Success      => [colorant"#40a02b"],
        K.CallToAction => [colorant"#40a02b"],
        K.Information  => [colorant"#209fb5"],
        K.Caution      => [colorant"#e64553"],
        K.Warning      => [colorant"#fe640b"],
        K.Error        => [colorant"#d20f39"],
        K.Failure      => [colorant"#d20f39"],
        K.Debug        => [colorant"#8839ef"],
    ))

    # Dracula (dark) — from ktsu Themes/Dracula/Dracula.cs
    dracula = K._ktsu_theme(; name = "Dracula", isdark = true, roles = Dict(
        K.Neutral      => [colorant"#f8f8f2", colorant"#282a36"],  # Foreground, Background
        K.Primary      => [colorant"#bd93f9"],
        K.Alternate    => [colorant"#ff79c6"],
        K.Success      => [colorant"#50fa7b"],
        K.CallToAction => [colorant"#50fa7b"],
        K.Information  => [colorant"#8be9fd"],
        K.Caution      => [colorant"#ffb86c"],
        K.Warning      => [colorant"#f1fa8c"],
        K.Error        => [colorant"#ff5555"],
        K.Failure      => [colorant"#ff5555"],
        K.Debug        => [colorant"#bd93f9"],
    ))

    for t in (latte, dracula)
        @test length(t.colors) == 47                 # every slot resolved
        for (_, c) in t.colors                        # all components in gamut, alpha forced to 1
            for comp in (red(c), green(c), blue(c))
                @test isfinite(comp) && 0 ≤ comp ≤ 1
            end
            @test alpha(c) == 1f0
        end
    end

    @test "light" in latte.tags
    @test "dark" in dracula.tags

    # Light theme: background bright, text dark. Dark theme: the reverse.
    L(c) = K._rgb_to_oklab(red(c), green(c), blue(c)).L
    @test L(latte.colors[:WindowBg]) > L(latte.colors[:Text])
    @test L(dracula.colors[:WindowBg]) < L(dracula.colors[:Text])

    # Regression: exact values cross-checked against ktsu's C# engine
    # (ktsu.ThemeProvider, MakeCompletePalette) — match to ~1e-7, well under 1/255.
    approxrgba(c, r, g, b) = isapprox(red(c), r; atol = 5e-4) &&
                             isapprox(green(c), g; atol = 5e-4) &&
                             isapprox(blue(c), b; atol = 5e-4)
    @test approxrgba(latte.colors[:WindowBg], 0.86274457, 0.87843144, 0.9098034)
    @test approxrgba(latte.colors[:Text],     0.24897297, 0.2593263,  0.35032633)
    @test approxrgba(latte.colors[:Button],   0.44397306, 0.66916883, 0.99953973)
    @test approxrgba(dracula.colors[:WindowBg], 0.15686299, 0.16470574, 0.2117647)
    @test approxrgba(dracula.colors[:Text],     0.9725482,  0.9725493,  0.9490193)
    @test approxrgba(dracula.colors[:Button],   0.7154975,  0.5546663,  0.94537854)
end
