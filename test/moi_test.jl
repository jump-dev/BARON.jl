# Copyright (c) 2015: Joey Huchette and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module MOITests

using BARON
using Test

import MathOptInterface as MOI

function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
    return
end

function test_runtests()
    model = MOI.instantiate(
        BARON.Optimizer;
        with_bridge_type = Float64,
        with_cache_type = Float64,
    )
    MOI.set(model, MOI.Silent(), true)
    MOI.Test.runtests(
        model,
        MOI.Test.Config(
            atol = 1e-3,
            rtol = 1e-3,
            exclude = Any[
                MOI.ConstraintBasisStatus,
                MOI.DualObjectiveValue,
                MOI.ObjectiveBound,
                MOI.ConstraintDual,
            ],
        );
        exclude = [
            # TODO(odow): These tests fail in CI but pass locally.
            r"^test_cpsat_AllDifferent$",
            r"^test_cpsat_BinPacking$",
            r"^test_cpsat_Circuit$",
            r"^test_cpsat_CountAtLeast$",
            r"^test_cpsat_CountBelongs$",
            r"^test_cpsat_CountDistinct$",
            r"^test_cpsat_CountGreaterThan$",
            r"^test_cpsat_ReifiedAllDifferent$",
            r"^test_linear_SOS2_integration$",
            r"^test_linear_integer_integration$",
            r"^test_linear_integer_solve_twice$",
            r"^test_solve_SOS2_add_and_delete$",
            # =================== Upstream bugs in BARON =======================
            #   This one is pretty funny. Adding a bound makes BARON ignore
            #   BINARY_VARIABLES
            r"^test_variable_solve_ZeroOne_with_upper_bound$",
            #   Wrong answer
            r"^test_linear_Indicator_ON_ONE$",
            # =================== Bugs in BARON.jl =============================
            #   A method error
            r"^test_linear_VectorAffineFunction_empty_row$",
            # =================== Tests that are okay to skip ==================
            r"^test_attribute_SolverVersion$",
            r"^test_nonlinear_hs071_NLPBlockDual$",
            r"^test_nonlinear_invalid$",
            r"^test_nonlinear_expression_hs110$",
        ],
    )
    return
end

function test_ListOfSupportedNonlinearOperators()
    attr = MOI.ListOfSupportedNonlinearOperators()
    @test MOI.get(BARON.Optimizer(), attr) ==
          BARON._LIST_OF_SUPPORTED_NONLINEAR_OPERATORS
    return
end

function test_is_valid()
    model = BARON.Optimizer()
    x = MOI.add_variables(model, 6)
    @test all(MOI.is_valid.(model, x))
    @test !MOI.is_valid(model, MOI.VariableIndex(-1))
    sets = (
        MOI.GreaterThan(0.0),
        MOI.LessThan(0.0),
        MOI.EqualTo(0.0),
        MOI.Integer(),
        MOI.ZeroOne(),
    )
    cis = Any[]
    for (i, set) in enumerate(sets)
        push!(cis, MOI.add_constraint(model, x[i], set))
    end
    for ci in cis
        @test MOI.is_valid(model, ci)
        @test !MOI.is_valid(model, typeof(ci)(-1))
        @test !MOI.is_valid(model, typeof(ci)(x[6].value))
    end
    c_eq = MOI.add_constraint(model, 1.0 * x[1] + x[2], MOI.EqualTo(0.0))
    @test MOI.is_valid(model, c_eq)
    @test !MOI.is_valid(model, typeof(c_eq)(-1))
    return
end

function test_bridge_indicator_to_milp()
    model = MOI.instantiate(
        BARON.Optimizer;
        with_bridge_type = Float64,
        with_cache_type = Float64,
    )
    MOI.set(model, MOI.Silent(), true)
    x = MOI.add_variables(model, 2)
    MOI.add_constraint.(model, x, MOI.GreaterThan(0.0))
    MOI.add_constraint.(model, x, MOI.LessThan(2.0))
    z = MOI.add_variable(model)
    MOI.add_constraint(model, z, MOI.ZeroOne())
    MOI.add_constraint(
        model,
        MOI.Utilities.operate(vcat, Float64, z, 1.0 * x[1] + 1.0 * x[2]),
        MOI.Indicator{MOI.ACTIVATE_ON_ONE}(MOI.LessThan(1.0)),
    )
    MOI.optimize!(model)
    @test MOI.get(model, MOI.TerminationStatus()) == MOI.OPTIMAL
    x_val = MOI.get.(model, MOI.VariablePrimal(), x)
    z_val = MOI.get(model, MOI.VariablePrimal(), z)
    @test z_val < 0.5 || (sum(x_val) <= 1.0 + 1e-5)
    return
end

function test_to_expr()
    x = MOI.VariableIndex(1)
    y = MOI.VariableIndex(2)
    a_terms = MOI.ScalarAffineTerm{Float64}[]
    q_terms = MOI.ScalarQuadraticTerm{Float64}[]
    for (input, output) in (
        # Real
        0.0 => 0.0,
        1.0 => 1.0,
        2 => 2,
        # VariableIndex
        x => :(x[1]),
        y => :(x[2]),
        # ScalarAffineFunction
        2.0 * x + 1.0 => :(1.0 + 2.0 * x[1]),
        2.0 * x + 0.0 => :(2.0 * x[1]),
        1.0 * x + 0.0 => :(x[1]),
        0.0 * x + y + 1.0 => :(1.0 + x[2]),
        MOI.ScalarAffineFunction(a_terms, 0.0) => 0.0,
        MOI.ScalarAffineFunction(a_terms, 1.0) => 1.0,
        # ScalarQuadraticFunction
        2.0 * x * x + 1.0 => :(1.0 + 2.0 * x[1] * x[1]),
        2.0 * x * y + 1.0 => :(1.0 + 2.0 * x[1] * x[2]),
        2.0 * x * y + 0.0 => :(2.0 * x[1] * x[2]),
        2.0 * x * y + x => :(x[1] + 2.0 * x[1] * x[2]),
        2.0 * x * y + 0.0 * x => :(2.0 * x[1] * x[2]),
        1.0 * x * y + x + 3.0 => :(3.0 + x[1] + x[1] * x[2]),
        0.0 * x * y + x + 3.0 => :(3.0 + x[1]),
        MOI.ScalarQuadraticFunction(q_terms, a_terms, 0.0) => 0.0,
        MOI.ScalarQuadraticFunction(q_terms, a_terms, 1.0) => 1.0,
        # ScalarNonlinearFunction
        MOI.ScalarNonlinearFunction(:log, Any[x]) => :(log(x[1])),
    )
        @test BARON.to_expr(input) == output
    end
    return
end

end # module

MOITests.runtests()
