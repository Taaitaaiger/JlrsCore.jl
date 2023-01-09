push!(LOAD_PATH,"../src/")

using Documenter, Jlrs, Jlrs.Reflect, Jlrs.Wrap
makedocs(
    sitename="Jlrs",
    modules = [Jlrs.Reflect, Jlrs.Wrap]
)