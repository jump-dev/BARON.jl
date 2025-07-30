# Copyright (c) 2015: Joey Huchette and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

const _SOLVER_STATUS_MAP = Dict(
    # NORMAL_COMPLETION = 1  # Handled separately
    INSUFFICIENT_MEMORY_FOR_NODES => MOI.MEMORY_LIMIT,
    ITERATION_LIMIT => MOI.ITERATION_LIMIT,
    TIME_LIMIT => MOI.TIME_LIMIT,
    NUMERICAL_SENSITIVITY => MOI.NUMERICAL_ERROR,
    USER_INTERRUPTION => MOI.INTERRUPTED,
    INSUFFICIENT_MEMORY_FOR_SETUP => MOI.MEMORY_LIMIT,
    RESERVED => MOI.OTHER_ERROR,
    TERMINATED_BY_BARON => MOI.OTHER_ERROR,
    SYNTAX_ERROR => MOI.INVALID_MODEL,
    LICENSING_ERROR => MOI.OTHER_ERROR,
    USER_HEURISTIC_TERMINATION => MOI.OTHER_LIMIT,
)

const _MODEL_STATUS_MAP = Dict(
    OPTIMAL => MOI.OPTIMAL,
    INFEASIBLE => MOI.INFEASIBLE,
    UNBOUNDED => MOI.DUAL_INFEASIBLE,
    INTERMEDIATE_FEASIBLE => MOI.LOCALLY_SOLVED,
    UNKNOWN => MOI.OTHER_ERROR,
)

function MOI.get(model::Optimizer, ::MOI.TerminationStatus)
    solution_info = model.inner.solution_info
    if solution_info === nothing
        return MOI.OPTIMIZE_NOT_CALLED
    end
    if solution_info.solver_status == NORMAL_COMPLETION
        return _MODEL_STATUS_MAP[solution_info.model_status]
    end
    return _SOLVER_STATUS_MAP[solution_info.solver_status]
end

function MOI.get(model::Optimizer, ::MOI.ResultCount)
    return (model.inner.solution_info.feasible_point === nothing) ? 0 : 1
end

MOI.get(model::Optimizer, ::MOI.DualStatus) = MOI.NO_SOLUTION

function MOI.get(model::Optimizer, attr::MOI.PrimalStatus)
    if attr.result_index != 1
        return MOI.NO_SOLUTION
    end
    solution_info = model.inner.solution_info
    if solution_info === nothing || solution_info.feasible_point === nothing
        return MOI.NO_SOLUTION
    end
    return MOI.FEASIBLE_POINT
end

function MOI.get(model::Optimizer, attr::MOI.ObjectiveValue)
    MOI.check_result_index_bounds(model, attr)
    return model.inner.solution_info.objective_value
end

function MOI.get(
    model::Optimizer,
    attr::MOI.VariablePrimal,
    vi::MOI.VariableIndex,
)
    MOI.check_result_index_bounds(model, attr)
    MOI.throw_if_not_valid(model, vi)
    return model.inner.solution_info.feasible_point[vi.value]
end

function MOI.get(model::Optimizer, ::MOI.ObjectiveBound)
    return model.inner.solution_info.dual_bound
end

function MOI.get(model::Optimizer, ::MOI.SolveTimeSec)
    return model.inner.solution_info.wall_time
end

function MOI.get(model::Optimizer, ::MOI.RawStatusString)
    info = model.inner.solution_info
    return "solver: $(info.solver_status), model: $(info.model_status)"
end

function MOI.get(
    model::MOI.Utilities.CachingOptimizer{BARON.Optimizer},
    attr::MOI.ConstraintPrimal,
    ci::MOI.ConstraintIndex,
)
    return MOI.Utilities.get_fallback(model, attr, ci)
end
