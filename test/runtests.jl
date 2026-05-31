using TestItems
using TestItemRunner
@run_package_tests


@testitem "_" begin
    import Aqua
    Aqua.test_all(ImGuiThemes)

    import CompatHelperLocal as CHL
    CHL.@check()
end
