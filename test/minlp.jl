module MINLP

using JuMP, BARON, Compat.Test

m = Model(with_optimizer(BARON.Optimizer))
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

end # module
