module Gear

using JuMP, BARON, Compat.Test

m = Model(solver=BaronSolver())
ub = [2, 2, 1]
@variable(m, 12 ≤ x[i=1:4] ≤ 60, start = 24)

@NLconstraints(m, begin
    x[3] ≤ x[4]
    x[2] ≤ x[1]
end)

@NLobjective(m, Min, 6.931 - x[1]*x[2]/(x[3]*x[4])^2 + 1)

solve(m)

end # module
