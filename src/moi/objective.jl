MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true

function MOI.set(model::Optimizer, ::MOI.ObjectiveSense, sense::MOI.OptimizationSense)
    if model.inner.objective_info === nothing
        model.inner.objective_info = ObjectiveInfo()
    end
    if sense == MOI.MIN_SENSE
        model.inner.objective_info.sense = :Min
    else
        model.inner.objective_info.sense = :Max
    end
    return
end

