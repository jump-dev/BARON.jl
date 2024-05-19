# Copyright (c) 2015: Joey Huchette and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module JuMPTests

using JuMP
using Test

import BARON

function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
    return
end

function test_Gear()
    m = Model(BARON.Optimizer)
    @variable(m, 12 ≤ x[i = 1:4] ≤ 60, start = 24)
    @NLconstraints(m, begin
        x[3] ≤ x[4]
        x[2] ≤ x[1]
    end)
    @NLobjective(m, Min, 6.931 - x[1] * x[2] / (x[3] * x[4])^2 + 1)
    optimize!(m)
    @test isapprox(value(x[1]), 60, rtol = 1e-6)
    @test isapprox(value(x[2]), 60, rtol = 1e-6)
    @test isapprox(value(x[3]), 12, rtol = 1e-6)
    @test isapprox(value(x[4]), 12, rtol = 1e-6)
    @test isapprox(objective_value(m), 7.75738888889, rtol = 1e-6)
    return
end

function test_MINLP()
    m = Model(BARON.Optimizer)
    ub = [2, 2, 1]
    @variable(m, 0 ≤ x[i = 1:3] ≤ ub[i])
    @variable(m, y[1:3], Bin)
    @NLconstraints(
        m,
        begin
            0.8log(x[2] + 1) + 0.96log(x[1] - x[2] + 1) - 0.8x[3] ≥ 0
            log(x[2] + 1) + 1.20log(x[1] - x[2] + 1) - x[3] - 2y[3] ≥ -2
            x[2] ≤ x[1]
            x[2] ≤ 2y[1]
            x[1] - x[2] ≤ 2y[2]
            y[1] + y[2] ≤ 1
        end
    )
    @NLobjective(
        m,
        Min,
        5y[1] + 6y[2] + 8y[3] + 10x[1] - 7x[3] - 18log(x[2] + 1) -
        19.2log(x[1] - x[2] + 1) + 10
    )
    optimize!(m)
    @test isapprox(value(x[1]), 1.300975890892825, rtol = 1e-6)
    @test isapprox(value(x[2]), 0.0, rtol = 1e-6)
    @test isapprox(value(x[3]), 1.0, rtol = 1e-6)
    @test isapprox(value(y[1]), 0.0, rtol = 1e-6)
    @test isapprox(value(y[2]), 1.0, rtol = 1e-6)
    @test isapprox(value(y[3]), 0.0, rtol = 1e-6)
    @test isapprox(objective_value(m), 6.00975890893, rtol = 1e-6)
    return
end

function test_NLP1()
    m = Model(BARON.Optimizer)
    ub = [6, 4]
    @variable(m, 0 ≤ x[i = 1:2] ≤ ub[i], start = ub[i])
    @constraint(m, x[1] * x[2] ≤ 4)
    @objective(m, Min, -x[1] - x[2])
    optimize!(m)
    @test isapprox(value(x[1]), 6, rtol = 1e-6)
    @test isapprox(value(x[2]), 2 / 3, rtol = 2e-6)
    @test isapprox(objective_value(m), -20 / 3, rtol = 1e-6)
    return
end

function test_NLP2()
    m = Model(BARON.Optimizer)
    ub = [9.422, 5.9023, 267.417085245]
    @variable(m, 0 ≤ x[i = 1:3] ≤ ub[i], start = ub[i])
    @constraints(m, begin
        250 + 30x[1] - 6x[1]^2 == x[3]
        300 + 20x[2] - 12x[2]^2 == x[3]
        150 + 0.5 * (x[1] + x[2])^2 == x[3]
    end)
    @objective(m, Min, -x[3])
    optimize!(m)
    @test isapprox(value(x[1]), 6.2934300, rtol = 1e-6)
    @test isapprox(value(x[2]), 3.8218391, rtol = 1e-6)
    @test isapprox(value(x[3]), 201.1593341, rtol = 1e-5)
    @test isapprox(objective_value(m), -201.1593341, rtol = 1e-6)
    return
end

function test_Pool1()
    m = Model(BARON.Optimizer)
    lb = [0, 3, 1, 2, 0, 0, 0]
    ub = [10, 20, 2, 4, 10, 201, 100]
    @variable(m, lb[i] ≤ x[i = 1:7] ≤ ub[i])
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
    return
end

function test_UnrecognizedExpressionException()
    exception =
        BARON.UnrecognizedExpressionException("comparison", :(sin(x[1])))
    buf = IOBuffer()
    Base.showerror(buf, exception)
    @test occursin("sin(x[1])", String(take!(buf)))
    return
end

function test_trig_unrecognized()
    model = Model(BARON.Optimizer)
    @variable model x
    @NLconstraint model sin(x) == 0
    # @test_throws BARON.UnrecognizedExpressionException optimize!(model) # FIXME: currently broken due to lack of NLPBlock support.
    return
end

end  # module

JuMPTests.runtests()
