module NLP1

using JuMP, BARON, Compat.Test

m = Model(solver=BaronSolver())
ub = [6,4]
@variable(m, 0 ≤ x[i=1:2] ≤ ub[i])

@NLconstraint(m, x[1]*x[2] ≤ 4)

@NLobjective(m, Min, -x[1] - x[2])

solve(m)

@test isapprox(getvalue(x[1]), 6, rtol=1e-6)
@test isapprox(getvalue(x[2]), 2/3, rtol=1e-6)
@test isapprox(getobjectivevalue(m), -20/3, rtol=1e-6)

end # module
