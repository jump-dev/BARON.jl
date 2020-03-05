MOI.supports(::Optimizer, ::MOI.NLPBlock) = true

function MOI.set(model::Optimizer, ::MOI.NLPBlock, nlp_data::MOI.NLPBlockData)
    @assert model.nlp_data === nothing
    model.nlp_block_data = nlp_data

    nlp_eval = nlp_data.evaluator

    MOI.initialize(nlp_eval, [:ExprGraph])

    if nlp_data.has_objective
        @assert model.inner.objective_expr === nothing
        model.inner.objective_expr = verify_support(MOI.obj_expr(npl_eval))
    end

    for i in 1:length(nlp_data.constraint_bounds)
        push!(model.inner.constraints, ConstraintInfo(
            verify_support(MOI.constr_expr(nlp_eval, i)),
            nlp_data.constraint_bounds[i].lower,
            nlp_data.constraint_bounds[i].upper,
            "nlp_constraint_$i"
        ))
    end
    return
end
