MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true

function MOIU.load(model::Optimizer, ::MOI.ObjectiveSense, sense::MOI.OptimizationSense)
    if sense == MOI.MIN_SENSE
        model.inner.objective_sense = :Min
    elseif sense == MOI.MAX_SENSE
        model.inner.objective_sense = :Max
    elseif sense == MOI.FEASIBILITY_SENSE
        model.inner.objective_sense = :Feasibility
    else
        error("Unsupported objective sense: $sense")
    end
    return
end

MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{SAF}) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{SQF}) = true

function MOIU.load(model::Optimizer, ::MOI.ObjectiveFunction{F}, obj::F) where {F<:Union{SAF, SQF}}
    @assert model.inner.objective_expr === nothing
    model.inner.objective_expr = to_expr(obj)
    return
end
