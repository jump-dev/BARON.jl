import MathOptInterface
import MathOptInterface: Utilities

const MOI = MathOptInterface
const MOIU = MOI.Utilities

# indices
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# function aliases
const SV = MOI.SingleVariable
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
    options
end

MOIU.@model(Model, # modelname
    (MOI.ZeroOne, MOI.Integer), # scalarsets
    (MOI.Interval, MOI.LessThan, MOI.GreaterThan, MOI.EqualTo), # typedscalarsets
    (), # vectorsets
    (), # typedvectorsets
    (MOI.SingleVariable,), # scalarfunctions
    (MOI.ScalarAffineFunction, MOI.ScalarQuadraticFunction), # typedscalarfunctions
    (), # vectorfunctions
    () # typedvectorfunctions
)

Optimizer(; options...) = Optimizer(BaronModel(; options...), nothing, options)

# empty
function MOI.is_empty(model::Optimizer)
    BARON.is_empty(model.inner) && model.nlp_block_data === nothing
end

function MOI.empty!(model::Optimizer)
    model.inner = BaronModel(; model.options...)
    model.nlp_block_data = nothing
end

# copy
function MOI.copy_to(dest::Optimizer, src::MOI.ModelLike; kws...)
    return MOIU.automatic_copy_to(dest, src; kws...)
end

# allocate-load interface
MOIU.supports_allocate_load(model::Optimizer, copy_names::Bool) = true

MOIU.allocate(model::Optimizer, args...) = nothing

function MOIU.allocate_constraint(model::Optimizer, f::MOI.AbstractFunction, s::MOI.AbstractSet)
    constraint_info = model.inner.constraint_info
    push!(constraint_info, ConstraintInfo())
    return CI{typeof(f), typeof(s)}(length(constraint_info))
end

function MOIU.allocate_constraint(model::Optimizer, f::SV, s::MOI.AbstractSet)
    # use negative indices for variable bounds
    CI{typeof(f), typeof(s)}(-f.variable.value)
end

# optimize
function MOI.optimize!(model::Optimizer)
    write_bar_file(model.inner)
    run(`$baron_exec $(model.inner.problem_file_name)`)
    read_results(model.inner)
end

include(joinpath("moi", "util.jl"))
include(joinpath("moi", "variables.jl"))
include(joinpath("moi", "constraints.jl"))
include(joinpath("moi", "objective.jl"))
include(joinpath("moi", "results.jl"))
