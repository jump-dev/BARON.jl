module MOITests

using BARON
using Test

using MathOptInterface
const MOI = MathOptInterface
const MOIT = MOI.Test
const MOIB = MOI.Bridges

const optimizer = MOIB.full_bridge_optimizer(BARON.Optimizer(), Float64);

# TODO: test infeasibility certificates, duals.
const config = MOIT.TestConfig(atol=1e-5, rtol=1e-4, infeas_certificates=false, duals=false)

@testset "MOI Continuous Linear" begin
    excluded = [
        "linear1",  # needs MOI.delete (of variables in constraints)
        "linear5",  # needs MOI.delete (of variables in constraints)
        "linear14", # needs MOI.delete (of variables in constraints)
    ]
    MOIT.linear3test(optimizer, config)
    # MOIT.contlineartest(optimizer, config, excluded)
    @show optimizer.model.inner.problem_file_name
end

# @testset "MOI Integer Linear" begin
#     MOIT.intlineartest(optimizer, config)
# end

# @testset "MOI Nonlinear" begin
#     MOIT.nonlineartest(optimizer, config)
# end

end # module
