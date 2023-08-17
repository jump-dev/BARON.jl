# Copyright (c) 2015: Joey Huchette and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module MOITests

using BARON
using Test

import MathOptInterface as MOI

function test_runtests()
    model = MOI.instantiate(
        BARON.Optimizer;
        with_bridge_type = Float64,
        with_cache_type = Float64,
    )
    MOI.set(model, MOI.RawOptimizerAttribute("PrLevel"), 0)
    MOI.Test.runtests(
        model,
        MOI.Test.Config(
            atol = 1e-3,
            rtol = 1e-3,
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
        ],
    )
    return
end

@testset "MOI Unit" begin
    test_runtests()
end

end # module
