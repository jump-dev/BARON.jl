MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true

function MOI.set(model::Optimizer, ::MOI.ObjectiveSense, sense::MOI.OptimizationSense)
    objective_info = model.inner.objective_info
    if sense == MOI.MIN_SENSE
        objective_info.sense = :Min
    elseif sense == MOI.MAX_SENSE
        objective_info.sense = :Max
    elseif sense == MOI.FEASIBILITY_SENSE
        objective_info.sense = :Feasibility
    else
        error("Unsupported objective sense: $sense")
    end
    return
end

MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{SAF}) = true

function MOI.set(model::Optimizer, ::MOI.ObjectiveFunction{SAF}, obj::SAF)
    model.inner.objective_info.expression = to_expr(obj)
    return
end
