# src/fonts.jl — optional fonts, downloaded and cached on demand (only when requested).

using Scratch: @get_scratch!
import Downloads
import SHA

"""
    FontSpec

A downloadable font: a pinned `url`, the expected `sha256` of the downloaded object
(a `.ttf` or a `.tar.gz`), and `member` — the path of the `.ttf` inside the archive
for tarball sources, or `nothing` for a direct `.ttf`.

Get one from [`FONTS`](@ref) — e.g. `ImGuiThemes.FONTS[(:JuliaMono, :Bold)]` — and pass it to
`CImGui.AddFontFromFileTTF` (or [`font_path`](@ref)).
"""
struct FontSpec
    url::String
    sha256::String
    member::Union{Nothing,String}
end
FontSpec(url, sha256) = FontSpec(url, sha256, nothing)

const _LIBERATION_URL = "https://github.com/liberationfonts/liberation-fonts/files/7261482/liberation-fonts-ttf-2.1.5.tar.gz"
const _LIBERATION_SHA = "7191c669bf38899f73a2094ed00f7b800553364f90e2637010a69c0e268f25d0"
_lib(name)    = FontSpec(_LIBERATION_URL, _LIBERATION_SHA, "liberation-fonts-ttf-2.1.5/$name.ttf")
_jm(style)    = "https://github.com/cormullion/juliamono/raw/v0.062/JuliaMono-$style.ttf"
_dejavu(file) = "https://cdn.jsdelivr.net/npm/dejavu-fonts-ttf@2.37.3/ttf/$file.ttf"
_roboto(dir)  = "https://cdn.jsdelivr.net/npm/@expo-google-fonts/roboto@0.4.3/$dir/Roboto_$dir.ttf"

"""
    FONTS

Registry of optionally-downloadable fonts, keyed by `(family, variant)` — e.g.
`FONTS[(:JuliaMono, :Bold)]` → a [`FontSpec`](@ref). The fonts are fetched from upstream
(and cached) only when actually requested; nothing is downloaded on install. Enumerate with
`keys(FONTS)`.

```julia
CImGui.AddFontFromFileTTF(ImGuiThemes.FONTS[(:JuliaMono, :Bold)])   # download + add to the atlas
```
"""
const FONTS = Dict{Tuple{Symbol,Symbol},FontSpec}(
    (:JuliaMono, :Regular) => FontSpec(_jm("Regular"), "b9e7c00d2bbc69aa072b45c72d2156137de654ce032905df04d4217dc9853e9f"),
    (:JuliaMono, :Bold) => FontSpec(_jm("Bold"), "3cc105fe979a35cbb3f69d846ee709384aae9a163cb6f6e53cc1c58b9e85c903"),
    (:JuliaMono, :Italic) => FontSpec(_jm("RegularItalic"), "5717f6b578f319b4e4a1997579fc22b56a2be7fb09a6677648a9bb525979f797"),
    (:JuliaMono, :BoldItalic) => FontSpec(_jm("BoldItalic"), "1e45bc6b8a4c69e3c09b1bd475dc6113ed822941161d666a18ee9ffcd88391f1"),
    (:JuliaMono, :Light) => FontSpec(_jm("Light"), "8dfc82789dc405ba475290ecc0c64d64250931bcb4181e39bf2abf94bfae2cb7"),
    (:JuliaMono, :LightItalic) => FontSpec(_jm("LightItalic"), "51a619f25e5acb3bee97dec6176f90713e38c5d69ebeec9526cfa0d59a0acc06"),
    (:JuliaMono, :Medium) => FontSpec(_jm("Medium"), "6e94b8998f01cada1e4ecb1ce6e852d81d2ba86628f4cee09abf5408b1f0368c"),
    (:JuliaMono, :MediumItalic) => FontSpec(_jm("MediumItalic"), "08d83eeeb16886964ebcb7092f0c653af37cd0c4f1444ac5439e0917a01decdd"),
    (:JuliaMono, :SemiBold) => FontSpec(_jm("SemiBold"), "9a07ddb3f8404618d1fde3977e9e4aafc4e1d656f2eae1781ecebd6df706d77b"),
    (:JuliaMono, :SemiBoldItalic) => FontSpec(_jm("SemiBoldItalic"), "a1e11b4fb012a6ded1ce7a520c14d8ac8710f0cedef02fead8ce255497fb4580"),
    (:JuliaMono, :ExtraBold) => FontSpec(_jm("ExtraBold"), "cc6d73a3d0940a76f3d8b06f60281139cc65f451136b8e1fc27bb29e20039dd8"),
    (:JuliaMono, :ExtraBoldItalic) => FontSpec(_jm("ExtraBoldItalic"), "f7d89521dadb5c54cc134a4c435c52a7acf76a060a1c545299c971f9f525e8bd"),
    (:JuliaMono, :Black) => FontSpec(_jm("Black"), "d969778879e0f73bd7c7e1525bf1d648987a9c9f984f05488914ab2c5fb5a8dc"),
    (:JuliaMono, :BlackItalic) => FontSpec(_jm("BlackItalic"), "b4ab0764b4ffc4e0d76fa331698db9bdb0abb039780a16b7dd6786bbb1ea2bdf"),

    (:DejaVuSans, :Regular) => FontSpec(_dejavu("DejaVuSans"), "7da195a74c55bef988d0d48f9508bd5d849425c1770dba5d7bfc6ce9ed848954"),
    (:DejaVuSans, :Bold) => FontSpec(_dejavu("DejaVuSans-Bold"), "e6476c1b80502924294eed40894c5b18e06c181444ca953e5334262df9c27724"),
    (:DejaVuSans, :Italic) => FontSpec(_dejavu("DejaVuSans-Oblique"), "4af75fa16ee6d3ad43e1ecec41862c24954af26a55c6bb1ebb27bd486a50f5f4"),
    (:DejaVuSans, :BoldItalic) => FontSpec(_dejavu("DejaVuSans-BoldOblique"), "eb436dca0c2594b73d8b603b892e374fdfd8d885d25ffb4f18df4c4c0b49e50f"),
    (:DejaVuSans, :ExtraLight) => FontSpec(_dejavu("DejaVuSans-ExtraLight"), "6cb0746a1f68d176bebe83752cee35ebdf726cb1a1e88a01fc038ddf76de9ea8"),
    (:DejaVuSans, :Condensed) => FontSpec(_dejavu("DejaVuSansCondensed"), "8550cd5ca1acb65a8fc7877c46939cd0b4d909f8e7bc1e24716873d918c5e549"),
    (:DejaVuSans, :CondensedBold) => FontSpec(_dejavu("DejaVuSansCondensed-Bold"), "38098d0b8edd8430a0f53fb2831b5d36037563a998a620d3c87a4d7591766d20"),
    (:DejaVuSans, :CondensedItalic) => FontSpec(_dejavu("DejaVuSansCondensed-Oblique"), "dc3526fa25fae4278c4e34b47d4c049b6923421c70921032a0db11bfe9c1b0cf"),
    (:DejaVuSans, :CondensedBoldItalic) => FontSpec(_dejavu("DejaVuSansCondensed-BoldOblique"), "43f9fd6b77edf174553cf94857c77c63de7ddb0c6751fd1390e73223518e128f"),

    (:DejaVuSansMono, :Regular) => FontSpec(_dejavu("DejaVuSansMono"), "b4a6c3e4faab8773f4ff761d56451646409f29abedd68f05d38c2df667d3c582"),
    (:DejaVuSansMono, :Bold) => FontSpec(_dejavu("DejaVuSansMono-Bold"), "bce60f1b4421acd9ea51ba6623d7024ecbe6817a953e3654df62a5e6bdf8f769"),
    (:DejaVuSansMono, :Italic) => FontSpec(_dejavu("DejaVuSansMono-Oblique"), "742097840c541870e8d6dc5c9b37bb1ceeea6c0dedd1d475faf903ef9df734b0"),
    (:DejaVuSansMono, :BoldItalic) => FontSpec(_dejavu("DejaVuSansMono-BoldOblique"), "91713a71d550bba22c2a6b2bb2a9ad8f9a159e12e4e9f0a5b2677998ba21213e"),

    (:DejaVuSerif, :Regular) => FontSpec(_dejavu("DejaVuSerif"), "42d1edeb7952f31b1f96d767ed7030b08a39e0c372b0071641518864e2bffb51"),
    (:DejaVuSerif, :Bold) => FontSpec(_dejavu("DejaVuSerif-Bold"), "c47b5527bcdc8dcf9ea8c77054454c5a884beaca2f44851a2a823ee639cbf07f"),
    (:DejaVuSerif, :Italic) => FontSpec(_dejavu("DejaVuSerif-Italic"), "2e39b1d50f90b933b00c7bb54a96afd3f86419b3d717c7cf202e36f2d4973e47"),
    (:DejaVuSerif, :BoldItalic) => FontSpec(_dejavu("DejaVuSerif-BoldItalic"), "8d3dd3d31350309042ed226af82b34539bd773518e6107cb352712853ba80308"),
    (:DejaVuSerif, :Condensed) => FontSpec(_dejavu("DejaVuSerifCondensed"), "685dcdfb8daf32a453d3426a4eb8d881c72146ddd999229354fb757511357995"),
    (:DejaVuSerif, :CondensedBold) => FontSpec(_dejavu("DejaVuSerifCondensed-Bold"), "e09aa87c60c3e8de7f4e6c7bfeec8fd9489b6cd975e3033259bca3d6009aed18"),
    (:DejaVuSerif, :CondensedItalic) => FontSpec(_dejavu("DejaVuSerifCondensed-Italic"), "dfe5bf5336d62ca71de419cccf7fd18ab19a57245dc392891ee76347129807e1"),
    (:DejaVuSerif, :CondensedBoldItalic) => FontSpec(_dejavu("DejaVuSerifCondensed-BoldItalic"), "4cfc5a3700c72413f51c4bb54f09617401a0a63eccb9ff577713e20afa047fa5"),

    (:Roboto, :Thin) => FontSpec(_roboto("100Thin"), "97610d693caecc007e532da2ba4703b693667819badc2e88a724236402094c65"),
    (:Roboto, :ThinItalic) => FontSpec(_roboto("100Thin_Italic"), "5b9d03fc55047e379893dfcf3ac85dcfaf39a88e5027f149f4caa39c0773ad81"),
    (:Roboto, :ExtraLight) => FontSpec(_roboto("200ExtraLight"), "f5d01fbfa656ab6f228454253dfcdf057b7e9568b6c2afe82d97e05f3b45e55e"),
    (:Roboto, :ExtraLightItalic) => FontSpec(_roboto("200ExtraLight_Italic"), "2391c44c22fbaef26b7a1184da8943a506036b41ed70af79c2036c18fdea1f1c"),
    (:Roboto, :Light) => FontSpec(_roboto("300Light"), "cce4405e885544376ce20621001274e2ac9080a171ad4d2e097bf04d790157ea"),
    (:Roboto, :LightItalic) => FontSpec(_roboto("300Light_Italic"), "8711097e1a718e29d5cfde77c529b168fe96a0de38bb3c9d8d484f5bbc36bb01"),
    (:Roboto, :Regular) => FontSpec(_roboto("400Regular"), "15256405ecb0d880678833a582760efad538ab2932318b52c8105b267d159459"),
    (:Roboto, :Italic) => FontSpec(_roboto("400Regular_Italic"), "6a372c348dc20c246b92d60b9bda3c0a9ffedc129790ed3f31faf89daa99d793"),
    (:Roboto, :Medium) => FontSpec(_roboto("500Medium"), "79343dc641a2e8d48a703a4667b71fc8dc6565cc8ce47dfc34fc52c12aadbf38"),
    (:Roboto, :MediumItalic) => FontSpec(_roboto("500Medium_Italic"), "1bdb6f190ea0b5a41f333e276a5fcf26244dbc621a5d2077144dbf5a39f0ef83"),
    (:Roboto, :SemiBold) => FontSpec(_roboto("600SemiBold"), "32fe2086b0e54eca85a68eb74e3d89bb16a7ffe59085d6dc7d079f5b3c26d6ab"),
    (:Roboto, :SemiBoldItalic) => FontSpec(_roboto("600SemiBold_Italic"), "d39ce04ed4833809795c4d83d8e66e91aaa687db9023b86e80c92e48395cd7d4"),
    (:Roboto, :Bold) => FontSpec(_roboto("700Bold"), "4aaf8c5b661a386998c2e70cf2b87e2440f5404e0b8fd81164f0413fb3435ec6"),
    (:Roboto, :BoldItalic) => FontSpec(_roboto("700Bold_Italic"), "c6a5e7c224d3bf6698e5d3c124f0f0220cad20d5d413920447a96f033a0292ee"),
    (:Roboto, :ExtraBold) => FontSpec(_roboto("800ExtraBold"), "43d5ce98c58336045220fa1dac2bd22281b1aab3eca66785cb34eb3ad1dfe1a5"),
    (:Roboto, :ExtraBoldItalic) => FontSpec(_roboto("800ExtraBold_Italic"), "14cf06159e9f486267d4892fbe38ab0806d596c9a9a3c664c69bf2b863c5c7d8"),
    (:Roboto, :Black) => FontSpec(_roboto("900Black"), "27bccdc7ead7eb5754e950c4c4eaa9a35f2b4ae1a29164921017285bebb82a02"),
    (:Roboto, :BlackItalic) => FontSpec(_roboto("900Black_Italic"), "c3e3432dd52e1b566c410408f7625e14b7702f5b9e05cc478936297ca488fe0e"),

    (:LiberationSans, :Regular) => _lib("LiberationSans-Regular"),
    (:LiberationSans, :Bold) => _lib("LiberationSans-Bold"),
    (:LiberationSans, :Italic) => _lib("LiberationSans-Italic"),
    (:LiberationSans, :BoldItalic) => _lib("LiberationSans-BoldItalic"),

    (:LiberationSerif, :Regular) => _lib("LiberationSerif-Regular"),
    (:LiberationSerif, :Bold) => _lib("LiberationSerif-Bold"),
    (:LiberationSerif, :Italic) => _lib("LiberationSerif-Italic"),
    (:LiberationSerif, :BoldItalic) => _lib("LiberationSerif-BoldItalic"),

    (:LiberationMono, :Regular) => _lib("LiberationMono-Regular"),
    (:LiberationMono, :Bold) => _lib("LiberationMono-Bold"),
    (:LiberationMono, :Italic) => _lib("LiberationMono-Italic"),
    (:LiberationMono, :BoldItalic) => _lib("LiberationMono-BoldItalic"),
)

"""
    font_path(spec::FontSpec) -> String

Local path to the font's `.ttf`, downloading and caching it on first call (verifying
its `sha256`) and returning the cached path thereafter. The cache lives in a per-package
scratch directory. Tarball sources are unpacked with the system `tar`.
"""
function font_path(spec::FontSpec)
    dir = @get_scratch!("fonts")
    # Cache name includes the member: archive-based specs share one sha256 (the tarball)
    # and differ only by which file they extract.
    fname = spec.member === nothing ? "$(spec.sha256).ttf" : "$(spec.sha256)_$(basename(spec.member))"
    dest = joinpath(dir, fname)
    isfile(dest) && return dest

    tmp = tempname(dir)
    Downloads.download(spec.url, tmp)
    try
        got = bytes2hex(open(SHA.sha256, tmp))
        got == spec.sha256 || error("ImGuiThemes: checksum mismatch for $(spec.url)\n  expected $(spec.sha256)\n  got      $got")
        if spec.member === nothing
            mv(tmp, dest; force = true)
        else
            open(dest, "w") do io
                run(pipeline(`tar xzOf $tmp $(spec.member)`; stdout = io))
            end
        end
    finally
        rm(tmp; force = true)
    end
    dest
end

"""
    CImGui.AddFontFromFileTTF(spec::FontSpec, [atlas]) -> Ptr{ImFont}

Download `spec` (if not cached) and add it to the imgui font `atlas`, defaulting to the
current context's atlas. With Dear ImGui ≥ 1.92's dynamic font system no glyph ranges or
size need to be passed. Returns the `Ptr{ImFont}` (use with `CImGui.PushFont` or
`CImGui.GetIO().FontDefault`).
"""
CImGui.AddFontFromFileTTF(atlas::Ptr{CImGui.lib.ImFontAtlas}, spec::FontSpec) = CImGui.AddFontFromFileTTF(atlas, font_path(spec))
CImGui.AddFontFromFileTTF(spec::FontSpec) = CImGui.AddFontFromFileTTF(unsafe_load(CImGui.GetIO().Fonts), spec)
