MOI.supports_constraint(::Optimizer, ::Type{SV}, ::Type{MOI.ZeroOne}) = true
MOI.supports_constraint(::Optimizer, ::Type{SV}, ::Type{MOI.Integer}) = true

function MOIU.load_constraint(model::Optimizer, ci::CI, f::SV, set::Union{MOI.ZeroOne, MOI.Integer})
    vi = f.variable
    _check_inbounds(model, vi)
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


# function MOI.add_constraint(model::Optimizer, f::SV, set::MOI.ZeroOne)
#     vi = f.variable
#     _check_inbounds(model, vi)
#     model.inner.variable_info[vi.value].category = :Bin
#     return
# end

# function MOI.add_constraint(model::Optimizer, f::SV, set::MOI.Integer)
#     vi = f.variable
#     _check_inbounds(model, vi)
#     model.inner.variable_info[vi.value].category = :Int
#     return
# end
