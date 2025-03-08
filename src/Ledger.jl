module Ledger
import Libdl
import JlrsLedger_jll: libjlrs_ledger_handle

"""
The current version of the ledger API.

If the API version of JlrsLedger_jll and this version don't match, this module will fail to
initialize.
"""
const LEDGER_API_VERSION = 0x3

const API_VERSION_FN = Ref{Ptr{Cvoid}}(C_NULL)
const IS_BORROWED_SHARED = Ref{Ptr{Cvoid}}(C_NULL)
const IS_BORROWED_EXCLUSIVE = Ref{Ptr{Cvoid}}(C_NULL)
const IS_BORROWED = Ref{Ptr{Cvoid}}(C_NULL)
const BORROW_SHARED = Ref{Ptr{Cvoid}}(C_NULL)
const BORROW_EXCLUSIVE = Ref{Ptr{Cvoid}}(C_NULL)
const UNBORROW_SHARED = Ref{Ptr{Cvoid}}(C_NULL)
const UNBORROW_EXCLUSIVE = Ref{Ptr{Cvoid}}(C_NULL)

export LedgerError, PoisonError, is_borrowed, is_borrowed_exclusive, is_borrowed_shared,
       try_borrow_exclusive, try_borrow_shared, borrow_shared_unchecked, unborrow_exclusive,
       unborrow_shared, LEDGER_API_VERSION

"""
An exception that indicates the ledger was used incorrectly.
"""
struct LedgerError <: Exception end

"""
    is_borrowed_shared(data)

Returns `true` if there is at least one active shared borrow of this data.
"""
function is_borrowed_shared(data)
    if !ismutable(data)
        return false
    end

    res = ccall(IS_BORROWED_SHARED[], Int32, (Ptr{Cvoid},), data)
    if res >= 0
        Bool(res)
    else
        throw(LedgerError())
    end
end

"""
    is_borrowed_exclusive(data)

Returns `true` if this data is exclusively borrowed.
"""
function is_borrowed_exclusive(data)
    if !ismutable(data)
        return false
    end

    res = ccall(IS_BORROWED_EXCLUSIVE[], Int32, (Ptr{Cvoid},), data)
    if res >= 0
        Bool(res)
    else
        throw(LedgerError())
    end
end


"""
    is_borrowed(data)

Returns `true` if this data is borrowed. Equivalent to
`is_borrowed_shared(data) || is_borrowed_exclusive(data)`.
"""
function is_borrowed(data)
    if !ismutable(data)
        return false
    end

    res = ccall(IS_BORROWED[], Int32, (Ptr{Cvoid},), data)
    if res >= 0
        Bool(res)
    else
        throw(LedgerError())
    end
end

"""
    try_borrowed_shared(data)

Marks the data as being borrowed if the data isn't exclusively borrowed. Returns `true` on
success, `false` if the data is already borrowed exclusively. If `true` is returned you must call
`unborrow_shared` when you're done using it.
"""
function try_borrow_shared(data)
    if !ismutable(data)
        return true
    end

    res = ccall(BORROW_SHARED[], Int32, (Ptr{Cvoid},), data)
    if res >= 0
        Bool(res)
    else
        throw(LedgerError())
    end
end

"""
    try_borrowed_exclusive(data)

Marks the data as being borrowed exclusively if the data isn't already borrowed. Returns `true` on
success, `false` if the data is already borrowed. If `true` is returned you must call
`unborrow_exclusive` when you're done using it.
"""
function try_borrow_exclusive(data)
    if !ismutable(data)
        return false
    end

    res = ccall(BORROW_EXCLUSIVE[], Int32, (Ptr{Cvoid},), data)
    if res >= 0
        Bool(res)
    else
        throw(LedgerError())
    end
end

"""
    unborrow_shared(data)

Ends an active shared borrow. Returns `true` if the borrow was successfully removed from the
ledger, `false` if other active shared borrows still exist, a `LedgerError` is thrown if the data
wasn't present in the ledger.

Each successfull call to `try_borrow_shared` and `borrow_shared_unchecked` must have a matching
call to this function.
"""
function unborrow_shared(data)
    if !ismutable(data)
        return true
    end

    res = ccall(UNBORROW_SHARED[], Int32, (Ptr{Cvoid},), data)
    if res >= 0
        Bool(res)
    else
        throw(LedgerError())
    end
end


"""
    unborrow_exclusive(data)

Ends an active exclusive borrow. Returns `true` if the borrow was successfully removed from the
ledger, a `LedgerError` is thrown if the data wasn't present in the ledger.

Each successfull call to `try_borrow_exclusive` must have a matching call to this function.
"""
function unborrow_exclusive(data)
    if !ismutable(data)
        return true
    end

    res = ccall(UNBORROW_EXCLUSIVE[], Int32, (Ptr{Cvoid},), data)
    if res >= 0
        Bool(res)
    else
        throw(LedgerError())
    end
end

function __init__()
    @assert libjlrs_ledger_handle != C_NULL "Library handle is null"

    API_VERSION_FN[] = api_version_fn = Libdl.dlsym(libjlrs_ledger_handle, "jlrs_ledger_api_version")
    @assert api_version_fn != C_NULL "API version function is null"

    api_version = ccall(api_version_fn, UInt, ())
    @assert api_version == LEDGER_API_VERSION "Incompatible version of jlrs_ledger"

    init_fn = Libdl.dlsym(libjlrs_ledger_handle, "jlrs_ledger_init")
    ccall(init_fn, Cvoid, ())

    IS_BORROWED_SHARED[] = Libdl.dlsym(libjlrs_ledger_handle, "jlrs_ledger_is_borrowed_shared")
    IS_BORROWED_EXCLUSIVE[] = Libdl.dlsym(libjlrs_ledger_handle, "jlrs_ledger_is_borrowed_exclusive")
    IS_BORROWED[] = Libdl.dlsym(libjlrs_ledger_handle, "jlrs_ledger_is_borrowed")
    BORROW_SHARED[] = Libdl.dlsym(libjlrs_ledger_handle, "jlrs_ledger_try_borrow_shared")
    BORROW_EXCLUSIVE[] = Libdl.dlsym(libjlrs_ledger_handle, "jlrs_ledger_try_borrow_exclusive")
    UNBORROW_SHARED[] = Libdl.dlsym(libjlrs_ledger_handle, "jlrs_ledger_unborrow_shared")
    UNBORROW_EXCLUSIVE[] = Libdl.dlsym(libjlrs_ledger_handle, "jlrs_ledger_unborrow_exclusive")
end
end
