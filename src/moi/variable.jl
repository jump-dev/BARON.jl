MOI.get(model::Optimizer, ::MOI.ListOfVariableIndices) = length(model.inner.variable_info)

function MOI.add_variable(model::Optimizer)
    push!(model.inner.variable_info, VariableInfo())
    return VI(length(model.inner.variable_info))
end

function MOI.add_variables(model::Optimizer, n::Int)
    return [MOI.add_variable(model) for i in 1:n]
end

function _check_inbounds(model::Optimizer, index::VI)
    @assert 1 <= index.value <= length(model.inner.variable_info)
end

MOI.supports(model::Optimizer, ::MOI.VariableName, ::Type{VI}) = true

function MOI.set(model::Optimizer, ::MOI.VariableName, vi::VI, value::AbstractString)
    _check_inbounds(model, vi)
    set_unique_variable_name!(model.inner, vi.value, value)
end

MOI.supports(::Optimizer, ::MOI.VariablePrimalStart, ::Type{VI}) = true

function MOI.set(model::Optimizer, ::MOI.VariablePrimalStart, vi::VI, value::Union{Real, Nothing})
    _check_inbounds(model, vi)
    model.inner.variable_info[vi.value].start = value
    return
end
