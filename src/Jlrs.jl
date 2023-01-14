module Jlrs

const version = v"0.1.0"

const color = Ref{Bool}(false)

# The ledger and foreign type registry can't be accessed from Julia, but they're defined here to
# ensure that this information is globally shared even if multiple copies of jlrs are used in
# different packages.
const foreign_type_registry = Ref{Ptr{Cvoid}}(C_NULL)
const ledger = Ref{Ptr{Cvoid}}(C_NULL)

using Base: @lock
import Base: convert

# Call show and write the output to a string.
function valuestring(value)::String
    io = IOBuffer()
    show(io, "text/plain", value)
    String(take!(io))
end

# Call showerror and write the output to a string.
function errorstring(value)::String
    io = IOBuffer()
    showerror(IOContext(io, :color => color[], :compact => true, :limit => true), value)
    String(take!(io))
end

# Exception thrown when data can't be borrowed.
struct BorrowError <: Exception end

# Throwing a Julia exception directly from Rust is generally unsound. A RustResult contains either a
# value of type T, or an exception. If is_exc is false, the data is converted to T and returned,
# otherwise the exception is thrown.
mutable struct RustResult{T}
    data
    is_exc::Bool
end

convert(::Type{T}, data::RustResult{T}) where T = data()
convert(::Type{Nothing}, data::Jlrs.RustResult{Nothing}) = data()

function (res::RustResult{T})() where T
    if res.is_exc
        throw(res.data)
    else
        return res.data
    end
end

# A Dict containing the root modules of all loaded packages is maintained to be able to
# easily access these modules from Rust .
const loaded_packages = Dict{Symbol, Module}()
const package_lock = ReentrantLock()

# Returns the root module of the package with the name package_name if this package has been
# loaded.
function root_module(package_name)
    @lock package_lock get(loaded_packages, package_name, nothing)
end

const root_module_c = Ref(Ptr{Cvoid}(C_NULL))

# Adds the root module of this package to loaded_packages. This function is called automatically
# when a package is loaded.
function add_to_loaded_packages(pkg_id)
    @lock package_lock loaded_packages[Symbol(pkg_id.name)] = Base.root_module(pkg_id)
end

const init_lock = ReentrantLock()

# Calls the function that initializes ledger, the function is implemented in Rust:
# ::jlrs::memory::ledger::init_ledger
function init_ledger(func::Ptr{Cvoid})
    @lock init_lock begin
        ccall(func, Cvoid, (Any,), ledger)
    end
end

# Calls the function that initializes foreign_type_registry, the function is implemented in Rust:
# ::jlrs::data::layout::foreign::init_foreign_type_registry
function init_foreign_type_registry(func::Ptr{Cvoid})
    @lock init_lock begin
        ccall(func, Cvoid, (Any,), foreign_type_registry)
    end
end

# Called from Rust to ensure the `Stack` type is only created once.
function lock_init_lock()
    lock(init_lock)
end

# Called from Rust to ensure the `Stack` type is only created once.
function unlock_init_lock()
    unlock(init_lock)
end

if VERSION.minor >= 9
    include("Threads-9-x.jl")
else
    include("Threads-6-8.jl")
end

include("Reflect.jl")

include("Wrap.jl")

function __init__()
    # Calling root_module as an extern "C" function from Rust is approximately twice as fast as
    # using jl_call on my machine.
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
