module BARON

using MathProgBase
using MathProgBase.SolverInterface
using Compat

export BaronSolver
struct BaronSolver <: AbstractMathProgSolver
    options
end

BaronSolver(;kwargs...) = BaronSolver(kwargs)

const baron_exec = ENV["BARON_EXEC"]

mutable struct BaronMathProgModel <: AbstractNonlinearModel
    options::Dict{Symbol, Any}

    xˡ::Vector{Float64}
    xᵘ::Vector{Float64}
    gˡ::Vector{Float64}
    gᵘ::Vector{Float64}

    nvar::Int
    ncon::Int

    obj
    constrs

    vartypes::Vector{Symbol}

    v_names::Vector{String}
    c_names::Vector{String}

    sense::Symbol

    x₀::Vector{Float64}

    tmpdir::String
    probfile::String
    sumfile::String
    resfile::String

    objval::Float64
    dualbound::Float64
    solution::Vector{Float64}
    walltime::Float64
    status::Symbol

    d::AbstractNLPEvaluator

    function BaronMathProgModel(;kwargs...)
        tmpdir = mktempdir()
        options = Dict{Symbol, Any}(key=>val for (key,val) in kwargs)
        get!(options, :ResName, joinpath(tmpdir, "res.lst"))
        get!(options, :TimName, joinpath(tmpdir, "tim.lst"))
        get!(options, :SumName, joinpath(tmpdir, "sum.lst"))
        new(options,
            zeros(0),
            zeros(0),
            zeros(0),
            zeros(0),
            0,
            0,
            :(0),
            Expr[],
            Symbol[],
            String[],
            String[],
            :Min,
            zeros(0),
            tmpdir,
            "",
            "",
            "",
            NaN,
            NaN,
            [NaN],
            0.0,
            :NotSolved)
    end
end

MathProgBase.NonlinearModel(s::BaronSolver) = BaronMathProgModel(;s.options...)
MathProgBase.LinearQuadraticModel(s::BaronSolver) = MathProgBase.NonlinearToLPQPBridge(MathProgBase.NonlinearModel(s))

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

function MathProgBase.loadproblem!(m::BaronMathProgModel,
    nvar, ncon, xˡ, xᵘ, gˡ, gᵘ, sense,
    d::MathProgBase.AbstractNLPEvaluator)

    @assert nvar == length(xˡ) == length(xᵘ)
    @assert ncon == length(gˡ) == length(gᵘ)

    m.xˡ, m.xᵘ = xˡ, xᵘ
    m.gˡ, m.gᵘ = gˡ, gᵘ
    m.sense = sense
    m.nvar, m.ncon = nvar, ncon
    m.d = d

    m.v_names = ["x$i" for i in 1:nvar]
    m.c_names = ["e$i" for i in 1:ncon]

    MathProgBase.initialize(d, [:ExprGraph])

    m.obj = verify_support(MathProgBase.obj_expr(d))
    m.vartypes = fill(:Cont, nvar)

    m.constrs = map(1:ncon) do c
        verify_support(MathProgBase.constr_expr(d,c))
    end

    m.probfile = joinpath(m.tmpdir, "baron_problem.bar")
    m.sumfile  = joinpath(m.tmpdir, "sum.lst")
    m.resfile  = joinpath(m.tmpdir, "res.lst")
    m
end

function MathProgBase.setvartype!(m::BaronMathProgModel, cat::Vector{Symbol})
    @assert all(x-> (x in (:Cont,:Bin,:Int)), cat)
    m.vartypes = cat
end

function print_var_definitions(m, fp, header, condition)
    idx = filter(condition, 1:m.nvar)
    if !isempty(idx)
        println(fp, header, join([m.v_names[i] for i in idx], ", "), ";")
    end
end

wrap_with_parens(x::String) = string("(", x, ")")

# to_str(x::Int) = string(x)
# to_str(x) = (@show(x); string(float(x)))
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

function write_bar_file(m::BaronMathProgModel)
    fp = open(m.probfile, "w")

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

    # Next, define variables
    print_var_definitions(m, fp, "BINARY_VARIABLES ",   v->(m.vartypes[v]==:Bin))
    print_var_definitions(m, fp, "INTEGER_VARIABLES ",  v->(m.vartypes[v]==:Int))
    print_var_definitions(m, fp, "POSITIVE_VARIABLES ", v->(m.vartypes[v]==:Cont && m.xˡ[v]==0))
    print_var_definitions(m, fp, "VARIABLE ",           v->(m.vartypes[v]==:Cont && m.xˡ[v]!=0))
    println(fp)

    # Print variable bounds
    if any(c->!isinf(c), m.xˡ)
        println(fp, "LOWER_BOUNDS{")
        for (i,l) in enumerate(m.xˡ)
            if !isinf(l)
                println(fp, "$(m.v_names[i]): $l;")
            end
        end
        println(fp, "}")
        println(fp)
    end
    if any(c->!isinf(c), m.xᵘ)
        println(fp, "UPPER_BOUNDS{")
        for (i,u) in enumerate(m.xᵘ)
            if !isinf(u)
                println(fp, "$(m.v_names[i]): $u;")
            end
        end
        println(fp, "}")
        println(fp)
    end

    # Now let's declare the equations
    if !isempty(m.constrs)
        println(fp, "EQUATIONS ", join(m.c_names, ", "), ";")
        for (i,c) in enumerate(m.constrs)
            str = to_str(c)
            println(fp, "$(m.c_names[i]): $str;")
        end
        println(fp)
    end

    # Now let's do the objective
    print(fp, "OBJ: ")
    print(fp, m.sense == :Min ? "minimize " : "maximize ")
    print(fp, to_str(m.obj))
    println(fp, ";")
    println(fp)

    if !isempty(m.x₀)
        println(fp, "STARTING_POINT{")
        for (i,v) in enumerate(m.x₀)
            println(fp, "$(m.v_names[i]): $v;")
        end
        println(fp, "}")
    end
    close(fp)
end

const normal_status = [
    ["***", "Normal", "completion", "***"]
]

const userlimits_status = [
    ["***", "Max.", "allowable", "nodes", "in", "memory", "reached", "***"],
    ["***", "Max.", "allowable", "BaR", "iterations", "reached", "***"],
    ["***", "Max.", "allowable", "CPU", "time", "exceeded", "***"],
    ["***", "Max.", "allowable", "time", "exceeded", "***"],
    ["***", "Problem", "is", "numerically", "sensitive", "***"],
    ["***", "Heuristic", "termination", "***"],
    ["***", "Globality", "is", "therefore", "not", "guaranteed", "***"]
]

const infeasible_status = [
    ["***", "Problem", "is", "infeasible", "***"],
    ["***", "No", "feasible", "solution", "was", "found", "***"],
    ["***", "Infeasibility", "is", "therefore", "not", "guaranteed", "***"],
    ["***", "Insufficient", "Memory", "for", "Data", "structures", "***"],
]

const unbounded_status = [
    ["***", "Problem", "is", "unbounded", "***"],
    ["***", "User" ,"did", "not", "provide", "appropriate", "variable", "bounds", "***"]
]

const numerical_status = [
    ["***", "Problem", "is", "numerically", "sensitive", "***"]
]

const interrupt_status = [
    ["***", "Search", "interrupted", "by", "user", "***"]
]

const error_status = [
    ["***", "A", "potentially", "catastrophic", "access", "violation", "just", "took", "place", "***"]
]

function read_results(m::BaronMathProgModel)

    # First, we read the summary file to get the solution status
    stat_code = []
    fp = open(m.sumfile, "r")
    stat = :Undefined
    t = -1.0
    n = -99
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
            m.dualbound = parse(Float64, spl[4])
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
                    m.dualbound = parsed_duals = parse(Float64, spl[end-1])
                finally
                end
            end
        end
        eof(fp) && break
    end
    close(fp)

    t < 0.0 && warn("No solution time is found in sum.lst")
    n == -99 && error("No solution node information found sum.lst")

    # Now navigate to the right problem status by looking at the main status
    if stat_code[1] in userlimits_status
        m.status = :UserLimit
        n == -3 && (m.status = :Infeasible)
    elseif stat_code[1] in normal_status
        m.status = :Optimal
        n == -3 && (m.status = :Infeasible)
    elseif stat_code[1] in infeasible_status
        m.status = :Infeasible
    elseif stat_code[1] in unbounded_status
        m.status = :Unbounded
    elseif stat_code[1] in numerical_status
        m.status = :NumericalSensitive
        n == -3 && (m.status = :Infeasible)
    elseif stat_code[1] in interrupt_status
        m.status = :Interrupted
        n == -3 && (m.status = :Infeasible)
    elseif stat_code[1] in error_status
        m.status = :Error
    end

    m.walltime = t # Track the time

    # Next, we read the results file to get the solution
    x = fill(NaN, m.nvar)
    m.objval = NaN
    if n != -3 # parse as long as there exist a solution
        fp = open(m.resfile, "r")
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
            x[v_idx] = v_val
        end
        m.solution = x
        line = readline(fp)
        val = match(r"[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?", chomp(line))
        if val != nothing
            m.objval = parse(Float64, val.match)
        end
    end
    nothing
end

MathProgBase.setwarmstart!(m::BaronMathProgModel, v::Vector{Float64}) = (m.x₀ = v)

function MathProgBase.optimize!(m::BaronMathProgModel)
    write_bar_file(m)
    run(`$baron_exec $(m.probfile)`)

    read_results(m)
end

MathProgBase.status(m::BaronMathProgModel) = m.status

MathProgBase.numvar(m::BaronMathProgModel) = m.nvar
MathProgBase.getsolution(m::BaronMathProgModel) = m.solution
MathProgBase.getobjval(m::BaronMathProgModel) = m.objval
MathProgBase.getobjbound(m::BaronMathProgModel) = m.dualbound
MathProgBase.getsolvetime(m::BaronMathProgModel) = m.walltime

end
