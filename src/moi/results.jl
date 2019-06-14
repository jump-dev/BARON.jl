function MOI.get(model::Optimizer, ::MOI.TerminationStatus)
    if model.inner.solution_info === nothing
        return MOI.OPTIMIZE_NOT_CALLED
    end
    status = model.inner.solution_info.status
    if status == NORMAL_COMPLETION
        return MOI.OPTIMAL # TODO: are we sure we're getting the global optimum in this case?
    elseif status == INFEASIBLE
        return MOI.INFEASIBLE
    elseif status == UNBOUNDED
        return MOI.DUAL_INFEASIBLE
    elseif status == NODE_LIMIT
        return MOI.NODE_LIMIT
    elseif status == BAR_ITERATION_LIMIT
        return ITERATION_LIMIT
    elseif status == CPU_TIME_LIMIT
        return MOI.TIME_LIMIT
    elseif status == NUMERICAL_SENSITIVITY
        return MOI.NUMERICAL_ERROR
    elseif status == INVALID_VARIABLE_BOUNDS
        return MOI.INVALID_MODEL        
    elseif status == USER_INTERRUPTION
        return MOI.INTERRUPTED
    elseif status == ACCESS_VIOLATION
        return MOI.OTHER_ERROR
    else
        error("Unrecognized Baron status $status")
    end
end

function MOI.get(model::Optimizer, ::MOI.ResultCount)
    return (model.inner.solution_info.feasible_point === nothing) ? 0 : 1
end

function MOI.get(model::Optimizer, ::MOI.PrimalStatus)
    if model.inner.solution_info === nothing || model.inner.solution_info.feasible_point === nothing
        return MOI.NO_SOLUTION
    else
        return MOI.FEASIBLE_POINT
    end
end

MOI.get(model::Optimizer, ::MOI.ObjectiveValue) = model.inner.solution_info.objective_value

function MOI.get(model::Optimizer, ::MOI.VariablePrimal, vi::VI)
    if model.inner.solution_info === nothing || model.inner.solution_info.feasible_point === nothing
        error("VariablePrimal not available.")
    end
    _check_inbounds(model, vi)
    return model.inner.solution_info.feasible_point[vi.value]
end

# TODO: MOI getters for objbound, solvetime
