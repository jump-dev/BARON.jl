MOI.get(model::Optimizer, ::MOI.NumberOfVariables) = length(model.inner.variable_info)
MOI.get(model::Optimizer, ::MOI.ListOfVariableIndices) = VI.(1 : length(model.inner.variable_info))

function MOI.add_variable(model::Optimizer)
    push!(model.inner.variable_info, VariableInfo())
    return VI(length(model.inner.variable_info))
end

function MOI.add_variables(model::Optimizer, nvars::Integer)
    return [MOI.add_variable(model) for i in 1:nvars]
end

function MOI.add_constraint(model::Optimizer, v::SV, lt::MOI.LessThan{Float64})
    vi = v.variable
    check_variable_indices(model, vi)
    set_upper_bound(model.inner.variable_info[vi.value], lt.upper)
    return MOI.ConstraintIndex{SV,MOI.LessThan{Float64}}(vi.value)
end

function MOI.add_constraint(model::Optimizer, v::SV, gt::MOI.GreaterThan{Float64})
    vi = v.variable
    check_variable_indices(model, vi)
    set_lower_bound(model.inner.variable_info[vi.value], gt.lower)
    return MOI.ConstraintIndex{SV, MOI.GreaterThan{Float64}}(vi.value)
end

function MOI.add_constraint(model::Optimizer, v::SV, eq::MOI.EqualTo{Float64})
    vi = v.variable
    check_variable_indices(model, vi)
    set_lower_bound(model.inner.variable_info[vi.value], eq.value)
    set_upper_bound(model.inner.variable_info[vi.value], eq.value)
    return MOI.ConstraintIndex{SV,MOI.EqualTo{Float64}}(vi.value)
end

MOI.supports(::Optimizer, ::MOI.VariableName, ::Type{VI}) = true

function MOI.set(model::Optimizer, attr::MOI.VariableName, vi::VI, value)
    check_variable_indices(model, vi)
    model.inner.variable_info[vi.value].name = value
end
function MOI.get(model::Optimizer, ::MOI.VariableName, vi::VI)
     return model.inner.variable_info[vi.value].name
end

function MOI.get(model::Optimizer, ::Type{MathOptInterface.VariableIndex}, name::String)
    for (i,var) in enumerate(model.inner.variable_info)
        if name == var.name
            return VI(i)
        end
    end
    error("Unrecognized variable name $name.")
end

MOI.supports(::Optimizer, ::MOI.VariablePrimalStart, ::Type{VI}) = true

function MOI.set(model::Optimizer, ::MOI.VariablePrimalStart, vi::VI, value::Union{Real, Nothing})
    check_variable_indices(model, vi)
    model.inner.variable_info[vi.value].start = value
    return
end
