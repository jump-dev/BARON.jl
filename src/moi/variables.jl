# Copyright (c) 2015: Joey Huchette and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

function MOI.get(model::Optimizer, ::MOI.NumberOfVariables)
    return length(model.inner.variable_info)
end

function MOI.get(model::Optimizer, ::MOI.ListOfVariableIndices)
    return MOI.VariableIndex.(1:length(model.inner.variable_info))
end

function MOI.add_variable(model::Optimizer)
    push!(model.inner.variable_info, VariableInfo())
    return MOI.VariableIndex(length(model.inner.variable_info))
end

function MOI.is_valid(model::Optimizer, x::MOI.VariableIndex)
    return 1 <= x.value <= length(model.inner.variable_info)
end

function MOI.supports(
    ::Optimizer,
    ::MOI.VariablePrimalStart,
    ::Type{MOI.VariableIndex},
)
    return true
end

function MOI.set(
    model::Optimizer,
    ::MOI.VariablePrimalStart,
    vi::MOI.VariableIndex,
    value::Union{Real,Nothing},
)
    MOI.throw_if_not_valid(model, vi)
    model.inner.variable_info[vi.value].start = value
    return
end
