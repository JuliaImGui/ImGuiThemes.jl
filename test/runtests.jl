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
    @test length(ImGuiThemes.THEMES) == 47
    @test allunique(t.name for t in ImGuiThemes.THEMES)
    @test all(length(t.colors) == 53 for t in ImGuiThemes.THEMES)
    @test ImGuiThemes.theme("Classic").author == "ocornut"
    @test_throws KeyError ImGuiThemes.theme("nope")
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
