module NLP1

using JuMP, BARON, Compat.Test

m = Model(with_optimizer(BARON.Optimizer))
ub = [6,4]
@variable(m, 0 ≤ x[i=1:2] ≤ ub[i])

@constraint(m, x[1]*x[2] ≤ 4)

@objective(m, Min, -x[1] - x[2])

optimize!(m)

@test isapprox(value(x[1]), 6, rtol=1e-6)
@test isapprox(value(x[2]), 2/3, rtol=2e-6)
@test isapprox(objective_value(m), -20/3, rtol=1e-6)

end # module
