function set_bounds(info::Union{VariableInfo, ConstraintInfo}, set::MOI.EqualTo)
    set_lower_bound(info, set.value)
    set_upper_bound(info, set.value)
end

function set_bounds(info::Union{VariableInfo, ConstraintInfo}, set::MOI.GreaterThan)
    set_lower_bound(info, set.lower)
end

function set_bounds(info::Union{VariableInfo, ConstraintInfo}, set::MOI.LessThan)
    set_upper_bound(info, set.upper)
end

function set_bounds(info::Union{VariableInfo, ConstraintInfo}, set::MOI.Interval)
    set_lower_bound(info, set.lower)
    set_upper_bound(info, set.upper)
end

MOI.supports_constraint(::Optimizer, ::Type{SV}, ::Type{<:Bounds}) = true

function MOI.add_constraint(model::Optimizer, f::SV, set::S) where {S <: Bounds}
    variable_info = find_variable_info(model, f.variable)
    set_bounds(variable_info, set)
    return CI{SV, S}(f.variable.value)
end

MOI.supports_constraint(::Optimizer, ::Type{<:Union{SAF, SQF}}, ::Type{<:Bounds}) = true

function MOI.add_constraint(model::Optimizer, f::F, set::S) where {F <: Union{SAF, SQF}, S <: Bounds}
    ci = ConstraintInfo()
    ci.expression = to_expr(f)
    set_bounds(ci, set)
    push!(model.inner.constraint_info, ci)
    return CI{F, S}(length(model.inner.constraint_info))
end

MOI.supports(::Optimizer, ::MOI.ConstraintName, ::Type{CI}) = true

function MOI.set(model::Optimizer, attr::MOI.ConstraintName, ci::CI{SV}, value)
    error("No support for naming constraints imposed on variables.")
end
function MOI.set(model::Optimizer, attr::MOI.ConstraintName, ci::CI, value)
    check_constraint_indices(model, ci)
    model.inner.constraint_info[ci.value].name = value
end
function MOI.get(model::Optimizer, ::MOI.ConstraintName, ci::CI)
     return model.inner.constraint_info[ci.value].name
end

function MOI.get(model::Optimizer, ::Type{MathOptInterface.ConstraintIndex}, name::String)
    for (i,c) in enumerate(model.inner.constraint_info)
        if name == c.name
            return CI(i)
        end
    end
    error("Unrecognized constraint name $name.")
end

MOI.supports_constraint(::Optimizer, ::Type{SV}, ::Type{MOI.ZeroOne}) = true
MOI.supports_constraint(::Optimizer, ::Type{SV}, ::Type{MOI.Integer}) = true

function MOI.add_constraint(model::Optimizer, f::SV, set::S) where {S <: Union{MOI.ZeroOne, MOI.Integer}}
    variable_info = find_variable_info(model, f.variable)
    if set isa MOI.ZeroOne
        variable_info.category = :Bin
    elseif set isa MOI.Integer
        variable_info.category = :Int
    else
        error("Unsupported variable type $set.")
    end
    return CI{SV, S}(f.variable.value)
end

# MOI.supports(::Optimizer, ::MOI.NLPBlock) = true

# function MOI.set(model::Optimizer, ::MOI.NLPBlock, nlp_block_data::MOI.NLPBlockData)
#     model.nlp_block_data = nlp_block_data
#     return
# end
