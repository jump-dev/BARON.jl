MOI.supports_constraint(::Optimizer, ::Type{SV}, ::Type{<:Bounds}) = true

function MOI.add_constraint(model::Optimizer, f::SV, set::Bounds)
    vi = f.variable
    _check_inbounds(model, vi)
    varinfo = model.inner.variable_info[vi.value]
    @assert (varinfo.lower_bound == -Inf && varinfo.upper_bound == Inf) "Variable already has bounds."
    interval = MOI.Interval(set)
    l, u = interval.lower, interval.upper
    l === -Inf || (varinfo.lower_bound = l)
    u === Inf || (varinfo.upper_bound = u)
    return CI{typeof(f), typeof(set)}(-vi.value) # use negative constraint indices for variable bounds
end

MOI.supports_constraint(::Optimizer, ::Type{SAF}, ::Type{<:Bounds}) = true

function MOI.add_constraint(model::Optimizer, f::SAF, set::Bounds)
    _check_inbounds(model, f)
    push!(model.inner.constraint_info, ConstraintInfo(f, set))
    ci = CI{typeof(f), typeof(set)}(length(model.inner.constraint_info))
    @show ci
    return ci
end
