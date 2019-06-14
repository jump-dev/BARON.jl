set_bounds(info::Union{VariableInfo, ConstraintInfo}, bounds::Bounds) = set_bounds(info, MOI.Interval(bounds))

function set_bounds(info::Union{VariableInfo, ConstraintInfo}, interval::MOI.Interval)
    l, u = interval.lower, interval.upper
    l === -Inf || (info.lower_bound = l)
    u === Inf || (info.upper_bound = u)
    return
end

MOI.supports_constraint(::Optimizer, ::Type{SV}, ::Type{<:Bounds}) = true

function MOIU.load_constraint(model::Optimizer, ci::CI, f::SV, set::Bounds)
    vi = f.variable
    _check_inbounds(model, vi)
    variable_info = model.inner.variable_info[vi.value]
    set_bounds(variable_info, set)
    return
end

MOI.supports_constraint(::Optimizer, ::Type{SAF}, ::Type{<:Bounds}) = true

function MOIU.load_constraint(model::Optimizer, ci::CI, f::SAF, set::Bounds)
    _check_inbounds(model, f)
    constraint_info = model.inner.constraint_info[ci.value]
    constraint_info.expression = to_expr(f)
    set_bounds(constraint_info, set)
    return
end
