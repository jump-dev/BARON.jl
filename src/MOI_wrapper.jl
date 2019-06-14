import MathOptInterface
const MOI = MathOptInterface

mutable struct Optimizer <: MOI.AbstractOptimizer
    inner::Union{Nothing, BaronModel}
    nlp_block_data::Union{Nothing, MOI.NLPBlockData}
    options
end

Optimizer(;options...) = Optimizer(BaronModel(;options...), nothing, options)

function MOI.is_empty(model::Optimizer)
    (model.inner === nothing || BARON.is_empty(model.inner)) &&  model.nlp_block_data === nothing
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

include(joinpath("moi", "variable.jl"))
include(joinpath("moi", "linear_constraints.jl"))
include(joinpath("moi", "quadratic_constraints.jl"))
include(joinpath("moi", "nonlinear_constraints.jl"))
include(joinpath("moi", "integrality_constraints.jl"))
include(joinpath("moi", "objective.jl"))
include(joinpath("moi", "results.jl"))
