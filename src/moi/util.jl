# to_expr
to_expr(vi::MOI.VariableIndex) = :(x[$(vi.value)])

function to_expr(f::SAF)
    f = MOIU.canonical(f)
    if isempty(f.terms)
        return f.constant
    else
        linear_term_exprs = map(f.terms) do term
            :($(term.coefficient) * x[$(term.variable.value)])
        end
        expr = :(+($(linear_term_exprs...)))
        if !iszero(f.constant)
            push!(expr.args, f.constant)
        end
        return expr
    end
end

function to_expr(f::SQF)
    f = MOIU.canonical(f)
    linear_term_exprs = map(f.affine_terms) do term
        i = term.variable.value
        :($(term.coefficient) * x[$i])
    end
    quadratic_term_exprs = map(f.quadratic_terms) do term
        i = term.variable_1.value
        j = term.variable_2.value
        if i == j
            :($(term.coefficient / 2) * x[$i] * x[$j])
        else
            :($(term.coefficient) * x[$i] * x[$j])
        end
    end
    expr = :(+($(linear_term_exprs...), $(quadratic_term_exprs...)))
    if !iszero(f.constant)
        push!(expr.args, f.constant)
    end
    return expr
end

# check_variable_indices
function check_variable_indices(model::Optimizer, index::VI)
    @assert 1 <= index.value <= length(model.inner.variable_info)
end

function check_variable_indices(model::Optimizer, f::SAF)
    for term in f.terms
        check_variable_indices(model, term.variable)
    end
end

function check_variable_indices(model::Optimizer, f::SQF)
    for term in f.affine_terms
        check_variable_indices(model, term.variable)
    end
    for term in f.quadratic_terms
        check_variable_indices(model, term.variable_1)
        check_variable_indices(model, term.variable_2)
    end
end

function find_variable_info(model::Optimizer, vi::VI)
    check_variable_indices(model, vi)
    model.inner.variable_info[vi.value]
end

function check_constraint_indices(model::Optimizer, index::CI{MOI.VariableIndex})
    @assert 1 <= index.value <= length(model.inner.variable_info)
end

function check_constraint_indices(model::Optimizer, index::CI)
    @assert 1 <= index.value <= length(model.inner.constraint_info)
end
