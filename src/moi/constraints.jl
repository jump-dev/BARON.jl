set_bounds(info::Union{VariableInfo, ConstraintInfo}, bounds::Bounds) = set_bounds(info, MOI.Interval(bounds))

function set_bounds(info::Union{VariableInfo, ConstraintInfo}, interval::MOI.Interval)
    l, u = interval.lower, interval.upper
    l == -Inf || (info.lower_bound = l)
    u == Inf || (info.upper_bound = u)
    return
end

MOI.supports_constraint(::Optimizer, ::Type{SV}, ::Type{<:Bounds}) = true

function MOIU.load_constraint(model::Optimizer, ci::CI, f::SV, set::Bounds)
    vi = f.variable
    check_variable_indices(model, vi)
    variable_info = model.inner.variable_info[vi.value]
    set_bounds(variable_info, set)
    return
end

MOI.supports_constraint(::Optimizer, ::Type{<:Union{SAF, SQF}}, ::Type{<:Bounds}) = true

function MOIU.load_constraint(model::Optimizer, ci::CI, f::Union{SAF, SQF}, set::Bounds)
    check_variable_indices(model, f)
    constraint_info = model.inner.constraint_info[ci.value]
    constraint_info.expression = to_expr(f)
    set_bounds(constraint_info, set)
    return
end

MOI.supports_constraint(::Optimizer, ::Type{SV}, ::Type{MOI.ZeroOne}) = true
MOI.supports_constraint(::Optimizer, ::Type{SV}, ::Type{MOI.Integer}) = true

function MOIU.load_constraint(model::Optimizer, ci::CI, f::SV, set::Union{MOI.ZeroOne, MOI.Integer})
    vi = f.variable
    check_variable_indices(model, vi)
    variable_info = model.inner.variable_info[vi.value]
    if set isa MOI.ZeroOne
        variable_info.category = :Bin
    elseif set isa MOI.Integer
        variable_info.category = :Int
    else
        error()
    end
    return
end

# MOI.supports(::Optimizer, ::MOI.NLPBlock) = true

# function MOI.set(model::Optimizer, ::MOI.NLPBlock, nlp_block_data::MOI.NLPBlockData)
#     model.nlp_block_data = nlp_block_data
#     return
# end
