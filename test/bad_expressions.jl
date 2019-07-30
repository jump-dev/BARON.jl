module BadExpressions

using Compat, JuMP, BARON, Compat.Test

@testset "UnrecognizedExpressionException" begin
    exception = BARON.UnrecognizedExpressionException("comparison", :(sin(x[1])))
    buf = IOBuffer()
    Base.showerror(buf, exception)
    @test Compat.occursin("sin(x[1])", String(take!(buf)))
end

@testset "Trig unrecognized" begin
    model = Model(with_optimizer(BARON.Optimizer))
    @variable model x
    @NLconstraint model sin(x) == 0
    # @test_throws BARON.UnrecognizedExpressionException optimize!(model) # FIXME: currently broken due to lack of NLPBlock support.
end

end # module
