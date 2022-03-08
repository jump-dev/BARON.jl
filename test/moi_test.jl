module MOITests

using BARON
using Test

using MathOptInterface
const MOI = MathOptInterface
const MOIT = MOI.DeprecatedTest
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
@testset "New" begin
    test_runtests()
end
@testset "Old" begin
@testset "Unit" begin
    config = MOIT.Config(atol=1e-5, rtol=1e-4, infeas_certificates=true, duals=false)
    # A number of test cases are excluded because loadfromstring! works only
    # if the solver supports variable and constraint names.
    exclude = ["delete_variable", # Deleting not supported.
               "delete_variables", # Deleting not supported.
               "solve_zero_one_with_bounds_1", # loadfromstring!
               "solve_zero_one_with_bounds_2", # loadfromstring!
               "solve_zero_one_with_bounds_3", # loadfromstring!
               "getconstraint", # Constraint names not suported.
               "solve_with_upperbound", # loadfromstring!
               "solve_with_lowerbound", # loadfromstring!
               "solve_integer_edge_cases", # loadfromstring!
               "solve_affine_lessthan", # loadfromstring!
               "solve_affine_greaterthan", # loadfromstring!
               "solve_affine_equalto", # loadfromstring!
               "solve_affine_interval", # loadfromstring!
               "solve_duplicate_terms_vector_affine", # Vector variables
               "solve_blank_obj", # loadfromstring!
               "solve_affine_deletion_edge_cases", # Deleting not supported.
               "number_threads", # NumberOfThreads not supported
               "delete_nonnegative_variables", # get ConstraintFunction n/a.
               "update_dimension_nonnegative_variables", # get ConstraintFunction n/a.
               "delete_soc_variables", # VectorOfVar. in SOC not supported
               "solve_result_index", # DualObjectiveValue not supported
               "time_limit_sec", # Supported by Optimizer, but not by MOIU.Model
               "silent",
               "raw_status_string",
               "solve_qp_edge_cases",
               "solve_objbound_edge_cases",
               #
               "solve_farkas_interval_lower",
               "solve_farkas_lessthan",
               "solve_farkas_greaterthan",
               "solve_farkas_variable_lessthan_max",
               "solve_farkas_variable_lessthan",
               "solve_farkas_equalto_upper",
               "solve_farkas_interval_upper",
               "solve_farkas_equalto_lower",
               ]
    MOIT.unittest(caching_optimizer, config, exclude)
end

MOI.empty!(optimizer)

@testset "MOI Continuous Linear" begin
    config = MOIT.Config(atol=1e-5, rtol=1e-4, infeas_certificates=false, duals=false)
    excluded = String[
        "linear7", # vector constraints
        "linear8b", # certificate provided in this case (result count is 1)
        "linear8c", # should be unbounded below, returns "Preprocessing found feasible solution with value -.200000000000E+052"
        "linear15", # vector constraints
        "partial_start" # TODO
    ]
    # MOIT.partial_start_test(optimizer, config)
    MOIT.contlineartest(caching_optimizer, config, excluded)
    MOIT.linear8btest(caching_optimizer, MOIT.Config(atol=1e-5, rtol=1e-4, infeas_certificates=true, duals=false))
end

MOI.empty!(optimizer)

@testset "MOI Integer Linear" begin
    config = MOIT.Config(atol=1e-5, rtol=1e-4, infeas_certificates=false, duals=false)
    excluded = String[
        "int2", # SOS1
        "int3", # SOS1
        "indicator1", # ACTIVATE_ON_ONE
        "indicator2", # ACTIVATE_ON_ONE
        "indicator3", # ACTIVATE_ON_ONE
        "indicator4", # ACTIVATE_ON_ONE
        "semiconttest",
        "semiinttest",
    ]
    MOIT.intlineartest(caching_optimizer, config, excluded)
end

MOI.empty!(optimizer)

@testset "MOI Continuous Quadratic" begin
    # TODO: rather high tolerances
    config = MOIT.Config(atol=1e-3, rtol=1e-3, infeas_certificates=false, duals=false)
    excluded = String[
        "qcp1", # vector constraints
    ]
    MOIT.contquadratictest(caching_optimizer, config, excluded)
end

MOI.empty!(optimizer)
bridged = MOIB.full_bridge_optimizer(optimizer, Float64)

@testset "MOI Nonlinear" begin
    config = MOIT.Config(atol=1e-3, rtol=1e-3, infeas_certificates=false, duals=false)
    excluded = String[
        "nlp_objective_and_moi_objective",
    ]
    MOIT.nlptest(bridged, config, excluded)
end
end#rm
end # module
