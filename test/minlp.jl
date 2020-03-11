module MINLP

using JuMP, BARON, Test

m = Model(BARON.Optimizer)
ub = [2, 2, 1]
@variable(m, 0 ≤ x[i=1:3] ≤ ub[i])
@variable(m, y[1:3], Bin)

@NLconstraints(m, begin
    0.8log(x[2]+1) + 0.96log(x[1]-x[2]+1) - 0.8x[3]         ≥  0
       log(x[2]+1) + 1.20log(x[1]-x[2]+1)  -   x[3] - 2y[3] ≥ -2
       x[2] ≤  x[1]
       x[2] ≤ 2y[1]
       x[1] - x[2] ≤ 2y[2]
       y[1] + y[2] ≤ 1
end)

@NLobjective(m, Min, 5y[1] + 6y[2] + 8y[3] + 10x[1] - 7x[3] - 18log(x[2]+1) -
                        19.2log(x[1]-x[2]+1) + 10)

optimize!(m)

@test isapprox(value(x[1]), 1.300975890892825, rtol=1e-6)
@test isapprox(value(x[2]), 0.0, rtol=1e-6)
@test isapprox(value(x[3]), 1.0, rtol=1e-6)
@test isapprox(value(y[1]), 0.0, rtol=1e-6)
@test isapprox(value(y[2]), 1.0, rtol=1e-6)
@test isapprox(value(y[3]), 0.0, rtol=1e-6)
@test isapprox(objective_value(m), 6.00975890893, rtol=1e-6)

end # module
