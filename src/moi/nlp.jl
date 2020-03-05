MOI.supports(::Optimizer, ::MOI.NLPBlock) = true

function walk_and_strip_variable_index!(expr::Expr)
    for i in 1:length(expr.args)
        if expr.args[i] isa MOI.VariableIndex
            expr.args[i] = expr.args[i].value
        end
        walk_and_strip_variable_index!(expr.args[i])
    end
    return
end

walk_and_strip_variable_index!(not_expr) = nothing

function MOI.set(model::Optimizer, ::MOI.NLPBlock, nlp_data::MOI.NLPBlockData)
    @assert model.nlp_block_data === nothing
    model.nlp_block_data = nlp_data

    nlp_eval = nlp_data.evaluator

    MOI.initialize(nlp_eval, [:ExprGraph])

    if nlp_data.has_objective
        @assert model.inner.objective_expr === nothing
        obj = MOI.objective_expr(nlp_eval)
        walk_and_strip_variable_index!(obj)
        model.inner.objective_expr = obj
    end

    for i in 1:length(nlp_data.constraint_bounds)
        expr = verify_support(MOI.constraint_expr(nlp_eval, i))
        lb = nlp_data.constraint_bounds[i].lower
        ub = nlp_data.constraint_bounds[i].upper
        @assert expr.head == :call
        if expr.args[1] == :(==)
            @assert lb == ub == expr.args[3]
        elseif expr.args[1] == :(<=)
            @assert lb == -Inf
            lb = nothing
            @assert ub == expr.args[3]
        elseif expr.args[1] == :(>=)
            @assert lb == expr.args[3]
            @assert ub == Inf
            ub = nothing
        else
            error("Unexpected expression $expr.")
        end
        expr = expr.args[2]
        walk_and_strip_variable_index!(expr)
        push!(model.inner.constraint_info, ConstraintInfo(expr, lb, ub, "c_$i"))
    end
    return
end
