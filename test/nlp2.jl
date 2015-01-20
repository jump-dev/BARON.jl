using JuMP, BARON, Base.Test

m = Model(solver=BaronSolver())
ub = [9.422, 5.9023, 267.417085245]
@defVar(m, 0 ≤ x[i=1:3] ≤ ub[i])

@addNLConstraints(m, begin
    250 + 30x[1] -  6x[1]^2 == x[3]
    300 + 20x[2] - 12x[2]^2 == x[3]
    150 + 0.5*(x[1]+x[2])^2 == x[3]
end)

@setNLObjective(m, Min, -x[3])

solve(m)

@test_approx_eq getValue(x[1]) 6.2934300
@test_approx_eq getValue(x[2]) 3.8218391
@test_approx_eq getValue(x[3]) 201.1593341
@test_approx_eq getObjectiveValue(m) -201.1593341
