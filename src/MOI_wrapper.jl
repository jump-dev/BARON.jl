import MathOptInterface
const MOI = MathOptInterface

# indices
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# function aliases
const SV = MOI.SingleVariable
const SAF = MOI.ScalarAffineFunction{Float64}
const SQF = MOI.ScalarQuadraticFunction{Float64}
const SATerm = MOI.ScalarAffineTerm{Float64}
const SQTerm = MOI.ScalarQuadraticTerm{Float64}

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
    options
end

Optimizer(;options...) = Optimizer(BaronModel(;options...), nothing, options)

function MOI.is_empty(model::Optimizer)
    BARON.is_empty(model.inner) &&  model.nlp_block_data === nothing
end

function MOI.empty!(model::Optimizer)
    model.inner = BaronModel(; model.options...)
    model.nlp_block_data = nothing
end

MOI.Utilities.supports_default_copy_to(model::Optimizer, copy_names::Bool) = true
function MOI.copy_to(dest::Optimizer, src::MOI.ModelLike; kws...)
    return MOI.Utilities.automatic_copy_to(dest, src; kws...)
end

function MOI.optimize!(model::Optimizer)
    write_bar_file(model.inner)
    run(`$baron_exec $(model.inner.problem_file_name)`)
    read_results(model.inner)
end

# Copied from SCIP.jl:
"Extract bounds from sets."
bounds(set::MOI.EqualTo) = (set.value, set.value)
bounds(set::MOI.GreaterThan) = (set.lower, nothing)
bounds(set::MOI.LessThan) = (nothing, set.upper)
bounds(set::MOI.Interval) = (set.lower, set.upper)

# comparator_symbol(::Type{<:MOI.EqualTo}) = :(==)
# comparator_symbol(::Type{<:MOI.GreaterThan}) = :(>=)
# comparator_symbol(::Type{<:MOI.LessThan}) = :(<=)

include(joinpath("moi", "util.jl"))
include(joinpath("moi", "variable.jl"))
include(joinpath("moi", "linear_constraints.jl"))
include(joinpath("moi", "quadratic_constraints.jl"))
include(joinpath("moi", "nonlinear_constraints.jl"))
include(joinpath("moi", "integrality_constraints.jl"))
include(joinpath("moi", "objective.jl"))
include(joinpath("moi", "results.jl"))
