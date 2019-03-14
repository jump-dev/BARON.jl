import MathOptInterface
const MOI = MathOptInterface

mutable struct Optimizer <: MOI.AbstractOptimizer
    inner::Union{Nothing, BaronModel}
    nlp_block_data::Union{Nothing, MOI.NLPBlockData}
    options
end

Optimizer(;options...) = Optimizer(BaronModel(;options...), nothing, options)

MOI.supports(::Optimizer, ::MOI.NLPBlock) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.LessThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.GreaterThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.ZeroOne}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.Integer}) = true

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

MOI.get(model::Optimizer, ::MOI.ListOfVariableIndices) = length(model.inner.variable_info)

function MOI.set(model::Optimizer, ::MOI.ObjectiveSense, sense::MOI.OptimizationSense)
    if model.inner.objective_info === nothing
        model.inner.objective_info = ObjectiveInfo()
    end
    if sense == MOI.MIN_SENSE
        model.inner.objective_info.sense = :Min
    else
        model.inner.objective_info.sense = :Max
    end
    return
end

function MOI.add_variable(model::Optimizer)
    push!(model.inner.variable_info, VariableInfo())
    return MOI.VariableIndex(length(model.inner.variable_info))
end

function MOI.add_variables(model::Optimizer, n::Int)
    return [MOI.add_variable(model) for i in 1:n]
end

function _check_inbounds(model::Optimizer, index::MOI.VariableIndex)
    @assert 1 <= index.value <= length(model.inner.variable_info)
end

MOI.supports(model::Optimizer, ::MOI.VariableName, ::Type{MOI.VariableIndex}) = true

function MOI.set(model::Optimizer, ::MOI.VariableName, vi::MOI.VariableIndex, value::AbstractString)
    _check_inbounds(model, vi)
    set_unique_variable_name!(model.inner, vi.value, value)
end

MOI.supports(::Optimizer, ::MOI.VariablePrimalStart, ::Type{MOI.VariableIndex}) = true

function MOI.set(model::Optimizer, ::MOI.VariablePrimalStart, vi::MOI.VariableIndex, value::Union{Real, Nothing})
    _check_inbounds(model, vi)
    model.inner.variable_info[vi.value].start = value
    return
end

function MOI.add_constraint(model::Optimizer, fun::MOI.SingleVariable, set::MOI.GreaterThan{Float64})
    vi = fun.variable
    _check_inbounds(model, vi)
    model.inner.variable_info[vi.value].lower_bound = set.lower
    return
end

function MOI.add_constraint(model::Optimizer, fun::MOI.SingleVariable, set::MOI.LessThan{Float64})
    vi = fun.variable
    _check_inbounds(model, vi)
    model.inner.variable_info[vi.value].upper_bound = set.upper
    return
end

function MOI.add_constraint(model::Optimizer, fun::MOI.SingleVariable, set::MOI.ZeroOne)
    vi = fun.variable
    _check_inbounds(model, vi)
    model.inner.variable_info[vi.value].category = :Bin
    return
end

function MOI.add_constraint(model::Optimizer, fun::MOI.SingleVariable, set::MOI.Integer)
    vi = fun.variable
    _check_inbounds(model, vi)
    model.inner.variable_info[vi.value].category = :Int
    return
end

function MOI.set(model::Optimizer, ::MOI.NLPBlock, nlp_block_data::MOI.NLPBlockData)
    model.nlp_block_data = nlp_block_data
    return
end

function MOI.optimize!(model::Optimizer)
    write_bar_file(model.inner)
    run(`$baron_exec $(model.inner.problem_file_name)`)
    read_results(model.inner)
end

function MOI.get(model::Optimizer, ::MOI.TerminationStatus)
    if model.inner === nothing || model.inner.solution_info === nothing
        return MOI.OPTIMIZE_NOT_CALLED
    end
    status = model.inner.solution_info.status
    if status == NORMAL_COMPLETION
        return MOI.LOCALLY_SOLVED
    elseif status == USER_INTERRUPTION
        return MOI.INTERRUPTED
    else
        error("Unrecognized Baron status $status")
    end
end

function MOI.get(model::Optimizer, ::MOI.ResultCount)
    return (model.inner.solution_info === nothing) ? 0 : 1
end

function MOI.get(model::Optimizer, ::MOI.PrimalStatus)
    if model.inner === nothing || model.inner.solution_info === nothing || model.inner.solution_info.value === nothing
        return MOI.NO_SOLUTION
    else
        return MOI.FEASIBLE_POINT
    end
end

MOI.get(model::Optimizer, ::MOI.ObjectiveValue) = model.inner.solution_info.objective_value

function MOI.get(model::Optimizer, ::MOI.VariablePrimal, vi::MOI.VariableIndex)
    if model.inner === nothing || model.inner.solution_info === nothing || model.inner.solution_info.feasible_point === nothing
        error("VariablePrimal not available.")
    end
    _check_inbounds(model, vi)
    return model.inner.solution_info.feasible_point[vi.value]
end

# TODO: MOI getters for objbound, solvetime
