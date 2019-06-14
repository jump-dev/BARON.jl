MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.LessThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.GreaterThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.ZeroOne}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.Integer}) = true

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

