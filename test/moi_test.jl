module MOITests

using BARON
using Test

using MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities
const MOIB = MOI.Bridges

const optimizer = BARON.Optimizer(PrLevel=0)
const caching_optimizer = MOIU.CachingOptimizer(
    MOIU.UniversalFallback(MOIU.Model{Float64}()), BARON.Optimizer(PrLevel=0));

function test_runtests()
    model = caching_optimizer#MOI.instantiate(BARON.Optimizer, with_bridge_type = Float64)
    MOI.set(model, MOI.RawOptimizerAttribute("PrLevel"), 0)
    # MOI.set(model, MOI.Silent(), true) # todo
    MOI.Test.runtests(model,
        MOI.Test.Config(
            atol = 1e-3,
            rtol = 1e-3,
            # optimal_status = MOI.LOCALLY_SOLVED,
            exclude = Any[
                MOI.ConstraintBasisStatus,
                MOI.DualObjectiveValue,
                MOI.ObjectiveBound,
                MOI.DualStatus,
                MOI.ConstraintDual,
            ],
        );
        exclude = [
            "test_attribute_SolverVersion",      # unavailable
            "test_nonlinear_hs071_NLPBlockDual", # MathOptInterface.NLPBlockDual(1)
            "test_nonlinear_invalid",            # see below
            "test_linear_open_intervals",
            "test_linear_variable_open_intervals",
            # returns NaN in expression and solver has to responde with:
            # MOI.get(model, MOI.TerminationStatus()) == MOI.INVALID_MODEL
            # this code will error when NaN is found (better than waiting to knoe about bad stuff)
            "test_variable_solve_ZeroOne_with_upper_bound",# fail is upstream
            "test_objective_ObjectiveFunction_blank", # fail is upstream
            "test_objective_FEASIBILITY_SENSE_clears_objective", # fail is upstream
            "test_linear_integer_solve_twice", # simply fails in the first solve
            # objective fails
            # BARON will set the same large number
            # for both abj and variables in case of unbounded
            "test_unbounded_MIN_SENSE_offset",
            "test_unbounded_MIN_SENSE",
            "test_unbounded_MAX_SENSE_offset",
            "test_unbounded_MAX_SENSE",
        ]
    )
    return
end

@testset "MOI Unit" begin
    test_runtests()
end

end # module
