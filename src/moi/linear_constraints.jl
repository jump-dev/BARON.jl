MOI.supports_constraint(::Optimizer, ::Type{SV}, ::Type{MOI.LessThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{SV}, ::Type{MOI.GreaterThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{SV}, ::Type{MOI.ZeroOne}) = true
MOI.supports_constraint(::Optimizer, ::Type{SV}, ::Type{MOI.Integer}) = true

function MOI.add_constraint(model::Optimizer, fun::SV, set::MOI.GreaterThan{Float64})
    vi = fun.variable
    _check_inbounds(model, vi)
    model.inner.variable_info[vi.value].lower_bound = set.lower
    return
end

function MOI.add_constraint(model::Optimizer, fun::SV, set::MOI.LessThan{Float64})
    vi = fun.variable
    _check_inbounds(model, vi)
    model.inner.variable_info[vi.value].upper_bound = set.upper
    return
end

