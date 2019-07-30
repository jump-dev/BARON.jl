module Pool1

using JuMP, BARON

m = Model(with_optimizer(BARON.Optimizer))
lb = [0,3,1,2,0,0,0]
ub = [10,20,2,4,10,201,100]
@variable(m, lb[i] ≤ x[i=1:7] ≤ ub[i])

@constraints(m, begin
    x[3]^2 + x[4]^2 ≤ 12
    x[1]^2 - x[2]^2 + x[4]^2 ≥ 3
    x[1]^2 - x[2]^2 + x[4]^2 ≤ 100
    x[1] + x[2] - 5x[3] + 2x[4] ≥ 10
    x[1] + x[2] - 5x[3] + 2x[4] ≤ 20
    x[4] - x[6]^2 + 4x[7]^2 ≤ 0
end)

@objective(m, Min, 6x[1] + 16x[2] - 9x[3] - 10x[4])

optimize!(m)

end # module
