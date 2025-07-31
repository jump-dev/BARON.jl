# Copyright (c) 2015: Joey Huchette and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

MOI.supports(::Optimizer, ::MOI.NLPBlock) = true

function walk_and_strip_variable_index!(expr::Expr)
    for i in 1:length(expr.args)
        if expr.args[i] isa MOI.VariableIndex
            expr.args[i] = expr.args[i].value
        end
        walk_and_strip_variable_index!(expr.args[i])
    end
    return expr
end

walk_and_strip_variable_index!(not_expr) = not_expr

function MOI.set(model::Optimizer, attr::MOI.NLPBlock, data::MOI.NLPBlockData)
    if model.nlp_block_data !== nothing
        msg = "Nonlinear block already set; cannot overwrite. Create a new model instead."
        throw(MOI.SetAttributeNotAllowed(attr, msg))
    end
    model.nlp_block_data = data
    MOI.initialize(data.evaluator, [:ExprGraph])
    if data.has_objective
        obj = MOI.objective_expr(data.evaluator)
        model.inner.objective_expr = walk_and_strip_variable_index!(obj)
    end
    for (i, bound) in enumerate(data.constraint_bounds)
        expr = MOI.constraint_expr(data.evaluator, i)
        lb, f, ub = if expr.head == :call
            if expr.args[1] == :(==)
                bound.lower, expr.args[2], bound.upper
            elseif expr.args[1] == :(<=)
                nothing, expr.args[2], bound.upper
            else
                @assert expr.args[1] == :(>=)
                bound.lower, expr.args[2], nothing
            end
        else
            @assert expr.head == :comparison
            @assert expr.args[2] == expr.args[4]
            bound.lower, expr.args[3], bound.upper
        end
        c_expr = walk_and_strip_variable_index!(f)
        push!(model.inner.constraint_info, ConstraintInfo(c_expr, lb, ub))
    end
    return
end
