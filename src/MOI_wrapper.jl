import MathOptInterface
import MathOptInterface: Utilities

const MOI = MathOptInterface
const MOIU = MOI.Utilities

# indices
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# function aliases
const SAF = MOI.ScalarAffineFunction{Float64}
const SQF = MOI.ScalarQuadraticFunction{Float64}

# set aliases
const Bounds{T} = Union{
    MOI.EqualTo{T},
    MOI.GreaterThan{T},
    MOI.LessThan{T},
    MOI.Interval{T}
}

mutable struct Optimizer <: MOI.AbstractOptimizer
    inner::BaronModel
    nlp_block_data::Union{Nothing, MOI.NLPBlockData}
end

Optimizer(; options...) = Optimizer(BaronModel(; options...), nothing)

MOI.get(model::Optimizer, ::MOI.SolverName) = "BARON"

# empty
function MOI.is_empty(model::Optimizer)
    BARON.is_empty(model.inner) && model.nlp_block_data === nothing
end

function MOI.empty!(model::Optimizer)
    model.inner = BaronModel(; ((Symbol(key), val) for (key, val) in model.inner.options)...)
    model.nlp_block_data = nothing
    return
end

# copy
# MOIU.supports_default_copy_to(::Optimizer, copy_names::Bool) = !copy_names
MOI.supports_incremental_interface(::Optimizer) = true
function MOI.copy_to(dest::Optimizer, src::MOI.ModelLike; kws...)
    return MOIU.default_copy_to(dest, src; kws...)
end

# optimize
function MOI.optimize!(model::Optimizer)
    if !IS_SOLVER_SET
        error(("""BARON.jl was not built correctly.
                 Set the environment variable `BARON_EXEC` and run `using Pkg; Pkg.build("BARON")`."""))
    end
    write_bar_file(model.inner)
    if model.inner.print_input_file
        println("\nBARON input file: $(model.inner.problem_file_name)\n")
        println(read(model.inner.problem_file_name, String))
    end
    try
        run(`$baron_exec $(model.inner.problem_file_name)`)
    catch e
        println("$e")
        println(read(model.inner.problem_file_name, String))
        error("failed to call BARON exec $baron_exec")
    end
    read_results(model.inner)
end

# RawOptimizerAttribute
MOI.supports(::Optimizer, ::MOI.RawOptimizerAttribute) = true
function MOI.set(model::Optimizer, param::MOI.RawOptimizerAttribute, value)
    model.inner.options[param.name] = value
    return
end
function MOI.get(model::Optimizer, param::MOI.RawOptimizerAttribute)
    return get(model.inner.options, param.name) do
        throw(ErrorException("Requested parameter $(param.name) is not set."))
    end
end

# TimeLimitSec
MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true
function MOI.set(model::Optimizer, ::MOI.TimeLimitSec, val::Real)
    model.inner.options["MaxTime"] = Float64(val)
    return
end

# BARON's default time limit is 1000 seconds.
function MOI.get(model::Optimizer, ::MOI.TimeLimitSec)
    return get(model.inner.options, "MaxTime", 1000.0)
end

struct PrintInputFile <: MOI.AbstractOptimizerAttribute end
function MOI.set(model::Optimizer, ::PrintInputFile, val::Bool)
    model.inner.print_input_file = val
    return
end
function MOI.get(model::Optimizer, ::PrintInputFile)
    model.inner.print_input_file
end

include(joinpath("moi", "util.jl"))
include(joinpath("moi", "variables.jl"))
include(joinpath("moi", "constraints.jl"))
include(joinpath("moi", "objective.jl"))
include(joinpath("moi", "nlp.jl"))
include(joinpath("moi", "results.jl"))
