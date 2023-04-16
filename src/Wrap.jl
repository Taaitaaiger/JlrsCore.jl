module Wrap

# This module has been adapted from CxxWrap:
# https://github.com/JuliaInterop/CxxWrap.jl/blob/709c18788fec41ef27d034c33d53aa21742c147c/src/CxxWrap.jl

import Libdl
import JlrsCore
import Base.Docs: Binding, docstr, doc!

export @wrapmodule, @initjlrs, AsyncCCall

# Encapsulate information about a function
mutable struct JlrsFunctionInfo
    name::Any
    ccall_argument_types::Array{Type,1}
    julia_argument_types::Array{Type,1}
    ccall_return_type::Type
    julia_return_type::Type
    function_pointer::Ptr{Cvoid}
    override_module::Module
    async_func::Bool
end

struct AsyncCCall
    join_handle::Ptr{Cvoid}
    join_func::Ptr{Cvoid}
end

struct DocItem
    mod::Module
    item::Symbol
    signature
    doc::String
end

struct JlrsModuleInfo
    func_info::Vector{JlrsFunctionInfo}
    docs::Vector{DocItem}
end

# Type of the key used in the global function list, used to uniquely identify methods
const MethodKey = Tuple{Symbol,Symbol,UInt}

function _module_name_hash(mod::Module, previous_hash=UInt(0))
    parent = parentmodule(mod)
    if parent == mod || parent == Main
      return hash(nameof(mod), previous_hash)
    end
    return _module_name_hash(parent, hash(nameof(mod), previous_hash))
end

# Return a unique key for the given function, not taking into account the pointer values. This key has to be stable between Julia runs.
function methodkey(f::JlrsFunctionInfo)
    mhash = UInt(0)
    for arg in f.julia_argument_types
      mhash = hash(arg, mhash)
    end
    mhash = hash(f.julia_return_type, mhash)
    mhash = hash(_module_name_hash(f.override_module), mhash)
    return (f.name, nameof(f.override_module), mhash)
  end

# Pointers to function and thunk
const FunctionPointer = Tuple{Ptr{Cvoid},Bool}

# Store a unique map between methods and their pointer, filled whenever a method is created in a module
# This solves a problem with e.g. vectors of vectors of vectors of... where it is impossible to predict
# how many times and in which module a method will be defined
# This map is used to update a per-module vector of pointers upon module initialization, so it doesn't slow
# down each function call
const __global_method_map = Dict{MethodKey, FunctionPointer}()

function _register_function_pointers(func, precompiling)
    mkey = methodkey(func)
    fptrs = (func.function_pointer, precompiling)

    if haskey(__global_method_map, mkey)
        existing = __global_method_map[mkey]
        if existing[2] == precompiling
            error("Double registration for method $mkey")
        end
    end

    __global_method_map[mkey] = fptrs
    return (mkey, fptrs)
end

function _get_function_pointer(mkey)
    if !haskey(__global_method_map, mkey)
        error("Unregistered method with key $mkey requested, maybe you need to precompile the Julia module?")
    end

    return __global_method_map[mkey]
end

function register_julia_module(mod::Module, fptr::Ptr{Cvoid}, precompiling::UInt8)::Union{Nothing, JlrsModuleInfo}
    ccall(fptr, Any, (Any, UInt8), mod, precompiling)
end

function initialize_julia_module(mod::Module)
    lib = Libdl.dlopen(mod.__jlrswrap_sopath, mod.__jlrswrap_flags)

    fptr = Libdl.dlsym(lib, mod.__jlrswrap_init_func)
    modinfo = register_julia_module(mod, fptr, 0x0)
    if isnothing(modinfo)
        return
    end

    precompiling = false

    for func in modinfo.func_info
        _register_function_pointers(func, precompiling)
    end

    for (fidx,mkey) in enumerate(mod.__jlrswrap_methodkeys)
        mod.__jlrswrap_pointers[fidx] = _get_function_pointer(mkey)
    end
end

function process_fname(fn::Tuple{Symbol,Module}, julia_mod)
    (fname, mod) = fn
    if mod != julia_mod # Adding a method to a function from another module
        return :($mod.$fname)
    end
    return fname # defining a new function in the wrapped module, or adding a method to it
end

make_func_declaration(fn, argmap, julia_mod) = :($(process_fname(fn, julia_mod))($(argmap...)))

# Build the expression to wrap the given function
function build_function_expression(func::JlrsFunctionInfo, funcidx, julia_mod)
    # Arguments and types
    argtypes = func.julia_argument_types
    argsymbols = map((i) -> Symbol(:arg,i[1]), enumerate(argtypes))

    # Build the types for the ccall argument list
    c_arg_types = func.ccall_argument_types
    c_return_type = func.ccall_return_type
    jl_return_type = func.julia_return_type

    # Build the final call expression
    call_exp = if !func.async_func
        quote
            @inbounds ccall(__jlrswrap_pointers[$funcidx][1], $c_return_type, ($(c_arg_types...),), $(argsymbols...))
        end
    else
        quote
            cond = Base.AsyncCondition()
            GC.@preserve $(argsymbols...) begin
                async_call = @inbounds ccall(__jlrswrap_pointers[$funcidx][1], $c_return_type, ($(c_arg_types...),), cond.handle, $(argsymbols...))
                wait(cond)
                ccall(async_call.join_func, Any, (Ptr{Cvoid},), async_call.join_handle)
            end
        end
    end

    function argmap(signature)
        result = Expr[]
        for (t, s) in zip(signature, argsymbols)
          push!(result, :($s::$t))
        end

        return result
      end

    function_expression = :($(make_func_declaration((func.name,func.override_module), argmap(argtypes), julia_mod))::$(jl_return_type) = $call_exp)
    return function_expression
end

# Wrap functions from the JlrsCore module to the passed julia module
function wrap_functions(functions, julia_mod)
    if !isempty(julia_mod.__jlrswrap_pointers)
        empty!(julia_mod.__jlrswrap_methodkeys)
        empty!(julia_mod.__jlrswrap_pointers)
    end

    precompiling = true

    for func in functions
        (mkey,fptrs) = _register_function_pointers(func, precompiling)
        push!(julia_mod.__jlrswrap_methodkeys, mkey)
        push!(julia_mod.__jlrswrap_pointers, fptrs)
        funcidx = length(julia_mod.__jlrswrap_pointers)

        Core.eval(julia_mod, build_function_expression(func, funcidx, julia_mod))
    end
end

function generate_docs(filename, doc_items::Vector{DocItem})
    for item in doc_items
        binding = Binding(item.mod, item.item)
        docstring = docstr(item.doc)
        docstring.data[:path] = filename
        docstring.data[:module] = item.mod
        doc!(item.mod, binding, docstring, item.signature)
    end
end

function wrapmodule(so_path::AbstractString, init_fn_name, m::Module, filename, flags)
    if isdefined(m, :__jlrswrap_methodkeys)
        return
    end

    if flags === nothing
        flags = Libdl.RTLD_LAZY | Libdl.RTLD_DEEPBIND
    end

    init_funcname = string(init_fn_name)

    Core.eval(m, :(const __jlrswrap_methodkeys = $(MethodKey)[]))
    Core.eval(m, :(const __jlrswrap_pointers = $(FunctionPointer)[]))
    Core.eval(m, :(const __jlrswrap_sopath = $so_path))
    Core.eval(m, :(const __jlrswrap_init_func = $(QuoteNode(init_funcname))))
    Core.eval(m, :(const __jlrswrap_flags = $flags))

    fptr = Libdl.dlsym(Libdl.dlopen(so_path, flags), init_funcname)
    modinfo = register_julia_module(m, fptr, 0x1)
    if isnothing(modinfo)
        return
    end

    wrap_functions(modinfo.func_info, m)
    generate_docs(filename, modinfo.docs)
end

"""
    @wrapmodule libraryfile init_fn_name [flags]

Place the functions, exported types, constants, and globals exported by the Rust library into the
module enclosing this macro call by calling an entrypoint named `init_fn_name`. This entrypoint
must have been generated with the `julia_module` macro provided by the jlrs crate.
"""
macro wrapmodule(libraryfile, init_fn_name, flags=:(nothing))
    return :(wrapmodule($(esc(libraryfile)), $(esc(init_fn_name)),$__module__, @__FILE__, $(esc(flags))))
end

"""
    @initjlrs

Initialize the Rust function pointer tables in a precompiled module and reinitialize exported
types. Must be called from within `__init__` in the wrapped module.
"""
macro initjlrs()
    return :(initialize_julia_module($__module__))
end
end
