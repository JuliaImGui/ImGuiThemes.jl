# src/app_icon.jl — set the application (dock) icon from an image file.

"""
    set_app_icon!(path)

Set the application icon to the image at `path`. On macOS this sets the **dock
icon** (`NSApplication`'s `applicationIconImage`); `path` may be any format AppKit
can decode (png, jpeg, icns, tiff, …). Currently a no-op with a warning on
non-macOS platforms. Returns `nothing`.
"""
function set_app_icon!(path::AbstractString)
    isfile(path) || throw(ArgumentError("no such file: $path"))
    Sys.isapple() || return (@warn "set_app_icon! is only implemented on macOS for now"; nothing)
    _set_dock_icon_macos(abspath(path))
end

# macOS dock icon via the Objective-C runtime (no ObjectiveC.jl dep). AppKit must be
# dlopen'd so NSApplication/NSImage are registered; in a running GLFW app it already is.
function _set_dock_icon_macos(path::AbstractString)
    Libdl.dlopen("/System/Library/Frameworks/AppKit.framework/AppKit"; throw_error = false)
    cls(n) = @ccall objc_getClass(n::Cstring)::Ptr{Cvoid}
    sel(n) = @ccall sel_registerName(n::Cstring)::Ptr{Cvoid}
    nsstr = @ccall objc_msgSend(cls("NSString")::Ptr{Cvoid}, sel("stringWithUTF8String:")::Ptr{Cvoid}, path::Cstring)::Ptr{Cvoid}
    alloc = @ccall objc_msgSend(cls("NSImage")::Ptr{Cvoid}, sel("alloc")::Ptr{Cvoid})::Ptr{Cvoid}
    img   = @ccall objc_msgSend(alloc::Ptr{Cvoid}, sel("initWithContentsOfFile:")::Ptr{Cvoid}, nsstr::Ptr{Cvoid})::Ptr{Cvoid}
    img == C_NULL && error("AppKit could not decode an image from $path")
    app = @ccall objc_msgSend(cls("NSApplication")::Ptr{Cvoid}, sel("sharedApplication")::Ptr{Cvoid})::Ptr{Cvoid}
    @ccall objc_msgSend(app::Ptr{Cvoid}, sel("setApplicationIconImage:")::Ptr{Cvoid}, img::Ptr{Cvoid})::Cvoid
    nothing
end
