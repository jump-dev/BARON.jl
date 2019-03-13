import MathOptInterface
const MOI = MathOptInterface

mutable struct Optimizer <: MOI.AbstractOptimizer
    inner::Union{Nothing, BaronModel}
    nlp_block::Union{Nothing, MOI.NLPBlock}
    options
end

Optimizer(;options...) = Optimizer(nothing, nothing, options)

MOI.supports(::Optimizer, ::MOI.NLPBlock) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.LessThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.GreaterThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.ZeroOne}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.Integer}) = true

MOI.get(model::Optimizer, ::MOI.ListOfVariableIndices) = length(model.inner.variable_info)

function MOI.set(model::Optimizer, ::MOI.ObjectiveSense, sense::MOI.OptimizationSense)
    if sense == MOI.MINIMIZE
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

function add_variables(model::Optimizer, n::Int)
    return [MOI.add_variable(model) for i in 1:n]
end

MOI.supports(::Optimizer, ::MOI.VariablePrimalStart, ::Type{MOI.VariableIndex}) = true

function _check_inbounds(model::Optimizer, index::Int)
    @assert 1 <= length(model.inner.variabl_info)
end

function MOI.set(model::Optimizer, ::MOI.VariablePrimalStart, vi::MOI.VariableIndex, value::Union{Real, Nothing})
    _check_inbounds(model, vi)
    model.inner.variable_info[vi].start = value
    return
end

function MOI.add_constraint(model::Optimizer, variable::MOI.SingleVariable, lt::MOI.GreaterThan{Float64})
    vi = index(v.variable)
    _check_inbounds(model, vi)
    model.inner.variable_info[vi].lower__bound = lt.lower
    return
end

function MOI.add_constraint(model::Optimizer, variable::MOI.SingleVariable, lt::MOI.LessThan{Float64})
    vi = index(v.variable)
    _check_inbounds(model, vi)
    model.inner.variable_info[vi].upper_bound = lt.upper
    return
end

function MOI.add_constraint(model::Optimizer, v::MOI.SingleVariable, set::MOI.ZeroOne)
    vi = index(v.variable)
    _check_inbounds(model, vi)
    model.inner.variable_info[vi].category = :Binary
    return
end

function MOI.add_constraint(model::Optimizer, v::MOI.SingleVariable, set::MOI.Integer)
    vi = index(v.variable)
    _check_inbounds(model, vi)
    model.inner.variable_info[vi].category = :Int
    return
end

function MOI.set(model::Optimizer, ::MOI.NLPBlock, nlp_block::MOI.NLPBlock)
    model.nlp_block = block
    return
end

function MOI.optimize!(model::Optimizer)
    write_bar_file(model.inner)
    run(`$baron_exec $(model.inner.probfile)`)
    read_results(model.inner)
end

function MOI.get(model::Optimizer, ::MOI.TerminationStatus)
    if model.inner === nothing
        return MOI.OPTIMIZE_NOT_CALLED
    end
    status = model.inner.status
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
    return model.inner.solution_info.feasible_point[vi]
end

# TODO: MOI getters for objbound, solvetime
