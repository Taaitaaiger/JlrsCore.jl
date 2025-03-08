mutable struct BackgroundTask{T}
    fetch_fn::Ptr{Cvoid}
    thread_handle::Ptr{Cvoid}
    cond::Base.AsyncCondition
    result::T
    BackgroundTask() = throw(JlrsException("BackgroundTask can only be created from Rust"))
end

function Base.fetch(@nospecialize t::BackgroundTask{T})::T where {T}
    wait(t.cond)
    ccall(t.fetch_fn, Ref{T}, (Any,), t)
end
