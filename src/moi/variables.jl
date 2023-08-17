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

function MOI.add_variables(model::Optimizer, nvars::Integer)
    return [MOI.add_variable(model) for i in 1:nvars]
end

function MOI.add_constraint(
    model::Optimizer,
    vi::MOI.VariableIndex,
    lt::MOI.LessThan{Float64},
)
    check_variable_indices(model, vi)
    set_upper_bound(model.inner.variable_info[vi.value], lt.upper)
    return MOI.ConstraintIndex{MOI.VariableIndex,MOI.LessThan{Float64}}(
        vi.value,
    )
end

function MOI.add_constraint(
    model::Optimizer,
    vi::MOI.VariableIndex,
    gt::MOI.GreaterThan{Float64},
)
    check_variable_indices(model, vi)
    set_lower_bound(model.inner.variable_info[vi.value], gt.lower)
    return MOI.ConstraintIndex{MOI.VariableIndex,MOI.GreaterThan{Float64}}(
        vi.value,
    )
end

function MOI.add_constraint(
    model::Optimizer,
    vi::MOI.VariableIndex,
    eq::MOI.EqualTo{Float64},
)
    check_variable_indices(model, vi)
    set_lower_bound(model.inner.variable_info[vi.value], eq.value)
    set_upper_bound(model.inner.variable_info[vi.value], eq.value)
    return MOI.ConstraintIndex{MOI.VariableIndex,MOI.EqualTo{Float64}}(vi.value)
end

# see comment in: write_bar_file
# MOI.supports(::Optimizer, ::MOI.VariableName, ::Type{MOI.VariableIndex}) = true
# function MOI.set(model::Optimizer, attr::MOI.VariableName, vi::MOI.VariableIndex, value)
#     check_variable_indices(model, vi)
#     model.inner.variable_info[vi.value].name = value
# end
# function MOI.get(model::Optimizer, ::MOI.VariableName, vi::MOI.VariableIndex)
#      return model.inner.variable_info[vi.value].name
# end
# function MOI.get(model::Optimizer, ::Type{MathOptInterface.VariableIndex}, name::String)
#     for (i,var) in enumerate(model.inner.variable_info)
#         if name == var.name
#             return MOI.VariableIndex(i)
#         end
#     end
#     error("Unrecognized variable name $name.")
# end

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
    check_variable_indices(model, vi)
    model.inner.variable_info[vi.value].start = value
    return
end
