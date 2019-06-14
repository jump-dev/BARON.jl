function MOI.add_constraint(model::Optimizer, f::SV, set::MOI.ZeroOne)
    vi = f.variable
    _check_inbounds(model, vi)
    model.inner.variable_info[vi.value].category = :Bin
    return
end

function MOI.add_constraint(model::Optimizer, f::SV, set::MOI.Integer)
    vi = f.variable
    _check_inbounds(model, vi)
    model.inner.variable_info[vi.value].category = :Int
    return
end
