# JlrsCore Documentation

This package must be used in combination with the jlrs crate for the Rust programming language. It provides core functionality that jlrs depends on, can be used to generate Rust structs from Julia struct, and generate Julia modules that have been (partially) implemented in Rust in combination with the `julia_module` macro from jlrs.

## JlrsCore

The main module of this package provides some functionality that is used by crates that use the `julia_module` macro to export functionality to Julia. There's a function that lets you configure the size of the thread pool associated with a package, and several custom error types.

### Types and methods

```@autodocs
Modules = [JlrsCore]
```


## JlrsCore.Reflect

The functions defined in the `Reflect` module can be used to generate jlrs-compatible Rust implementations of Julia structs (layouts).

Layouts can be generated for many structs, including structs with union fields, tuple fields, and type parameters. Layouts are recursively generated for all of a type's fields, and are always generated for the most general case; any provided type parameter is erased and included in the set of structs for which layouts are generated.

Three things that are not supported are structs with union or tuple fields that depend on a type parameter (eg `struct SomeGenericStruct{T} a::Tuple{Int32, T} end` and `struct SomeGenericStruct{T} a::Union{Int32, T} end`), unions used as generic parameters (eg `SomeGenericStruct{Union{A,B}}`), and structs with atomic fields. An error is thrown in the first two cases, in the final case no layout is generated for the struct itself but wrappers for all of its dependencies will be generated.

You can generate layouts by calling the `reflect` function with a `Vector` of types:

```julia
using JlrsCore.Reflect

struct TypeA
    # ...fields
end

struct TypeB{T}
    # ...fields
end

...

layouts = reflect([TypeA, TypeB, ...]);

# Print layouts to standard output
println(layouts)

# Write layouts to file
open("julia_layouts.rs", "w") do f
    write(f, layouts)
end
```

Layouts for types used as fields and type parameters are automatically generated. If you want or need to rename structs or their fields you can use `renamestruct!` and `renamefields!` as follows:

```julia
layouts = JlrsCore.Reflect.reflect([TypeA, TypeB, ...])
renamestruct!(layouts, TypeA, "StructA")
renamefields!(layouts, TypeB, [:fielda => "field_a", :fieldb => "field_b"])
```

### Methods

```@autodocs
Modules = [JlrsCore.Reflect]
```


## JlrsCore.Wrap

The macros defined in the `Wrap` module can be used to make the items exported by the `julia_module` macro available.

For example, let's say you have a crate called example that uses `julia_module` to generate an initialization function called `module_init_fn`:

```rust
julia_module! {
    become module_init_fn;
    // ...exported items
    // See the documentation for `julia_module` in the jlrs docs for more information about
    // what can be exported from Rust to Julia and how.
}
```

After the crate has been built (NB: the crate type must have been set to `cdylib` to build a shared library that can be used by Julia), the `@wrapmodule` and `@initjlrs` macros can be used to make the exported items available in Julia:

```julia
module Example
using JlrsCore.Wrap

# If the library has been distributed as a JLL package, e.g. `Example_jll`, you can replace the
# path to the library with `Example_jll.libexample_path` if `libexample` is the name of the
# `LibraryProduct`.
@wrapmodule("path/to/libexample", :module_init_fn)

function __init__()
    @initjlrs
end
end
```

### Macros

```@autodocs
Modules = [JlrsCore.Wrap]
```


## JlrsCore.Ledger

JlrsCore uses a ledger to track whether Julia data is currently borrowed. By tracking this information, it's safer to access data from Rust because it enforces Rust's borrowing rules at runtime. While this is mostly used internally, you can make use of this functionality from Julia to prevent data you're actively using in Julia to be accessed incorrectly from Rust.

```@autodocs
Modules = [JlrsCore.Ledger]
```
