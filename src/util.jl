function set_lower_bound(info::Union{VariableInfo, ConstraintInfo}, value::Union{Number, Nothing})
    if value !== nothing
        info.lower_bound !== nothing && throw(ArgumentError("Lower bound has already been set"))
        info.lower_bound = value
    end
    return
end

function set_upper_bound(info::Union{VariableInfo, ConstraintInfo}, value::Union{Number, Nothing})
    if value !== nothing
        info.upper_bound !== nothing && throw(ArgumentError("Upper bound has already been set"))
        info.upper_bound = value
    end
    return
end

function is_empty(model::BaronModel)
    isempty(model.variable_info) && isempty(model.constraint_info)
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
end

verify_support(c) = c

function verify_support(c::Expr)
    if c.head == :comparison
        map(verify_support, c.args)
        return c
    end
    if c.head == :call
        if c.args[1] in (:+, :-, :*, :/, :exp, :log)
            return c
        elseif c.args[1] in (:<=, :>=, :(==))
            map(verify_support, c.args[2:end])
            return c
        elseif c.args[1] == :^
            @assert isa(c.args[2], Real) || isa(c.args[3], Real)
            return c
        else # TODO: do automatic transformation for x^y, |x|
            error("Unsupported expression $c")
        end
    end
    return c
end

function print_var_definitions(m::BaronModel, fp, header, condition)
    idx = filter(condition, 1 : length(m.variable_info))
    if !isempty(idx)
        println(fp, header, join([m.variable_info[i].name for i in idx], ", "), ";")
    end
end

wrap_with_parens(x::String) = string("(", x, ")")

to_str(x) = string(x)

struct UnrecognizedExpressionException <: Exception
    exprtype::String
    expr
end
function Base.showerror(io::IO, err::UnrecognizedExpressionException)
    print(io, "UnrecognizedExpressionException: ")
    print(io, "unrecognized $(err.exprtype) expression: $(err.expr)")
end

function to_str(c::Expr)
    if c.head == :comparison
        if length(c.args) == 3
            return join([to_str(c.args[1]), c.args[2], c.args[3]], " ")
        elseif length(c.args) == 5
            return join([c.args[1], c.args[2], to_str(c.args[3]),
                         c.args[4], c.args[5]], " ")
        else
            throw(UnrecognizedExpressionException("comparison", c))
        end
    elseif c.head == :call
        if c.args[1] in (:<=,:>=,:(==))
            if length(c.args) == 3
                return join([to_str(c.args[2]), to_str(c.args[1]), to_str(c.args[3])], " ")
            elseif length(c.args) == 5
                return join([to_str(c.args[1]), to_str(c.args[2]), to_str(c.args[3]), to_str(c.args[4]), to_str(c.args[5])], " ")
            end
        elseif c.args[1] in (:+,:-,:*,:/,:^)
            if all(d->isa(d, Real), c.args[2:end]) # handle unary case
                return wrap_with_parens(string(eval(c)))
            elseif c.args[1] == :- && length(c.args) == 2
                return wrap_with_parens(string("(-$(to_str(c.args[2])))"))
            else
                return wrap_with_parens(string(join([to_str(d) for d in c.args[2:end]], string(c.args[1]))))
            end
        elseif c.args[1] in (:exp,:log)
            if isa(c.args[2], Real)
                return wrap_with_parens(string(eval(c)))
            else
                return wrap_with_parens(string(c.args[1], wrap_with_parens(to_str(c.args[2]))))
            end
        else
            throw(UnrecognizedExpressionException("comparison", c))
        end
    elseif c.head == :ref
        if c.args[1] == :x
            @assert isa(c.args[2], Int)
            return "x$(c.args[2])"
        else
            throw(UnrecognizedExpressionException("reference", c))
        end
    end
end

function write_bar_file(m::BaronModel)
    open(m.problem_file_name, "w") do fp
        # First: process any options
        println(fp, "OPTIONS{")
        for (opt,setting) in m.options
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
        print_var_definitions(m, fp, "BINARY_VARIABLES ",   v->(m.variable_info[v].category == :Bin))
        print_var_definitions(m, fp, "INTEGER_VARIABLES ",  v->(m.variable_info[v].category == :Int))
        print_var_definitions(m, fp, "POSITIVE_VARIABLES ", v->(m.variable_info[v].category == :Cont && m.variable_info[v].lower_bound == 0))
        print_var_definitions(m, fp, "VARIABLE ",           v->(m.variable_info[v].category == :Cont && m.variable_info[v].lower_bound != 0))
        println(fp)

        # Print variable bounds
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
            println(fp, "EQUATIONS ", join([constr.name for constr in m.constraint_info], ", "), ";")
            for c in m.constraint_info
                print(fp, c.name, ": ")
                str = to_str(c.expression)
                if c.lower_bound == c.upper_bound
                    print(fp, str, " == ", c.upper_bound)
                else
                    if c.lower_bound !== nothing && c.upper_bound !== nothing
                        print(fp, c.lower_bound, " <= ", str, " <= ", c.upper_bound)
                    elseif c.lower_bound !== nothing
                        print(fp, str, " >= ", c.lower_bound)
                    elseif c.upper_bound !== nothing
                        print(fp, str, " <= ", c.upper_bound)
                    end
                end
                println(fp, ";")
            end
            println(fp)
        end

        # Now let's do the objective
        objective_info = m.objective_info
        print(fp, "OBJ: ")
        if objective_info.sense == :Feasibility
            print(fp, "minimize 0")
        else
            if objective_info.sense == :Min
                print(fp, "minimize ")
            elseif objective_info.sense == :Max
                print(fp, "maximize ")
            else
                error("Objective sense not recognized.")
            end
            print(fp, to_str(objective_info.expression))
        end
        println(fp, ";")
        println(fp)

        if any(v -> v.start !== nothing, m.variable_info)
            println(fp, "STARTING_POINT{")
            for var in m.variable_info
                if var.start !== nothing
                    println(fp, "$(v.name): $(v.start)")
                end
            end
            println(fp, "}")
        end
    end
end

function read_results(m::BaronModel)
    m.solution_info = SolutionStatus()

    # First, read the time file to get the solution status
    nodeopt = 0
    open(m.times_file_name, "r") do fp
        spl = split(readchomp(fp))
        m.solution_info.dual_bound = parse(Float64, spl[6])
        m.solution_info.objective_value = parse(Float64, spl[7])
        m.solution_info.solver_status = BaronSolverStatus(parse(Int, spl[8]))
        m.solution_info.model_status = BaronModelStatus(parse(Int, spl[9]))
        nodeopt = parse(Int, spl[12])
        m.solution_info.wall_time = parse(Float64, spl[end])
    end

    # Next, we read the results file to get the solution
    if nodeopt != -3 # parse as long as there exist a solution
        m.solution_info.feasible_point = fill(NaN, length(m.variable_info))
        open(m.result_file_name, "r") do fp
            while true
                startswith(readline(fp), "The best solution found") && break
                eof(fp) && error("Reached end of results file without finding expected optimal primal solution")
            end
            readline(fp)
            readline(fp)

            while true
                line = chomp(readline(fp))
                parts = split(line)
                isempty(parts) && break
                mt = match(r"\d+", parts[1])
                mt == nothing && error("Cannot find appropriate variable index from $(parts[1])")
                v_idx = parse(Int, mt.match)
                v_val = parse(Float64, parts[3])
                m.solution_info.feasible_point[v_idx] = v_val
            end
        end
    end
    return
end
