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
            return MOI.LOCALLY_SOLVED
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

function MOI.get(model::Optimizer, ::MOI.DualStatus)
    MOI.NO_SOLUTION
end

function MOI.get(model::Optimizer, attr::MOI.PrimalStatus)
    if attr.result_index != 1
        return MOI.NO_SOLUTION
    end
    solution_info = model.inner.solution_info
    if solution_info === nothing || solution_info.feasible_point === nothing
        return MOI.NO_SOLUTION
    else
        return solution_info.model_status == UNBOUNDED ? MOI.INFEASIBILITY_CERTIFICATE : MOI.FEASIBLE_POINT
    end
end

function MOI.get(model::Optimizer, attr::MOI.ObjectiveValue)
    MOI.check_result_index_bounds(model, attr)
    # if model.inner.solution_info.model_status == UNBOUNDED
    #     # BARON will set the same large number
    #     # for both abj and variables in case of unbounded
    #     # this would make it retur MOI consistent values
    #     # but getters are no define and NL one would be messy
    #     return MOIU.get_fallback(model, attr)
    # else
        model.inner.solution_info.objective_value
    # end
end

function MOI.get(model::Optimizer, attr::MOI.VariablePrimal, vi::VI)
    MOI.check_result_index_bounds(model, attr)
    # MOI.throw_if_not_valid(model, vi) # TODO implement is_valid
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

function MOI.get(model::Optimizer, ::MOI.SolveTimeSec)
    solution_info = model.inner.solution_info
    return solution_info.wall_time
end

function MOI.get(model::Optimizer, ::MOI.RawStatusString)
    info = model.inner.solution_info
    return "solver: $(info.solver_status), model: $(info.model_status)"
end

# TODO: desirable?
function MOI.get(model::MOIU.CachingOptimizer{BARON.Optimizer}, attr::MOI.ConstraintPrimal, ci::MOI.ConstraintIndex)
    return MOIU.get_fallback(model, attr, ci)
end

function MOI.supports(::Optimizer, ::MOI.SolverVersion)
    false
end
