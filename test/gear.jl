using JuMP, BARON, Base.Test

m = Model(solver=BaronSolver())
ub = [2, 2, 1]
@defVar(m, 12 ≤ x[i=1:4] ≤ 60, start = 24)

@addNLConstraints(m, begin
    x[3] ≤ x[4]
    x[2] ≤ x[1]
end)

@setNLObjective(m, Min, 6.931 - x[1]*x[2]/(x[3]*x[4])^2 + 1)

solve(m)
