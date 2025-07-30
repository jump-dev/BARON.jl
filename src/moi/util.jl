# Copyright (c) 2015: Joey Huchette and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

to_expr(x::Real) = x

to_expr(vi::MOI.VariableIndex) = :(x[$(vi.value)])

function to_expr(f::MOI.ScalarAffineFunction)
    f = MOI.Utilities.canonical(f)
    if isempty(f.terms)
        return f.constant
    end
    expr = Expr(:call, :+)
    if !iszero(f.constant)
        push!(expr.args, f.constant)
    end
    for term in f.terms
        if isone(term.coefficient)
            push!(expr.args, :(x[$(term.variable.value)]))
        else
            push!(expr.args, :($(term.coefficient) * x[$(term.variable.value)]))
        end
    end
    if length(expr.args) == 2
        return expr.args[end]
    end
    return expr
end

function to_expr(f::MOI.ScalarQuadraticFunction)
    f = MOI.Utilities.canonical(f)
    expr = Expr(:call, :+)
    if !iszero(f.constant)
        push!(expr.args, f.constant)
    end
    for term in f.affine_terms
        if isone(term.coefficient)
            push!(expr.args, :(x[$(term.variable.value)]))
        else
            push!(expr.args, :($(term.coefficient) * x[$(term.variable.value)]))
        end
    end
    for term in f.quadratic_terms
        i, j = term.variable_1.value, term.variable_2.value
        coef = (i == j ? 0.5 : 1.0) * term.coefficient
        if isone(coef)
            push!(expr.args, :(x[$i] * x[$j]))
        else
            push!(expr.args, :($coef * x[$i] * x[$j]))
        end
    end
    if length(expr.args) == 1
        return f.constant
    elseif length(expr.args) == 2
        return expr.args[end]
    end
    return expr
end

function to_expr(f::MOI.ScalarNonlinearFunction)
    if !(f.head in _LIST_OF_SUPPORTED_NONLINEAR_OPERATORS)
        throw(MOI.UnsupportedNonlinearOperator(f.head))
    end
    expr = Expr(:call, f.head)
    for arg in f.args
        push!(expr.args, to_expr(arg))
    end
    return expr
end

function find_variable_info(model::Optimizer, vi::MOI.VariableIndex)
    MOI.throw_if_not_valid(model, vi)
    return model.inner.variable_info[vi.value]
end
