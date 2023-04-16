push!(LOAD_PATH,"../src/")

using Documenter, JlrsCore, JlrsCore.Reflect, JlrsCore.Wrap, JlrsCore.Ledger
makedocs(
    sitename="JlrsCore",
    modules = [JlrsCore.Reflect, JlrsCore.Wrap, JlrsCore.Ledger]
)