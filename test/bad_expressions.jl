module BadExpressions

using Compat, JuMP, BARON, Compat.Test

@testset "UnrecognizedExpressionException" begin
    exception = BARON.UnrecognizedExpressionException(:(sin(x[1])))
    buf = IOBuffer()
    Base.showerror(buf, exception)
    @test Compat.occursin("sin(x[1])", String(take!(buf)))
end

@testset "Trig unrecognized" begin
    solver = BaronSolver()
    model = Model(solver=solver)
    @variable model x
    @NLconstraint model sin(x) == 0
    @test_throws BARON.UnrecognizedExpressionException solve(model)
end

end # module
