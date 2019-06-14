module MOITests

using BARON
using Test

using MathOptInterface
const MOI = MathOptInterface
const MOIT = MOI.Test
const MOIB = MOI.Bridges

const optimizer = BARON.Optimizer()
const config = MOIT.TestConfig(atol=1e-6, rtol=1e-6)

@testset "MOI Continuous Linear" begin
    MOIT.contlineartest(MOIB.SplitInterval{Float64}(optimizer), config)
end

# @testset "MOI Integer Linear" begin
#     MOIT.intlineartest(MOIB.SplitInterval{Float64}(optimizer), config)
# end

# @testset "MOI Nonlinear" begin
#     MOIT.nonlineartest(MOIB.SplitInterval{Float64}(optimizer), config)
# end

end # module
