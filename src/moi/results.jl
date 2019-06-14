function MOI.get(model::Optimizer, ::MOI.TerminationStatus)
    if model.inner === nothing || model.inner.solution_info === nothing
        return MOI.OPTIMIZE_NOT_CALLED
    end
    status = model.inner.solution_info.status
    if status == NORMAL_COMPLETION
        return MOI.LOCALLY_SOLVED
    elseif status == USER_INTERRUPTION
        return MOI.INTERRUPTED
    else
        error("Unrecognized Baron status $status")
    end
end

function MOI.get(model::Optimizer, ::MOI.ResultCount)
    return (model.inner.solution_info === nothing) ? 0 : 1
end

function MOI.get(model::Optimizer, ::MOI.PrimalStatus)
    if model.inner === nothing || model.inner.solution_info === nothing || model.inner.solution_info.value === nothing
        return MOI.NO_SOLUTION
    else
        return MOI.FEASIBLE_POINT
    end
end

MOI.get(model::Optimizer, ::MOI.ObjectiveValue) = model.inner.solution_info.objective_value

function MOI.get(model::Optimizer, ::MOI.VariablePrimal, vi::MOI.VariableIndex)
    if model.inner === nothing || model.inner.solution_info === nothing || model.inner.solution_info.feasible_point === nothing
        error("VariablePrimal not available.")
    end
    _check_inbounds(model, vi)
    return model.inner.solution_info.feasible_point[vi.value]
end

# TODO: MOI getters for objbound, solvetime
