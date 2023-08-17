# Copyright (c) 2015: Joey Huchette and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module BadExpressions

using JuMP, BARON, Test

@testset "UnrecognizedExpressionException" begin
    exception =
        BARON.UnrecognizedExpressionException("comparison", :(sin(x[1])))
    buf = IOBuffer()
    Base.showerror(buf, exception)
    @test occursin("sin(x[1])", String(take!(buf)))
end

@testset "Trig unrecognized" begin
    model = Model(BARON.Optimizer)
    @variable model x
    @NLconstraint model sin(x) == 0
    # @test_throws BARON.UnrecognizedExpressionException optimize!(model) # FIXME: currently broken due to lack of NLPBlock support.
end

end # module
