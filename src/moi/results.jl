function MOI.get(model::Optimizer, ::MOI.TerminationStatus)
    solution_info = model.inner.solution_info
    if solution_info === nothing
        return MOI.OPTIMIZE_NOT_CALLED
    end
    solver_status = solution_info.solver_status
    model_status = solution_info.model_status

    if solver_status == NORMAL_COMPLETION
        if model_status == OPTIMAL
            return MOI.OPTIMAL
        elseif model_status == INFEASIBLE
            return MOI.INFEASIBLE
        elseif model_status == UNBOUNDED
            return MOI.DUAL_INFEASIBLE
        elseif model_status == INTERMEDIATE_FEASIBLE
            return LOCALLY_SOLVED
        elseif model_status == UNKNOWN
            return MOI.OTHER_ERROR
        end
    elseif solver_status == INSUFFICIENT_MEMORY_FOR_NODES
        return MOI.MEMORY_LIMIT
    elseif solver_status == ITERATION_LIMIT
        return MOI.ITERATION_LIMIT
    elseif solver_status == TIME_LIMIT
        return MOI.TIME_LIMIT
    elseif solver_status == NUMERICAL_SENSITIVITY
        return MOI.NUMERICAL_ERROR
    elseif solver_status == INSUFFICIENT_MEMORY_FOR_SETUP
        return MOI.MEMORY_LIMIT
    elseif solver_status == RESERVED
        return MOI.OTHER_ERROR
    elseif solver_status == TERMINATED_BY_BARON
        return MOI.OTHER_ERROR
    elseif solver_status == SYNTAX_ERROR
        return MOI.INVALID_MODEL
    elseif solver_status == LICENSING_ERROR
        return MOI.OTHER_ERROR
    elseif solver_status == USER_HEURISTIC_TERMINATION
        return MOI.OTHER_LIMIT
    end

    error("Unrecognized Baron status: $solver_status, $model_status")
end

function MOI.get(model::Optimizer, ::MOI.ResultCount)
    return (model.inner.solution_info.feasible_point === nothing) ? 0 : 1
end

function MOI.get(model::Optimizer, ::MOI.PrimalStatus)
    solution_info = model.inner.solution_info
    if solution_info === nothing || solution_info.feasible_point === nothing
        return MOI.NO_SOLUTION
    else
        return solution_info.model_status == UNBOUNDED ? MOI.INFEASIBILITY_CERTIFICATE : MOI.FEASIBLE_POINT
    end
end

MOI.get(model::Optimizer, ::MOI.ObjectiveValue) = model.inner.solution_info.objective_value

function MOI.get(model::Optimizer, ::MOI.VariablePrimal, vi::VI)
    solution_info = model.inner.solution_info
    if solution_info === nothing || solution_info.feasible_point === nothing
        error("VariablePrimal not available.")
    end
    check_variable_indices(model, vi)
    return solution_info.feasible_point[vi.value]
end

function MOI.get(model::Optimizer, ::MOI.ObjectiveBound)
    solution_info = model.inner.solution_info
    return solution_info.dual_bound
end

function MOI.get(model::Optimizer, ::MOI.SolveTime)
    solution_info = model.inner.solution_info
    return solution_info.wall_time
end


# TODO: desirable?
function MOI.get(model::MOIU.CachingOptimizer{BARON.Optimizer}, attr::MOI.ConstraintPrimal, ci::MOI.ConstraintIndex)
    return MOIU.get_fallback(model, attr, ci)
end

# TODO: MOI getter for solvetime
