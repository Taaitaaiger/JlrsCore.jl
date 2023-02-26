push!(LOAD_PATH,"../src/")

using Documenter, Jlrs, Jlrs.Reflect, Jlrs.Wrap, Jlrs.Ledger
makedocs(
    sitename="Jlrs",
    modules = [Jlrs.Reflect, Jlrs.Wrap, Jlrs.Ledger]
)