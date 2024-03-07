# Copyright (c) 2015: Joey Huchette and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

function set_bounds(info::Union{VariableInfo,ConstraintInfo}, set::MOI.EqualTo)
    set_lower_bound(info, set.value)
    set_upper_bound(info, set.value)
    return
end

function set_bounds(
    info::Union{VariableInfo,ConstraintInfo},
    set::MOI.GreaterThan,
)
    set_lower_bound(info, set.lower)
    return
end

function set_bounds(info::Union{VariableInfo,ConstraintInfo}, set::MOI.LessThan)
    set_upper_bound(info, set.upper)
    return
end

function set_bounds(info::Union{VariableInfo,ConstraintInfo}, set::MOI.Interval)
    set_lower_bound(info, set.lower)
    set_upper_bound(info, set.upper)
    return
end

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VariableIndex},
    ::Type{<:Bounds{Float64}},
)
    return true
end

function MOI.add_constraint(
    model::Optimizer,
    f::MOI.VariableIndex,
    set::S,
) where {S<:Bounds{Float64}}
    check_variable_indices(model, vi)
    variable_info = find_variable_info(model, f)
    set_bounds(variable_info, set)
    return MOI.ConstraintIndex{MOI.VariableIndex,S}(f.value)
end

function MOI.is_valid(
    model::Optimizer,
    ci::MOI.ConstraintIndex{MOI.VariableIndex,MOI.LessThan{Float64}},
)
    if !MOI.is_valid(model, MOI.VariableIndex(ci.value))
        return false
    end
    info = model.inner.variable_info[ci.value]
    return info.upper_bound !== nothing && info.lower_bound != info.upper_bound
end

function MOI.is_valid(
    model::Optimizer,
    ci::MOI.ConstraintIndex{MOI.VariableIndex,MOI.GreaterThan{Float64}},
)
    if !MOI.is_valid(model, MOI.VariableIndex(ci.value))
        return false
    end
    info = model.inner.variable_info[ci.value]
    return info.lower_bound !== nothing && info.lower_bound != info.upper_bound
end

function MOI.is_valid(
    model::Optimizer,
    ci::MOI.ConstraintIndex{MOI.VariableIndex,MOI.EqualTo{Float64}},
)
    if !MOI.is_valid(model, MOI.VariableIndex(ci.value))
        return false
    end
    info = model.inner.variable_info[ci.value]
    return info.lower_bound !== nothing && info.lower_bound == info.upper_bound
end

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{
        <:Union{
            MOI.ScalarAffineFunction{Float64},
            MOI.ScalarQuadraticFunction{Float64},
            MOI.ScalarNonlinearFunction,
        },
    },
    ::Type{<:Bounds{Float64}},
)
    return true
end

function MOI.is_valid(
    model::Optimizer,
    ::MOI.ConstraintIndex{F,<:Bounds{Float64}},
) where {
    F<:Union{
        MOI.ScalarAffineFunction{Float64},
        MOI.ScalarQuadraticFunction{Float64},
        MOI.ScalarNonlinearFunction,
    },
}
    return 1 <= ci.value <= length(model.inner.constraint_info)
end

function MOI.add_constraint(
    model::Optimizer,
    f::F,
    set::S,
) where {
    F<:Union{
        MOI.ScalarAffineFunction{Float64},
        MOI.ScalarQuadraticFunction{Float64},
    },
    S<:Bounds{Float64},
}
    ci = ConstraintInfo()
    ci.expression = to_expr(f)
    set_bounds(ci, set)
    push!(model.inner.constraint_info, ci)
    return MOI.ConstraintIndex{F,S}(length(model.inner.constraint_info))
end

# see comment in: write_bar_file
# MOI.supports(::Optimizer, ::MOI.ConstraintName, ::Type{MOI.ConstraintIndex}) = true
# function MOI.set(model::Optimizer, attr::MOI.ConstraintName, ci::MOI.ConstraintIndex{MOI.VariableIndex}, value)
#     error("No support for naming constraints imposed on variables.")
# end
# function MOI.set(model::Optimizer, attr::MOI.ConstraintName, ci::MOI.ConstraintIndex, value)
#     check_constraint_indices(model, ci)
#     model.inner.constraint_info[ci.value].name = value
# end
# function MOI.get(model::Optimizer, ::MOI.ConstraintName, ci::MOI.ConstraintIndex)
#      return model.inner.constraint_info[ci.value].name
# end
# function MOI.get(model::Optimizer, ::Type{MathOptInterface.ConstraintIndex}, name::String)
#     for (i,c) in enumerate(model.inner.constraint_info)
#         if name == c.name
#             return MOI.ConstraintIndex(i)
#         end
#     end
#     error("Unrecognized constraint name $name.")
# end

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VariableIndex},
    ::Type{MOI.ZeroOne},
)
    return true
end

function MOI.is_valid(
    model::Optimizer,
    ci::MOI.ConstraintIndex{MOI.VariableIndex,MOI.ZeroOne},
)
    return MOI.is_valid(model, MOI.VariableIndex(ci.value)) &&
           model.inner.variable_info[ci.value].category == :Bin
end

function MOI.add_constraint(
    model::Optimizer,
    f::MOI.VariableIndex,
    ::MOI.ZeroOne,
)
    find_variable_info(model, f).category = :Bin
    return MOI.ConstraintIndex{MOI.VariableIndex,MOI.ZeroOne}(f.value)
end

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VariableIndex},
    ::Type{MOI.Integer},
)
    return true
end

function MOI.is_valid(
    model::Optimizer,
    ci::MOI.ConstraintIndex{MOI.VariableIndex,MOI.Integer},
)
    return MOI.is_valid(model, MOI.VariableIndex(ci.value)) &&
           model.inner.variable_info[ci.value].category == :Int
end

function MOI.add_constraint(
    model::Optimizer,
    f::MOI.VariableIndex,
    ::MOI.Integer,
)
    find_variable_info(model, f).category = :Int
    return MOI.ConstraintIndex{MOI.VariableIndex,MOI.Integer}(f.value)
end

# MOI.supports(::Optimizer, ::MOI.NLPBlock) = true

# function MOI.set(model::Optimizer, ::MOI.NLPBlock, nlp_block_data::MOI.NLPBlockData)
#     model.nlp_block_data = nlp_block_data
#     return
# end
