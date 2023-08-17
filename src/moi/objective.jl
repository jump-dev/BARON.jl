# Copyright (c) 2015: Joey Huchette and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true

function MOI.set(
    model::Optimizer,
    ::MOI.ObjectiveSense,
    sense::MOI.OptimizationSense,
)
    if sense == MOI.MIN_SENSE
        model.inner.objective_sense = :Min
    elseif sense == MOI.MAX_SENSE
        model.inner.objective_sense = :Max
    elseif sense == MOI.FEASIBILITY_SENSE
        model.inner.objective_sense = :Feasibility
    else
        error("Unsupported objective sense: $sense")
    end
    return
end

function MOI.supports(
    ::Optimizer,
    ::MOI.ObjectiveFunction{
        <:Union{
            MOI.VariableIndex,
            MOI.ScalarAffineFunction{Float64},
            MOI.ScalarQuadraticFunction{Float64},
            MOI.ScalarNonlinearFunction,
        },
    },
)
    return true
end

function MOI.set(
    model::Optimizer,
    ::MOI.ObjectiveFunction{F},
    obj::F,
) where {
    F<:Union{
        MOI.VariableIndex,
        MOI.ScalarAffineFunction{Float64},
        MOI.ScalarQuadraticFunction{Float64},
        MOI.ScalarNonlinearFunction,
    },
}
    model.inner.objective_expr = to_expr(obj)
    return
end
