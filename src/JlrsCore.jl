module JlrsCore

using Base: @lock
export BorrowError, JlrsError, set_color

const JLRS_API_VERSION = 4

mutable struct AtomicBool
     @atomic value::Bool
end

const ERROR_COLOR = AtomicBool(false)

function set_error_color(color::Bool)
    @atomic ERROR_COLOR.value = color
end

const init_lock = ReentrantLock()

# Call show and write the output to a string.
function valuestring(value)::String
    io = IOBuffer()
    show(io, "text/plain", value)
    String(take!(io))
end

# Call showerror and write the output to a string.
function errorstring(value)::String
    io = IOBuffer()
    color = @atomic ERROR_COLOR.value
    showerror(IOContext(io, :color => color, :compact => true, :limit => true), value)
    String(take!(io))
end

"""
Exception thrown when data can't be borrowed.
"""
struct BorrowError <: Exception end

"""
Exception thrown when a `JlrsError` is returned from an exported Rust function.
"""
struct JlrsError <: Exception
    msg::String
end

# A Dict containing the root modules of all loaded packages is maintained to be able to
# easily access these modules from Rust .
const loaded_packages = Dict{Symbol,Module}()
const package_lock = ReentrantLock()

# Returns the root module of the package with the name package_name if this package has been
# loaded.
function root_module(package_name)
    @lock package_lock get(loaded_packages, package_name, nothing)
end

const root_module_c = Ref{Ptr{Cvoid}}()

# Adds the root module of this package to loaded_packages. This function is called automatically
# when a package is loaded.
function add_to_loaded_packages(pkg_id)
    @lock package_lock loaded_packages[Symbol(pkg_id.name)] = Base.root_module(pkg_id)
end


# Called from Rust to ensure the `Stack` type is only created once.
function lock_init_lock()
    lock(init_lock)
end

# Called from Rust to ensure the `Stack` type is only created once.
function unlock_init_lock()
    unlock(init_lock)
end

include("Threads.jl")
include("DelegatedTask.jl")
include("BackgroundTask.jl")
include("Ledger.jl")
include("Reflect.jl")
include("Wrap.jl")

function __init__()
    root_module_c[] = @cfunction(root_module, Any, (Symbol,))

    @lock package_lock begin
        push!(Base.package_callbacks, add_to_loaded_packages)
        loaded = Base.loaded_modules_array()
        for mod in loaded
            loaded_packages[Symbol(mod)] = mod
        end
    end
end
end
