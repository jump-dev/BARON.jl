# Copyright (c) 2015: Joey Huchette and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module BARON

import MathOptInterface as MOI

include(joinpath(dirname(@__DIR__), "deps", "path.jl"))

@enum BaronSolverStatus begin
    NORMAL_COMPLETION = 1
    INSUFFICIENT_MEMORY_FOR_NODES = 2
    ITERATION_LIMIT = 3
    TIME_LIMIT = 4
    NUMERICAL_SENSITIVITY = 5
    USER_INTERRUPTION = 6
    INSUFFICIENT_MEMORY_FOR_SETUP = 7
    RESERVED = 8
    TERMINATED_BY_BARON = 9
    SYNTAX_ERROR = 10
    LICENSING_ERROR = 11
    USER_HEURISTIC_TERMINATION = 12
    CALL_TO_EXEC_FAILED = 99 # TODO allow reach here
end

@enum BaronModelStatus begin
    OPTIMAL = 1
    INFEASIBLE = 2
    UNBOUNDED = 3
    INTERMEDIATE_FEASIBLE = 4
    UNKNOWN = 5
end

const _Bounds = Union{
    MOI.EqualTo{Float64},
    MOI.GreaterThan{Float64},
    MOI.LessThan{Float64},
    MOI.Interval{Float64},
}

mutable struct _VariableInfo
    lower_bound::Union{Float64,Nothing}
    upper_bound::Union{Float64,Nothing}
    category::Symbol
    start::Union{Float64,Nothing}

    _VariableInfo() = new(nothing, nothing, :Cont, nothing)
end

mutable struct _ConstraintInfo
    expression::Expr
    lower_bound::Union{Float64,Nothing}
    upper_bound::Union{Float64,Nothing}
end

mutable struct _SolutionStatus
    feasible_point::Union{Nothing,Vector{Float64}}
    objective_value::Float64
    dual_bound::Float64
    wall_time::Float64
    solver_status::BaronSolverStatus
    model_status::BaronModelStatus

    function _SolutionStatus()
        return new(nothing, NaN, NaN, NaN, CALL_TO_EXEC_FAILED, UNKNOWN)
    end
end

"""
    Optimizer()

Create a new BARON optimizer.
"""
mutable struct Optimizer <: MOI.AbstractOptimizer
    options::Dict{String,Any}
    variable_info::Vector{_VariableInfo}
    constraint_info::Vector{_ConstraintInfo}
    objective_sense::MOI.OptimizationSense
    objective_expr::Union{Nothing,Real,Expr}
    temp_dir_name::String
    problem_file_name::String
    times_file_name::String
    summary_file_name::String
    result_file_name::String
    solution_info::Union{Nothing,_SolutionStatus}
    print_input_file::Bool
    nlp_block_data::Union{Nothing,MOI.NLPBlockData}

    function Optimizer(; kwargs...)
        options = Dict{String,Any}(string(key) => val for (key, val) in kwargs)
        temp_dir = mktempdir()
        return new(
            options,
            _VariableInfo[],
            _ConstraintInfo[],
            MOI.FEASIBILITY_SENSE,
            nothing,
            temp_dir,
            get!(options, "ProName", joinpath(temp_dir, "baron_problem.bar")),
            get!(options, "TimName", joinpath(temp_dir, "tim.lst")),
            get!(options, "SumName", joinpath(temp_dir, "sum.lst")),
            get!(options, "ResName", joinpath(temp_dir, "res.lst")),
            nothing,
            false,
            nothing,
        )
    end
end

# _to_expr

_to_expr(x::Real) = x

_to_expr(vi::MOI.VariableIndex) = :(x[$(vi.value)])

function _to_expr(f::MOI.ScalarAffineFunction)
    f = MOI.Utilities.canonical(f)
    if isempty(f.terms)
        return f.constant
    end
    expr = Expr(:call, :+)
    if !iszero(f.constant)
        push!(expr.args, f.constant)
    end
    for term in f.terms
        if isone(term.coefficient)
            push!(expr.args, :(x[$(term.variable.value)]))
        else
            push!(expr.args, :($(term.coefficient) * x[$(term.variable.value)]))
        end
    end
    if length(expr.args) == 2
        return expr.args[end]
    end
    return expr
end

function _to_expr(f::MOI.ScalarQuadraticFunction)
    f = MOI.Utilities.canonical(f)
    expr = Expr(:call, :+)
    if !iszero(f.constant)
        push!(expr.args, f.constant)
    end
    for term in f.affine_terms
        if isone(term.coefficient)
            push!(expr.args, :(x[$(term.variable.value)]))
        else
            push!(expr.args, :($(term.coefficient) * x[$(term.variable.value)]))
        end
    end
    for term in f.quadratic_terms
        i, j = term.variable_1.value, term.variable_2.value
        coef = (i == j ? 0.5 : 1.0) * term.coefficient
        if isone(coef)
            push!(expr.args, :(x[$i] * x[$j]))
        else
            push!(expr.args, :($coef * x[$i] * x[$j]))
        end
    end
    if length(expr.args) == 1
        return f.constant
    elseif length(expr.args) == 2
        return expr.args[end]
    end
    return expr
end

function _to_expr(f::MOI.ScalarNonlinearFunction)
    if !(f.head in _LIST_OF_SUPPORTED_NONLINEAR_OPERATORS)
        throw(MOI.UnsupportedNonlinearOperator(f.head))
    end
    expr = Expr(:call, f.head)
    for arg in f.args
        push!(expr.args, _to_expr(arg))
    end
    return expr
end

# _set_bounds

function _set_bounds(
    info::Union{_VariableInfo,_ConstraintInfo},
    set::MOI.EqualTo,
)
    _set_lower_bound(info, set.value)
    _set_upper_bound(info, set.value)
    return
end

function _set_bounds(
    info::Union{_VariableInfo,_ConstraintInfo},
    set::MOI.GreaterThan,
)
    _set_lower_bound(info, set.lower)
    return
end

function _set_bounds(
    info::Union{_VariableInfo,_ConstraintInfo},
    set::MOI.LessThan,
)
    _set_upper_bound(info, set.upper)
    return
end

function _set_bounds(
    info::Union{_VariableInfo,_ConstraintInfo},
    set::MOI.Interval,
)
    if isfinite(set.lower)
        _set_lower_bound(info, set.lower)
    end
    if isfinite(set.upper)
        _set_upper_bound(info, set.upper)
    end
    return
end

function _set_lower_bound(info::Union{_VariableInfo,_ConstraintInfo}, value)
    if info.lower_bound !== nothing
        throw(ArgumentError("Lower bound has already been set"))
    end
    info.lower_bound = value
    return
end

function _set_upper_bound(info::Union{_VariableInfo,_ConstraintInfo}, value)
    if info.upper_bound !== nothing
        throw(ArgumentError("Upper bound has already been set"))
    end
    info.upper_bound = value
    return
end

# MOI.SolverName

MOI.get(::Optimizer, ::MOI.SolverName) = "BARON"

# MOI.empty!

function MOI.is_empty(model::Optimizer)
    return isempty(model.variable_info) &&
           isempty(model.constraint_info) &&
           model.nlp_block_data === nothing
end

function MOI.empty!(model::Optimizer)
    for key in ("ProName", "TimName", "SumName", "ResName")
        if startswith(model.options[key], model.temp_dir_name)
            delete!(model.options, key)
        end
    end
    empty!(model.variable_info)
    empty!(model.constraint_info)
    model.objective_sense = MOI.FEASIBILITY_SENSE
    model.objective_expr = nothing
    temp_dir = model.temp_dir_name = mktempdir()
    model.problem_file_name =
        get!(model.options, "ProName", joinpath(temp_dir, "baron_problem.bar"))
    model.times_file_name =
        get!(model.options, "TimName", joinpath(temp_dir, "tim.lst"))
    model.summary_file_name =
        get!(model.options, "SumName", joinpath(temp_dir, "sum.lst"))
    model.result_file_name =
        get!(model.options, "ResName", joinpath(temp_dir, "res.lst"))
    model.solution_info = nothing
    model.nlp_block_data = nothing
    return
end

# MOI.copy_to

MOI.supports_incremental_interface(::Optimizer) = true

function MOI.copy_to(dest::Optimizer, src::MOI.ModelLike)
    return MOI.Utilities.default_copy_to(dest, src)
end

# MOI.RawOptimizerAttribute

MOI.supports(::Optimizer, ::MOI.RawOptimizerAttribute) = true

function MOI.set(model::Optimizer, param::MOI.RawOptimizerAttribute, value)
    model.options[param.name] = value
    return
end

function MOI.get(model::Optimizer, param::MOI.RawOptimizerAttribute)
    return get(model.options, param.name, nothing)
end

# MOI.TimeLimitSec

MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true

function MOI.set(model::Optimizer, ::MOI.TimeLimitSec, val::Real)
    model.options["MaxTime"] = convert(Float64, val)
    return
end

function MOI.set(model::Optimizer, ::MOI.TimeLimitSec, ::Nothing)
    delete!(model.options, "MaxTime")
    return
end

function MOI.get(model::Optimizer, ::MOI.TimeLimitSec)
    return get(model.options, "MaxTime", nothing)
end

# MOI.Silent

MOI.supports(::Optimizer, ::MOI.Silent) = true

function MOI.get(model::Optimizer, ::MOI.Silent)
    return get(model.options, "prlevel", 1) == 0
end

function MOI.set(model::Optimizer, ::MOI.Silent, value::Bool)
    model.options["prlevel"] = value ? 0 : 1
    return
end

# BARON.PrintInputFile

struct PrintInputFile <: MOI.AbstractOptimizerAttribute end

function MOI.set(model::Optimizer, ::PrintInputFile, val::Bool)
    model.print_input_file = val
    return
end

function MOI.get(model::Optimizer, ::PrintInputFile)
    return model.print_input_file
end

# MOI.ListOfSupportedNonlinearOperators

const _LIST_OF_SUPPORTED_NONLINEAR_OPERATORS =
    [:+, :-, :*, :/, :^, :exp, :log, :abs]

function MOI.get(::Optimizer, ::MOI.ListOfSupportedNonlinearOperators)
    return _LIST_OF_SUPPORTED_NONLINEAR_OPERATORS
end

# MOI.ObjectiveSense

MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true

function MOI.set(
    model::Optimizer,
    ::MOI.ObjectiveSense,
    sense::MOI.OptimizationSense,
)
    model.objective_sense = sense
    return
end

# MOI.ObjectiveFunction

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
    model.objective_expr = _to_expr(obj)
    return
end

# MOI.NumberOfVariables

function MOI.get(model::Optimizer, ::MOI.NumberOfVariables)
    return length(model.variable_info)
end

# MOI.ListOfVariableIndices

function MOI.get(model::Optimizer, ::MOI.ListOfVariableIndices)
    return MOI.VariableIndex.(1:length(model.variable_info))
end

# MOI.add_variable

function MOI.add_variable(model::Optimizer)
    push!(model.variable_info, _VariableInfo())
    return MOI.VariableIndex(length(model.variable_info))
end

# MOI.is_valid(::Optimizer, :MOI.VariableIndex)

function MOI.is_valid(model::Optimizer, x::MOI.VariableIndex)
    return 1 <= x.value <= length(model.variable_info)
end

# MOI.VariablePrimalStart

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
    model.variable_info[vi.value].start = value
    return
end

# MOI.VariableIndex -in- Bounds

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VariableIndex},
    ::Type{<:_Bounds},
)
    return true
end

function MOI.add_constraint(
    model::Optimizer,
    f::MOI.VariableIndex,
    set::S,
) where {S<:_Bounds}
    MOI.throw_if_not_valid(model, f)
    _set_bounds(model.variable_info[f.value], set)
    return MOI.ConstraintIndex{MOI.VariableIndex,S}(f.value)
end

function MOI.is_valid(
    model::Optimizer,
    ci::MOI.ConstraintIndex{MOI.VariableIndex,MOI.LessThan{Float64}},
)
    if !MOI.is_valid(model, MOI.VariableIndex(ci.value))
        return false
    end
    info = model.variable_info[ci.value]
    return info.upper_bound !== nothing && info.lower_bound != info.upper_bound
end

function MOI.is_valid(
    model::Optimizer,
    ci::MOI.ConstraintIndex{MOI.VariableIndex,MOI.GreaterThan{Float64}},
)
    if !MOI.is_valid(model, MOI.VariableIndex(ci.value))
        return false
    end
    info = model.variable_info[ci.value]
    return info.lower_bound !== nothing && info.lower_bound != info.upper_bound
end

function MOI.is_valid(
    model::Optimizer,
    ci::MOI.ConstraintIndex{MOI.VariableIndex,MOI.EqualTo{Float64}},
)
    if !MOI.is_valid(model, MOI.VariableIndex(ci.value))
        return false
    end
    info = model.variable_info[ci.value]
    return info.lower_bound !== nothing && info.lower_bound == info.upper_bound
end

# MOI.VariableIndex -in- MOI.ZeroOne

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
           model.variable_info[ci.value].category == :Bin
end

function MOI.add_constraint(
    model::Optimizer,
    f::MOI.VariableIndex,
    ::MOI.ZeroOne,
)
    model.variable_info[f.value].category = :Bin
    return MOI.ConstraintIndex{MOI.VariableIndex,MOI.ZeroOne}(f.value)
end

# MOI.VariableIndex -in- MOI.Integer

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
           model.variable_info[ci.value].category == :Int
end

function MOI.add_constraint(
    model::Optimizer,
    f::MOI.VariableIndex,
    ::MOI.Integer,
)
    model.variable_info[f.value].category = :Int
    return MOI.ConstraintIndex{MOI.VariableIndex,MOI.Integer}(f.value)
end

# Row constraints

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{
        <:Union{
            MOI.ScalarAffineFunction{Float64},
            MOI.ScalarQuadraticFunction{Float64},
            MOI.ScalarNonlinearFunction,
        },
    },
    ::Type{<:_Bounds},
)
    return true
end

function MOI.is_valid(
    model::Optimizer,
    ci::MOI.ConstraintIndex{F,<:_Bounds},
) where {
    F<:Union{
        MOI.ScalarAffineFunction{Float64},
        MOI.ScalarQuadraticFunction{Float64},
        MOI.ScalarNonlinearFunction,
    },
}
    return 1 <= ci.value <= length(model.constraint_info)
end

function MOI.add_constraint(
    model::Optimizer,
    f::F,
    set::S,
) where {
    F<:Union{
        MOI.ScalarAffineFunction{Float64},
        MOI.ScalarQuadraticFunction{Float64},
        MOI.ScalarNonlinearFunction,
    },
    S<:_Bounds,
}
    ci = _ConstraintInfo(_to_expr(f), nothing, nothing)
    _set_bounds(ci, set)
    push!(model.constraint_info, ci)
    return MOI.ConstraintIndex{F,S}(length(model.constraint_info))
end

# MOI.NLPBlock

MOI.supports(::Optimizer, ::MOI.NLPBlock) = true

function _walk_and_strip_variable_index!(expr::Expr)
    for i in 1:length(expr.args)
        if expr.args[i] isa MOI.VariableIndex
            expr.args[i] = expr.args[i].value
        end
        _walk_and_strip_variable_index!(expr.args[i])
    end
    return expr
end

_walk_and_strip_variable_index!(not_expr) = not_expr

function MOI.set(model::Optimizer, attr::MOI.NLPBlock, data::MOI.NLPBlockData)
    if model.nlp_block_data !== nothing
        msg = "Nonlinear block already set; cannot overwrite. Create a new model instead."
        throw(MOI.SetAttributeNotAllowed(attr, msg))
    end
    model.nlp_block_data = data
    MOI.initialize(data.evaluator, [:ExprGraph])
    if data.has_objective
        obj = MOI.objective_expr(data.evaluator)
        model.objective_expr = _walk_and_strip_variable_index!(obj)
    end
    for (i, bound) in enumerate(data.constraint_bounds)
        expr = MOI.constraint_expr(data.evaluator, i)
        lb, f, ub = if expr.head == :call
            if expr.args[1] == :(==)
                bound.lower, expr.args[2], bound.upper
            elseif expr.args[1] == :(<=)
                nothing, expr.args[2], bound.upper
            else
                @assert expr.args[1] == :(>=)
                bound.lower, expr.args[2], nothing
            end
        else
            @assert expr.head == :comparison
            @assert expr.args[2] == expr.args[4]
            bound.lower, expr.args[3], bound.upper
        end
        c_expr = _walk_and_strip_variable_index!(f)
        push!(model.constraint_info, _ConstraintInfo(c_expr, lb, ub))
    end
    return
end

# MOI.optimize!

struct UnrecognizedExpressionException <: Exception
    exprtype::String
    expr::Any
end

function Base.showerror(io::IO, err::UnrecognizedExpressionException)
    print(io, "UnrecognizedExpressionException: ")
    return print(io, "unrecognized $(err.exprtype) expression: $(err.expr)")
end

_isexpr(expr::Expr, head) = expr.head == head

_isexpr(expr::Expr, head, n) = expr.head == head && length(expr.args) == n

_iscall(expr::Expr, op) = _isexpr(expr, :call) && expr.args[1] == op

_iscall(expr::Expr, op, n) = _isexpr(expr, :call, n + 1) && expr.args[1] == op

_to_str(x) = string(x)

function _to_str(c::Expr)
    if _isexpr(c, :ref, 2) && c.args[1] == :x
        @assert c.args[2] isa Int
        return "x$(c.args[2])"
    elseif _iscall(c, :+)
        return string("(", join(_to_str.(c.args[2:end]), '+'), ")")
    elseif _iscall(c, :*)
        return string("(", join(_to_str.(c.args[2:end]), '*'), ")")
    elseif _iscall(c, :-, 1)
        return string("(-", _to_str(c.args[2]), ")")
    elseif _iscall(c, :-, 2)
        return string('(', _to_str(c.args[2]), '-', _to_str(c.args[3]), ')')
    elseif _iscall(c, :exp, 1)
        return string("exp(", _to_str(c.args[2]), ")")
    elseif _iscall(c, :log, 1)
        return string("log(", _to_str(c.args[2]), ")")
    elseif _iscall(c, :/, 2)
        return string('(', _to_str(c.args[2]), '/', _to_str(c.args[3]), ')')
    elseif _iscall(c, :^, 2)
        if c.args[3] isa Real
            return string('(', _to_str(c.args[2]), '^', c.args[3], ')')
        else
            # BARON does not support x^y natively for x,y variables. Instead
            # we transform to the equivalent expression exp(y * log(x)).
            return _to_str(:(exp($(c.args[3]) * log($(c.args[2])))))
        end
    elseif _iscall(c, :abs, 1)
        # BARON does not support abs(x) natively for variable x. Instead
        # we transform to the equivalent expression sqrt(x^2).
        return _to_str(:(($(c.args[2])^2.0)^(0.5)))
    end
    return throw(UnrecognizedExpressionException("function call", c))
end

function _print_var_definitions(condition, model::Optimizer, fp, header)
    indices = filter(condition, 1:length(model.variable_info))
    if !isempty(indices)
        print(fp, header, "x", first(indices))
        for i in 2:length(indices)
            print(fp, ", x", indices[i])
        end
        println(fp, ";")
    end
    return
end

function _write_bar_file(model::Optimizer)
    open(model.problem_file_name, "w") do fp
        # First: process any options
        println(fp, "OPTIONS{")
        for (opt, setting) in model.options
            if isa(setting, AbstractString) # wrap it in quotes
                println(fp, "$opt: \"$setting\";")
            else
                println(fp, "$opt: $setting;")
            end
        end
        println(fp, "}")
        println(fp)
        # Next, define variables
        _print_var_definitions(model, fp, "BINARY_VARIABLES ") do v
            return model.variable_info[v].category == :Bin
        end
        _print_var_definitions(model, fp, "INTEGER_VARIABLES ") do v
            return model.variable_info[v].category == :Int
        end
        _print_var_definitions(model, fp, "POSITIVE_VARIABLES ") do v
            return model.variable_info[v].category == :Cont &&
                   model.variable_info[v].lower_bound == 0
        end
        _print_var_definitions(model, fp, "VARIABLE ") do v
            return model.variable_info[v].category == :Cont &&
                   model.variable_info[v].lower_bound != 0
        end
        println(fp)
        # Print variable bounds
        if any(info -> info.lower_bound !== nothing, model.variable_info)
            println(fp, "LOWER_BOUNDS{")
            for (i, variable_info) in enumerate(model.variable_info)
                if variable_info.lower_bound !== nothing
                    println(fp, "x$i: $(variable_info.lower_bound);")
                end
            end
            println(fp, "}")
            println(fp)
        end
        if any(info -> info.upper_bound !== nothing, model.variable_info)
            println(fp, "UPPER_BOUNDS{")
            for (i, variable_info) in enumerate(model.variable_info)
                if variable_info.upper_bound !== nothing
                    println(fp, "x$i: $(variable_info.upper_bound);")
                end
            end
            println(fp, "}")
            println(fp)
        end
        # Now let's declare the equations
        if !isempty(model.constraint_info)
            print(fp, "EQUATIONS c1")
            for i in 2:length(model.constraint_info)
                print(fp, ", c", i)
            end
            println(fp, ";")
            for (i, c) in enumerate(model.constraint_info)
                if c.lower_bound === c.upper_bound === nothing
                    continue # A free constraint. Skip it.
                end
                print(fp, "c", i, ": ")
                str = _to_str(c.expression)
                if c.lower_bound == c.upper_bound
                    print(fp, str, " == ", c.upper_bound)
                elseif c.lower_bound !== nothing && c.upper_bound !== nothing
                    print(fp, c.lower_bound, " <= ", str, " <= ", c.upper_bound)
                elseif c.lower_bound !== nothing
                    print(fp, str, " >= ", c.lower_bound)
                else
                    @assert c.upper_bound !== nothing
                    print(fp, str, " <= ", c.upper_bound)
                end
                println(fp, ";")
            end
            println(fp)
        end
        # Now let's do the objective
        print(fp, "OBJ: ")
        if model.objective_sense == MOI.FEASIBILITY_SENSE ||
           model.objective_expr === nothing ||
           model.objective_expr == :()
            println(fp, "minimize 0;")
        elseif model.objective_sense == MOI.MIN_SENSE
            println(fp, "minimize ", _to_str(model.objective_expr), ";")
        else
            @assert model.objective_sense == MOI.MAX_SENSE
            println(fp, "maximize ", _to_str(model.objective_expr), ";")
        end
        if any(v -> v.start !== nothing, model.variable_info)
            println(fp)
            println(fp, "STARTING_POINT{")
            for (i, var) in enumerate(model.variable_info)
                if var.start !== nothing
                    println(fp, "x$i: $(var.start);")
                end
            end
            println(fp, "}")
        end
    end
    return
end

function _read_results(model::Optimizer)
    model.solution_info = _SolutionStatus()
    # First, read the time file to get the solution status
    nodeopt = 0
    open(model.times_file_name, "r") do fp
        spl = split(readchomp(fp))
        if model.objective_sense == MOI.MIN_SENSE
            model.solution_info.dual_bound = parse(Float64, spl[6])
            model.solution_info.objective_value = parse(Float64, spl[7])
        else
            model.solution_info.dual_bound = parse(Float64, spl[7])
            model.solution_info.objective_value = parse(Float64, spl[6])
        end
        model.solution_info.solver_status =
            BaronSolverStatus(parse(Int, spl[8]))
        model.solution_info.model_status = BaronModelStatus(parse(Int, spl[9]))
        nodeopt = parse(Int, spl[12])
        model.solution_info.wall_time = parse(Float64, spl[end])
        return
    end
    # Next, we read the results file to get the solution
    if nodeopt == -3
        return  # No solution exists
    end
    model.solution_info.feasible_point = fill(NaN, length(model.variable_info))
    open(model.result_file_name, "r") do fp
        while true
            if startswith(readline(fp), "The best solution found")
                break
            elseif eof(fp)
                error(
                    "Reached end of results file without finding expected optimal primal solution",
                )
            end
        end
        readline(fp)
        readline(fp)
        while true
            line = chomp(readline(fp))
            parts = split(line)
            if isempty(parts)
                break
            end
            mt = match(r"\d+", parts[1])
            if mt == nothing
                error("Cannot find appropriate variable index from $(parts[1])")
            end
            v_idx = parse(Int, mt.match)
            model.solution_info.feasible_point[v_idx] = parse(Float64, parts[3])
        end
        return
    end
    return
end

function MOI.optimize!(model::Optimizer)
    _write_bar_file(model)
    if model.print_input_file
        println("\nBARON input file: $(model.problem_file_name)\n")
        println(read(model.problem_file_name, String))
    end
    try
        run(`$baron_exec $(model.problem_file_name)`)
    catch e
        msg = """
        Failed to call BARON exec `$baron_exec`.

        Check the BARON log for details.

        The Julia error was:
        ```
        $e
        ```

        The `.bar` file was:
        ```
        $(read(model.problem_file_name, String))
        ```
        """
        error(msg)
    end
    _read_results(model)
    return
end

# MOI.ResultCount

function MOI.get(model::Optimizer, ::MOI.ResultCount)
    return (model.solution_info.feasible_point === nothing) ? 0 : 1
end

# MOI.TerminationStatus

const _SOLVER_STATUS_MAP = Dict(
    # NORMAL_COMPLETION = 1  # Handled separately
    INSUFFICIENT_MEMORY_FOR_NODES => MOI.MEMORY_LIMIT,
    ITERATION_LIMIT => MOI.ITERATION_LIMIT,
    TIME_LIMIT => MOI.TIME_LIMIT,
    NUMERICAL_SENSITIVITY => MOI.NUMERICAL_ERROR,
    USER_INTERRUPTION => MOI.INTERRUPTED,
    INSUFFICIENT_MEMORY_FOR_SETUP => MOI.MEMORY_LIMIT,
    RESERVED => MOI.OTHER_ERROR,
    TERMINATED_BY_BARON => MOI.OTHER_ERROR,
    SYNTAX_ERROR => MOI.INVALID_MODEL,
    LICENSING_ERROR => MOI.OTHER_ERROR,
    USER_HEURISTIC_TERMINATION => MOI.OTHER_LIMIT,
    CALL_TO_EXEC_FAILED => MOI.OTHER_ERROR,
)

const _MODEL_STATUS_MAP = Dict(
    OPTIMAL => MOI.OPTIMAL,
    INFEASIBLE => MOI.INFEASIBLE,
    UNBOUNDED => MOI.DUAL_INFEASIBLE,
    INTERMEDIATE_FEASIBLE => MOI.LOCALLY_SOLVED,
    UNKNOWN => MOI.OTHER_ERROR,
)

function MOI.get(model::Optimizer, ::MOI.TerminationStatus)
    solution_info = model.solution_info
    if solution_info === nothing
        return MOI.OPTIMIZE_NOT_CALLED
    end
    if solution_info.solver_status == NORMAL_COMPLETION
        return _MODEL_STATUS_MAP[solution_info.model_status]
    end
    return _SOLVER_STATUS_MAP[solution_info.solver_status]
end

# MOI.PrimalStatus

function MOI.get(model::Optimizer, attr::MOI.PrimalStatus)
    if attr.result_index != 1
        return MOI.NO_SOLUTION
    end
    solution_info = model.solution_info
    if solution_info === nothing || solution_info.feasible_point === nothing
        return MOI.NO_SOLUTION
    end
    return MOI.FEASIBLE_POINT
end

# MOI.DualStatus

MOI.get(::Optimizer, ::MOI.DualStatus) = MOI.NO_SOLUTION

# MOI.RawStatusString

function MOI.get(model::Optimizer, ::MOI.RawStatusString)
    info = model.solution_info
    return "solver: $(info.solver_status), model: $(info.model_status)"
end

# MOI.ObjectiveValue

function MOI.get(model::Optimizer, attr::MOI.ObjectiveValue)
    MOI.check_result_index_bounds(model, attr)
    return model.solution_info.objective_value
end

# MOI.ObjectiveBound

function MOI.get(model::Optimizer, ::MOI.ObjectiveBound)
    return model.solution_info.dual_bound
end

# MOI.SolveTimeSec

function MOI.get(model::Optimizer, ::MOI.SolveTimeSec)
    return model.solution_info.wall_time
end

# MOI.VariablePrimal

function MOI.get(
    model::Optimizer,
    attr::MOI.VariablePrimal,
    vi::MOI.VariableIndex,
)
    MOI.check_result_index_bounds(model, attr)
    MOI.throw_if_not_valid(model, vi)
    return model.solution_info.feasible_point[vi.value]
end

# MOI.ConstraintPrimal

function MOI.get(
    model::MOI.Utilities.CachingOptimizer{BARON.Optimizer},
    attr::MOI.ConstraintPrimal,
    ci::MOI.ConstraintIndex,
)
    return MOI.Utilities.get_fallback(model, attr, ci)
end

end  # module
