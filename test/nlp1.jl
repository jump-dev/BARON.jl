using JuMP, BARON, Base.Test

m = Model(solver=BaronSolver())
ub = [6,4]
@defVar(m, 0 ≤ x[i=1:2] ≤ ub[i])

@addNLConstraint(m, x[1]*x[2] ≤ 4)

@setNLObjective(m, Min, -x[1] - x[2])

solve(m)

@test_approx_eq getValue(x[1]) 6
@test_approx_eq getValue(x[2]) 2/3
@test_approx_eq getObjectiveValue(m) -20/3
