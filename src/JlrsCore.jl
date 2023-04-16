module JlrsCore

using Base: @lock
import Base: convert
export set_pool_size, BorrowError, JlrsError, RustResult

const JLRS_API_VERSION = 1

# TODO: Thread-safety
const color = Ref{Bool}(false)

struct Pool
    set_pool_size_fn::Ptr{Cvoid}
end

const pools = Dict{Module,Pool}()
const init_lock = ReentrantLock()

"""
    set_pool_size(mod, size)

Sets the size of the thread pool if one is available for the module. A module has a thread pool
if it was created with jlrs' `julia_module` macro, the pool is used to execute callbacks without
blocking Julia.

The size of the pool must be larger than 0, otherwise an `ArgumentError` is thrown. If no pool is
known for the module, a `KeyError` is thrown. No active threads are killed by calling this
function.
"""
function set_pool_size(mod::Module, size::Unsigned)
    if size == 0
        throw(ArgumentError("size must be greater than 0"))
    end

    @lock init_lock begin
        set_pool_size_fn = pools[mod].set_pool_size_fn
        ccall(set_pool_size_fn, Cvoid, (UInt,), size)
    end

    nothing
end

function add_pool(mod::Module, set_pool_size_fn::Ptr{Cvoid})
    @lock init_lock begin
        if haskey(pools, mod)
            throw(ErrorException("Pool for module $mod already exists"))
        end

        pools[mod] = Pool(set_pool_size_fn)
    end

    nothing
end

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

"""
A pending exception.

Throwing a Julia exception directly from Rust is generally unsound. A RustResult contains either a
value of type T, or an exception. If is_exc is false, the data is converted to T and returned,
otherwise the exception is thrown.

Sometimes this conversion is ambiguous. This can typically be solved by providing a custom
implementation of `convert`, which can be implemented as
`Base.convert(::Type{T}, data::RustResult{T}) = data()`
where T has to be replaced with the problematic type. When this error occurs, the correct
signature is part of the error message.
"""
mutable struct RustResult{T}
    data
    is_exc::Bool
end

struct JlrsCatch
    tag::UInt32
    error::Ptr{Cvoid}
end

function call_catch_wrapper(func::Ptr{Cvoid}, callback::Ptr{Cvoid}, trampoline::Ptr{Cvoid}, result::Ptr{Cvoid}, frame_slice::Ptr{Cvoid})::JlrsCatch
    ccall(func, JlrsCatch, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}), callback, trampoline, result, frame_slice)
end

convert(::Type{T}, data::RustResult{T}) where {T} = data()
convert(::Type{Nothing}, data::JlrsCore.RustResult{Nothing}) = data()
convert(::Type{Any}, data::JlrsCore.RustResult{Any}) = data()

function (res::RustResult{T})() where {T}
    if res.is_exc
        throw(res.data)
    else
        return res.data
    end
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

const root_module_c = Ref(Ptr{Cvoid}(C_NULL))

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

if VERSION.minor >= 9
    include("Threads-9-x.jl")
else
    include("Threads-6-8.jl")
end

include("Ledger.jl")
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
