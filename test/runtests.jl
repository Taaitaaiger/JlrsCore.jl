using Jlrs.Reflect
using Test

include("AbstractTypes.jl")
include("SingleFieldBits.jl")
include("Mutable.jl")
include("MultiFieldBits.jl")
include("BitsWithCustom.jl")
include("BitsWithTuples.jl")
include("WithBuiltinFields.jl")
include("WithGenericFields.jl")
include("WithBitsUnion.jl")
include("WithNonBitsUnion.jl")
include("ZeroSized.jl")

if hasproperty(DataType.name, :atomicfields)
    include("AtomicFields.jl")
end
