module Gear

using JuMP, BARON, Test

m = Model(BARON.Optimizer)
@variable(m, 12 ≤ x[i=1:4] ≤ 60, start = 24)

@NLconstraints(m, begin
    x[3] ≤ x[4]
    x[2] ≤ x[1]
end)

@NLobjective(m, Min, 6.931 - x[1]*x[2]/(x[3]*x[4])^2 + 1)

optimize!(m)

@test isapprox(value(x[1]), 60, rtol=1e-6)
@test isapprox(value(x[2]), 60, rtol=1e-6)
@test isapprox(value(x[3]), 12, rtol=1e-6)
@test isapprox(value(x[4]), 12, rtol=1e-6)
@test isapprox(objective_value(m), 7.75738888889, rtol=1e-6)

end # module
