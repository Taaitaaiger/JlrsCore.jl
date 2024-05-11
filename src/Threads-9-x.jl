module Threads

const wakerust = Ref{Ptr{Cvoid}}(C_NULL)

function asynccall(func::Function, wakeptr::Ptr{Cvoid}, args...; kwargs...)::Task
    @nospecialize func wakeptr args kwargs
    Base.Threads.@spawn :default begin
        try
            Base.invokelatest(func, args...; kwargs...)
        finally
            if wakeptr != C_NULL
                ccall(wakerust[], Cvoid, (Ptr{Cvoid},), wakeptr)
            end
        end
    end
end

function asynccall(func::Function, args...; kwargs...)::Task
    @nospecialize func args kwargs
    Base.Threads.@spawn :default Base.invokelatest(func, args...; kwargs...)
end

function interactivecall(func::Function, wakeptr::Ptr{Cvoid}, args...; kwargs...)::Task
    @nospecialize func wakeptr args kwargs
    Base.Threads.@spawn :interactive begin
        try
            Base.invokelatest(func, args...; kwargs...)
        finally
            if wakeptr != C_NULL
                ccall(wakerust[], Cvoid, (Ptr{Cvoid},), wakeptr)
            end
        end
    end
end

function interactivecall(func::Function, args...; kwargs...)::Task
    @nospecialize func args kwargs
    Base.Threads.@spawn :interactive Base.invokelatest(func, args...; kwargs...)
end


scheduleasynclocal(func::Function, wakeptr::Ptr{Cvoid}, args...; kwargs...)::Task = interactivecall(func, wakeptr, args...; kwargs...)
scheduleasynclocal(func::Function, args...; kwargs...)::Task = interactivecall(func, args...; kwargs...)
scheduleasync(func::Function, wakeptr::Ptr{Cvoid}, args...; kwargs...)::Task = asynccall(func, wakeptr, args...; kwargs...)
scheduleasync(func::Function, args...; kwargs...)::Task = asynccall(func, args...; kwargs...)

function postblocking(func::Ptr{Cvoid}, task::Ptr{Cvoid}, wakeptr::Ptr{Cvoid})::Task
    Base.Threads.@spawn :default begin
        try
            ccall(func, Cvoid, (Ptr{Cvoid},), task)
        finally
            if wakeptr != C_NULL
                ccall(wakerust[], Cvoid, (Ptr{Cvoid},), wakeptr)
            end
        end
    end
end

# If all handles are dropped before the main thread starts waiting,
# notify_main can be called before wait_main is. Because both functions are
# only called once, we need to check in wait_main whether we've already been
# notified, and in notify_main if wait_main is waiting on the condition and
# only notify the condition in that case.
const wait_condition = Base.Threads.Condition()
const wait_lock = Base.ReentrantLock()
const has_waited = Ref(false)
const was_notified = Ref(false)

function wait_main()
    lock(wait_lock)

    if was_notified[] == false
        has_waited[] = true
        lock(wait_condition)

        try
            # Unlock wait_lock here so we don't hold it while we're waiting,
            # that would deadlock with notify_main. wait_condition won't be
            # unlocked until we've started waiting so notify_main can and 
            # must notify it.
            unlock(wait_lock)
            wait(wait_condition)
        finally
            unlock(wait_condition)
        end
    else
        unlock(wait_lock)
    end
end

function notify_main()
    lock(wait_lock)
    was_notified[] = true

    try
        if has_waited[] == true
            lock(wait_condition)

            try
                notify(wait_condition)
            finally
                unlock(wait_condition)
            end
        end
    finally
        unlock(wait_lock)
    end
end
end
