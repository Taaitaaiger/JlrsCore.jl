module Ledger
import Libdl
using JlrsLedger_jll: libjlrs_ledger_handle

"""
The current version of the ledger API.

If the API version of JlrsLedger_jll and this version don't match, this module will fail to
initialize.
"""
const API_VERSION = 0x1

const API_VERSION_FN = Ref{Ptr{Cvoid}}(C_NULL)
const IS_BORROWED_SHARED = Ref{Ptr{Cvoid}}(C_NULL)
const IS_BORROWED_EXCLUSIVE = Ref{Ptr{Cvoid}}(C_NULL)
const IS_BORROWED = Ref{Ptr{Cvoid}}(C_NULL)
const BORROW_SHARED = Ref{Ptr{Cvoid}}(C_NULL)
const BORROW_EXCLUSIVE = Ref{Ptr{Cvoid}}(C_NULL)
const BORROW_SHARED_UNCHECKED = Ref{Ptr{Cvoid}}(C_NULL)
const UNBORROW_SHARED = Ref{Ptr{Cvoid}}(C_NULL)
const UNBORROW_EXCLUSIVE = Ref{Ptr{Cvoid}}(C_NULL)

export LedgerError, PoisonError, is_borrowed, is_borrowed_exclusive, is_borrowed_shared,
       try_borrow_exclusive, try_borrow_shared, borrow_shared_unchecked, unborrow_exclusive,
       unborrow_shared, API_VERSION

"""
An exception that indicates the ledger was used incorrectly and has likely been corrupted.
"""
struct LedgerError <: Exception end

"""
An exception that indicates that the internal lock of the ledger was poisoned.
"""
struct PoisonError <: Exception end

"""
    is_borrowed_shared(data)

Returns `true` if there is at least one active shared borrow of this data.
"""
function is_borrowed_shared(@nospecialize data::Any)
    res = ccall(IS_BORROWED_SHARED[], UInt8, (Ptr{Cvoid},), Base.pointer_from_objref(data))
    if res == 0x0
        false
    elseif res == 0x1
        true
    elseif res == 0x2
        throw(LedgerError())
    elseif res == 0x3
        throw(PoisonError())
    end
end

"""
    is_borrowed_exclusive(data)

Returns `true` if this data is exclusively borrowed.
"""
function is_borrowed_exclusive(@nospecialize data::Any)
    res = ccall(IS_BORROWED_EXCLUSIVE[], UInt8, (Ptr{Cvoid},), Base.pointer_from_objref(data))
    if res == 0x0
        false
    elseif res == 0x1
        true
    elseif res == 0x2
        throw(LedgerError())
    elseif res == 0x3
        throw(PoisonError())
    end
end


"""
    is_borrowed(data)

Returns `true` if this data is borrowed. Equivalent to
`is_borrowed_shared(data) || is_borrowed_exclusive(data)`.
"""
function is_borrowed(@nospecialize data::Any)
    res = ccall(IS_BORROWED[], UInt8, (Ptr{Cvoid},), Base.pointer_from_objref(data))
    if res == 0x0
        false
    elseif res == 0x1
        true
    elseif res == 0x2
        throw(LedgerError())
    elseif res == 0x3
        throw(PoisonError())
    end
end

"""
    try_borrowed_shared(data)

Marks the data as being borrowed if the data isn't exclusively borrowed. Returns `true` on
success, `false` if the data is already borrowed exclusively. If `true` is returned you must call
`unborrow_shared` when you're done using it.
"""
function try_borrow_shared(@nospecialize data::Any)
    res = ccall(BORROW_SHARED[], UInt8, (Ptr{Cvoid},), Base.pointer_from_objref(data))
    if res == 0x0
        false
    elseif res == 0x1
        true
    elseif res == 0x2
        throw(LedgerError())
    elseif res == 0x3
        throw(PoisonError())
    end
end


"""
    borrowed_shared_unchecked(data)

Marks the data as being borrowed. Always returns `true`, you must call  `unborrow_shared` when
you're done using it.
"""
function borrow_shared_unchecked(@nospecialize data::Any)
    res = ccall(BORROW_SHARED_UNCHECKED[], UInt8, (Ptr{Cvoid},), Base.pointer_from_objref(data))
    if res == 0x0
        false
    elseif res == 0x1
        true
    elseif res == 0x2
        throw(LedgerError())
    elseif res == 0x3
        throw(PoisonError())
    end
end

"""
    try_borrowed_exclusive(data)

Marks the data as being borrowed exclusively if the data isn't already borrowed. Returns `true` on
success, `false` if the data is already borrowed. If `true` is returned you must call
`unborrow_exclusive` when you're done using it.
"""
function try_borrow_exclusive(@nospecialize data::Any)
    res = ccall(BORROW_EXCLUSIVE[], UInt8, (Ptr{Cvoid},), Base.pointer_from_objref(data))
    if res == 0x0
        false
    elseif res == 0x1
        true
    elseif res == 0x2
        throw(LedgerError())
    elseif res == 0x3
        throw(PoisonError())
    end
end

"""
    unborrow_shared(data)

Ends an active shared borrow. Returns `true` if the borrow was successfully removed from the
ledger, a `LedgerError` is thrown if the data wasn't present in the ledger.

Each successfull call to `try_borrow_shared` and `borrow_shared_unchecked` must have a matching
call to this function.
"""
function unborrow_shared(@nospecialize data::Any)
    res = ccall(UNBORROW_SHARED[], UInt8, (Ptr{Cvoid},), Base.pointer_from_objref(data))
    if res == 0x0
        false
    elseif res == 0x1
        true
    elseif res == 0x2
        throw(LedgerError())
    elseif res == 0x3
        throw(PoisonError())
    end
end


"""
    unborrow_exclusive(data)

Ends an active exclusive borrow. Returns `true` if the borrow was successfully removed from the
ledger, a `LedgerError` is thrown if the data wasn't present in the ledger.

Each successfull call to `try_borrow_exclusive` must have a matching call to this function.
"""
function unborrow_exclusive(@nospecialize data::Any)
    res = ccall(UNBORROW_EXCLUSIVE[], UInt8, (Ptr{Cvoid},), Base.pointer_from_objref(data))
    if res == 0x0
        false
    elseif res == 0x1
        true
    elseif res == 0x2
        throw(LedgerError())
    elseif res == 0x3
        throw(PoisonError())
    end
end

function __init__()
    @assert libjlrs_ledger_handle != C_NULL "Library handle is null"

    API_VERSION_FN[] = api_version_fn = Libdl.dlsym(libjlrs_ledger_handle, "jlrs_ledger_api_version")
    @assert api_version_fn != C_NULL "API version function is null"

    api_version = ccall(api_version_fn, UInt, ())
    @assert api_version == API_VERSION "Incompatible version of jlrs_ledger"

    IS_BORROWED_SHARED[] = Libdl.dlsym(libjlrs_ledger_handle, "jlrs_ledger_is_borrowed_shared")
    IS_BORROWED_EXCLUSIVE[] = Libdl.dlsym(libjlrs_ledger_handle, "jlrs_ledger_is_borrowed_exclusive")
    IS_BORROWED[] = Libdl.dlsym(libjlrs_ledger_handle, "jlrs_ledger_is_borrowed")
    BORROW_SHARED[] = Libdl.dlsym(libjlrs_ledger_handle, "jlrs_ledger_try_borrow_shared")
    BORROW_EXCLUSIVE[] = Libdl.dlsym(libjlrs_ledger_handle, "jlrs_ledger_try_borrow_exclusive")
    BORROW_SHARED_UNCHECKED[] = Libdl.dlsym(libjlrs_ledger_handle, "jlrs_ledger_borrow_shared_unchecked")
    UNBORROW_SHARED[] = Libdl.dlsym(libjlrs_ledger_handle, "jlrs_ledger_unborrow_shared")
    UNBORROW_EXCLUSIVE[] = Libdl.dlsym(libjlrs_ledger_handle, "jlrs_ledger_unborrow_exclusive")
end
end
