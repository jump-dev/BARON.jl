# Copyright (c) 2015: Joey Huchette and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

function set_lower_bound(
    info::Union{VariableInfo,ConstraintInfo},
    value::Union{Number,Nothing},
)
    if value !== nothing
        info.lower_bound !== nothing &&
            throw(ArgumentError("Lower bound has already been set"))
        info.lower_bound = value
    end
    return
end

function set_upper_bound(
    info::Union{VariableInfo,ConstraintInfo},
    value::Union{Number,Nothing},
)
    if value !== nothing
        info.upper_bound !== nothing &&
            throw(ArgumentError("Upper bound has already been set"))
        info.upper_bound = value
    end
    return
end

function is_empty(model::BaronModel)
    return isempty(model.variable_info) && isempty(model.constraint_info)
end

function set_unique_names!(infos, default_base_name::AbstractString)
    names = Set(String[])
    default_name_counter = Ref(1)
    for info in infos
        if info.name === nothing
            base_name = default_base_name
            name_counter = default_name_counter
        elseif info.name ∉ names
            push!(names, info.name)
            continue
        else
            base_name = info.name
            name_counter = Ref(1)
        end
        while true
            name = string(base_name, name_counter[])
            if name ∉ names
                info.name = name
                push!(names, info.name)
                break
            else
                name_counter[] += 1
            end
        end
    end
    return
end

function print_var_definitions(m::BaronModel, fp, header, condition)
    idx = filter(condition, 1:length(m.variable_info))
    if !isempty(idx)
        println(
            fp,
            header,
            join([m.variable_info[i].name for i in idx], ", "),
            ";",
        )
    end
end

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

to_str(x) = string(x)

function to_str(c::Expr)
    if _isexpr(c, :ref, 2) && c.args[1] == :x
        @assert c.args[2] isa Int
        # TODO decide is use use defined names. This might be messy because a
        # user can call their variable "sin"
        return "x$(c.args[2])"
    elseif _iscall(c, :+)
        return string("(", join(to_str.(c.args[2:end]), '+'), ")")
    elseif _iscall(c, :*)
        return string("(", join(to_str.(c.args[2:end]), '*'), ")")
    elseif _iscall(c, :-, 1)
        return string("(-", to_str(c.args[2]), ")")
    elseif _iscall(c, :-, 2)
        return string('(', to_str(c.args[2]), '-', to_str(c.args[3]), ')')
    elseif _iscall(c, :exp, 1)
        return string("exp(", to_str(c.args[2]), ")")
    elseif _iscall(c, :log, 1)
        return string("log(", to_str(c.args[2]), ")")
    elseif _iscall(c, :/, 2)
        return string('(', to_str(c.args[2]), '/', to_str(c.args[3]), ')')
    elseif _iscall(c, :^, 2)
        if c.args[3] isa Real
            return string('(', to_str(c.args[2]), '^', c.args[3], ')')
        else
            # BARON does not support x^y natively for x,y variables. Instead
            # we transform to the equivalent expression exp(y * log(x)).
            return to_str(:(exp($(c.args[3]) * log($(c.args[2])))))
        end
    elseif _iscall(c, :abs, 1)
        # BARON does not support abs(x) natively for variable x. Instead
        # we transform to the equivalent expression sqrt(x^2).
        return to_str(:(($(c.args[2])^2.0)^(0.5)))
    end
    return throw(UnrecognizedExpressionException("function call", c))
end

function write_bar_file(m::BaronModel)
    open(m.problem_file_name, "w") do fp
        # First: process any options
        println(fp, "OPTIONS{")
        for (opt, setting) in m.options
            if isa(setting, AbstractString) # wrap it in quotes
                println(fp, "$opt: \"$setting\";")
            else
                println(fp, "$opt: $setting;")
            end
        end
        println(fp, "}")
        println(fp)

        # Ensure that all variables and constraints have a name
        set_unique_names!(m.variable_info, "x")
        set_unique_names!(m.constraint_info, "e")

        # Next, define variables
        print_var_definitions(
            m,
            fp,
            "BINARY_VARIABLES ",
            v -> (m.variable_info[v].category == :Bin),
        )
        print_var_definitions(
            m,
            fp,
            "INTEGER_VARIABLES ",
            v -> (m.variable_info[v].category == :Int),
        )
        print_var_definitions(
            m,
            fp,
            "POSITIVE_VARIABLES ",
            v -> (
                m.variable_info[v].category == :Cont &&
                m.variable_info[v].lower_bound == 0
            ),
        )
        print_var_definitions(
            m,
            fp,
            "VARIABLE ",
            v -> (
                m.variable_info[v].category == :Cont &&
                m.variable_info[v].lower_bound != 0
            ),
        )
        println(fp)

        # Print variable bounds
        # TODO:
        # usage of variable_info.name must be revisited
        # now user names are disabled, but if they are enable
        # then bounds will use these names but
        # expressions will just use default names: "x$(variable_inde.value)"
        if any(info -> info.lower_bound !== nothing, m.variable_info)
            println(fp, "LOWER_BOUNDS{")
            for variable_info in m.variable_info
                l = variable_info.lower_bound
                if l !== nothing
                    println(fp, "$(variable_info.name): $l;")
                end
            end
            println(fp, "}")
            println(fp)
        end
        if any(info -> info.upper_bound !== nothing, m.variable_info)
            println(fp, "UPPER_BOUNDS{")
            for variable_info in m.variable_info
                u = variable_info.upper_bound
                if u !== nothing
                    println(fp, "$(variable_info.name): $u;")
                end
            end
            println(fp, "}")
            println(fp)
        end

        # Now let's declare the equations
        if !isempty(m.constraint_info)
            println(
                fp,
                "EQUATIONS ",
                join([constr.name for constr in m.constraint_info], ", "),
                ";",
            )
            for c in m.constraint_info
                if c.lower_bound === c.upper_bound === nothing
                    continue # A free constraint. Skip it.
                end
                print(fp, c.name, ": ")
                str = to_str(c.expression)
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
        if m.objective_sense == :Feasibility ||
           m.objective_expr === nothing ||
           m.objective_expr == :()
            println(fp, "minimize 0;")
        elseif m.objective_sense == :Min
            println(fp, "minimize ", to_str(m.objective_expr), ";")
        else
            @assert m.objective_sense == :Max
            println(fp, "maximize ", to_str(m.objective_expr), ";")
        end
        println(fp)

        if any(v -> v.start !== nothing, m.variable_info)
            println(fp, "STARTING_POINT{")
            for var in m.variable_info
                if var.start !== nothing
                    println(fp, "$(var.name): $(var.start);")
                end
            end
            println(fp, "}")
        end
    end
    return
end

function read_results(m::BaronModel)
    m.solution_info = SolutionStatus()

    # First, read the time file to get the solution status
    nodeopt = 0
    open(m.times_file_name, "r") do fp
        spl = split(readchomp(fp))
        if m.objective_sense == :Min
            m.solution_info.dual_bound = parse(Float64, spl[6])
            m.solution_info.objective_value = parse(Float64, spl[7])
        else
            m.solution_info.dual_bound = parse(Float64, spl[7])
            m.solution_info.objective_value = parse(Float64, spl[6])
        end
        m.solution_info.solver_status = BaronSolverStatus(parse(Int, spl[8]))
        m.solution_info.model_status = BaronModelStatus(parse(Int, spl[9]))
        nodeopt = parse(Int, spl[12])
        return m.solution_info.wall_time = parse(Float64, spl[end])
    end

    # Next, we read the results file to get the solution
    if nodeopt != -3 # parse as long as there exist a solution
        m.solution_info.feasible_point = fill(NaN, length(m.variable_info))
        open(m.result_file_name, "r") do fp
            while true
                startswith(readline(fp), "The best solution found") && break
                eof(fp) && error(
                    "Reached end of results file without finding expected optimal primal solution",
                )
            end
            readline(fp)
            readline(fp)

            while true
                line = chomp(readline(fp))
                parts = split(line)
                isempty(parts) && break
                mt = match(r"\d+", parts[1])
                mt == nothing && error(
                    "Cannot find appropriate variable index from $(parts[1])",
                )
                v_idx = parse(Int, mt.match)
                v_val = parse(Float64, parts[3])
                m.solution_info.feasible_point[v_idx] = v_val
            end
        end
    end
    return
end
