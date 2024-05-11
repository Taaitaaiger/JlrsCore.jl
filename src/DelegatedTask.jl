mutable struct DelegatedTask
    fetch_fn::Ptr{Cvoid}
    thread_handle::Ptr{Cvoid}
    cond::Base.AsyncCondition
    @atomic result
    DelegatedTask() = throw(JlrsException("DelegatedTask can only be created from Rust"))
end

function Base.fetch(t::DelegatedTask)
    wait(t.cond)
    ccall(t.fetch_fn, Any, (Any,), t)
end
