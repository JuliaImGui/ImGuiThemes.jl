# Live demo: opens a real GLFW/OpenGL window with the ImGuiThemes theme picker
# next to imgui's own demo window, so picking a theme restyles everything live.
#
# One-time setup (run from the repo root — devs the parent package into this env):
#   julia --project=examples -e 'import Pkg; Pkg.develop(path="."); Pkg.instantiate()'
# Then run:
#   julia --project=examples examples/theme_picker_demo.jl

using CImGui, ImGuiThemes
import GLFW, ModernGL

CImGui.set_backend(:GlfwOpenGL3)

function main()
    ctx = CImGui.CreateContext()
    CImGui.StyleColorsDark()
    CImGui.render(ctx; window_title = "ImGuiThemes demo", window_size = (1280, 720)) do
        ImGuiThemes.theme_picker()         # standalone window; applies the picked theme live
        CImGui.ShowDemoWindow(Ref(true))   # every widget type, so the theme is visible
    end
end

isempty(Base.PROGRAM_FILE) || main()
