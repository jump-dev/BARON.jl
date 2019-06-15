MOI.get(model::Optimizer, ::MOI.NumberOfVariables) = length(model.inner.variable_info)
MOI.get(model::Optimizer, ::MOI.ListOfVariableIndices) = VI.(1 : length(model.inner.variable_info))

function MOIU.allocate_variables(model::Optimizer, nvars::Integer)
    variable_info = model.inner.variable_info
    resize!(variable_info, nvars)
    @inbounds for i = 1 : nvars
        variable_info[i] = VariableInfo()
    end
    return VI.(1 : nvars)
end

MOIU.load_variables(model::Optimizer, nvars::Integer) = nothing

MOI.supports(model::Optimizer, ::MOI.VariableName, ::Type{VI}) = true

function MOIU.load(model::Optimizer, attr::MOI.VariableName, vi::VI, value)
    check_variable_indices(model, vi)
    model.inner.variable_info[vi.value].name = value
end

MOI.supports(::Optimizer, ::MOI.VariablePrimalStart, ::Type{VI}) = true

function MOIU.load(model::Optimizer, ::MOI.VariablePrimalStart, vi::VI, value::Union{Real, Nothing})
    check_variable_indices(model, vi)
    model.inner.variable_info[vi.value].start = value
    return
end
