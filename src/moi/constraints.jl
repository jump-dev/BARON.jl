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
    if isfinite(set.lower)
        set_lower_bound(info, set.lower)
    end
    if isfinite(set.upper)
        set_upper_bound(info, set.upper)
    end
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
    MOI.throw_if_not_valid(model, f)
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
    ci::MOI.ConstraintIndex{F,<:Bounds{Float64}},
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
    ci = ConstraintInfo(to_expr(f), nothing, nothing)
    set_bounds(ci, set)
    push!(model.inner.constraint_info, ci)
    return MOI.ConstraintIndex{F,S}(length(model.inner.constraint_info))
end

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
