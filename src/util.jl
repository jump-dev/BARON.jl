function is_empty(model::BaronModel)
    isempty(model.variable_info) && isempty(model.constraint_info) && model.objective_info == nothing
end

function set_unique_variable_name!(model::BaronModel, i::Integer, base_name::AbstractString, counter::Union{Integer, Nothing}=nothing)
    if counter === nothing
        unique_name = base_name
        counter = 1
    else
        unique_name = "$(base_name)$(counter)"
    end
    info_i = model.variable_info[i]
    other_names = (info.name for info in model.variable_info if info != info_i)
    while true
        if any(isequal(unique_name), other_names)
            unique_name = "$(name)$(counter)"
            counter += 1
        else
            info_i.name = unique_name
            break
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
                println(fp, "$opt: $('"')$setting$('"');")
            else
                println(fp, "$opt: $setting;")
            end
        end
        println(fp, "}")
        println(fp)

        # Ensure that all variables have a name
        for (i, info) in enumerate(m.variable_info)
            if info.name === nothing
                set_unique_variable_name!(m, i, "x", 1)
            end
        end

        # Next, define variables
        print_var_definitions(m, fp, "BINARY_VARIABLES ",   v->(m.variable_info[v].category == :Bin))
        print_var_definitions(m, fp, "INTEGER_VARIABLES ",  v->(m.variable_info[v].category == :Int))
        print_var_definitions(m, fp, "POSITIVE_VARIABLES ", v->(m.variable_info[v].category == :Cont && m.variable_info[v].lower_bound == 0))
        print_var_definitions(m, fp, "VARIABLE ",           v->(m.variable_info[v].category == :Cont && m.variable_info[v].lower_bound != 0))
        println(fp)

        # Print variable bounds
        if any(c->!isinf(c.lower_bound), m.variable_info)
            println(fp, "LOWER_BOUNDS{")
            for (i,l) in enumerate(m.xˡ)
                if !isinf(l)
                    println(fp, "$(m.variable_info[i].name): $l;")
                end
            end
            println(fp, "}")
            println(fp)
        end
        if any(c->!isinf(c.upper_bound), m.variable_info)
            println(fp, "UPPER_BOUNDS{")
            for (i,u) in enumerate(m.xᵘ)
                if !isinf(u)
                    println(fp, "$(m.variable_info[i].name): $u;")
                end
            end
            println(fp, "}")
            println(fp)
        end

        # Now let's declare the equations
        if !isempty(m.constraint_info)
            println(fp, "EQUATIONS ", join([constr.name for constr in m.constraint_info], ", "), ";")
            for (i,c) in enumerate(m.constraint_info)
                str = to_str(c.expression)
                println(fp, "$(c.name): $str;")
            end
            println(fp)
        end

        # Now let's do the objective
        print(fp, "OBJ: ")
        objective_info = m.objective_info === nothing ? ObjectiveInfo() : m.objective_info
        print(fp, objective_info.sense == :Min ? "minimize " : "maximize ")
        print(fp, to_str(objective_info.expression))
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

const status_string_to_baron_status = Dict(
    ["***", "Normal", "completion", "***"] => NORMAL_COMPLETION,
    ["***", "Max.", "allowable", "nodes", "in", "memory", "reached", "***"] => NODE_LIMIT,
    ["***", "Max.", "allowable", "BaR", "iterations", "reached", "***"] => BAR_ITERATION_LIMIT,
    ["***", "Max.", "allowable", "CPU", "time", "exceeded", "***"] => CPU_TIME_LIMIT,
    ["***", "Max.", "allowable", "time", "exceeded", "***"] => TIME_LIMIT,
    ["***", "Problem", "is", "numerically", "sensitive", "***"] => NUMERICAL_SENSITIVITY,
    ["***", "Problem", "is", "infeasible", "***"] => INFEASIBLE,
    ["***", "Problem", "is", "unbounded", "***"] => UNBOUNDED,
    ["***", "User" ,"did", "not", "provide", "appropriate", "variable", "bounds", "***"] => INVALID_VARIABLE_BOUNDS,
    ["***", "Search", "interrupted", "by", "user", "***"] => USER_INTERRUPTION,
    ["***", "A", "potentially", "catastrophic", "access", "violation", "just", "took", "place", "***"] => ACCESS_VIOLATION
)

function read_results(m::BaronModel)
    # First, we read the summary file to get the solution status
    stat_code = []
    n = -99
    m.solution_info = SolutionStatus()
    open(m.summary_file_name, "r") do fp
        stat = :Undefined
        t = -1.0
        while true
            line = readline(fp)
            spl = split(chomp(line))
            if !isempty(spl) && spl[1] == "***"
                push!(stat_code, spl)
            elseif length(spl)>=3 && spl[1:3] == ["Wall", "clock", "time:"]
                t = parse(Float64,match(r"\d+.\d+", line).match)
            elseif length(spl)>=3 && spl[1:3] == ["Best", "solution", "found"]
                n = parse(Int,match(r"-?\d+", line).match)
            # Grab dual bound if solved during presolve (printed directly to summary file)
            elseif length(spl)>=3 && spl[1:3] == ["Lower", "bound", "is"]
                m.solution_info.dual_bound = parse(Float64, spl[4])
            # Grab dual bound if branching (need to get it from solver update log)
            elseif spl == ["Iteration", "Open", "nodes", "Time", "(s)", "Lower", "bound", "Upper", "bound"]
                while true
                    line = readline(fp)
                    spl = split(chomp(line))
                    if isempty(spl)
                        break
                    end
                    # Lowerbound is 4th column in table, but log line might include * for heuristic solution
                    # Also, if variables are unbounded, duals will not be available
                    try
                        m.solution_info.dual_bound = (parsed_duals = parse(Float64, spl[end-1]))
                    finally
                    end
                end
            end
            eof(fp) && break
        end
        t < 0.0 && warn("No solution time is found in sum.lst")
        n == -99 && error("No solution node information found sum.lst")
        m.solution_info.wall_time = t # Track the time
    end

    # Now navigate to the right problem status by looking at the main status
    m.solution_info.status = status_string_to_baron_status[stat_code[1]]
    m.solution_info.feasible_point = fill(NaN, length(m.variable_info))

    # Next, we read the results file to get the solution
    if n != -3 # parse as long as there exist a solution
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
            line = readline(fp)
            val = match(r"[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?", chomp(line))
            if val != nothing
                m.solution_info.objective_value = parse(Float64, val.match)
            end
        end
    end
    return
end

