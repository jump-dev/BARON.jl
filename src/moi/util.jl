function to_expr(f::SAF)
    linear_term_exprs = map(f.terms) do term
        :($(term.coefficient) * x[$(term.variable_index.value)])
    end
    expr = :(+($(linear_term_exprs...)))
    if !iszero(f.constant)
        push!(expr.args, f.constant)
    end
    return expr
end

function ConstraintInfo(f::SAF, set::Bounds)
    ConstraintInfo(f, MOI.Interval(set))
end

function ConstraintInfo(f::SAF, set::MOI.Interval)
    ConstraintInfo(to_expr(f), set.lower, set.upper)
end


function _check_inbounds(model::Optimizer, index::VI)
    @assert 1 <= index.value <= length(model.inner.variable_info)
end

function _check_inbounds(model::Optimizer, f::SAF)
    for term in f.terms
        _check_inbounds(model, term.variable_index)
    end
end