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
    @test length(ImGuiThemes.THEMES) == 49
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
