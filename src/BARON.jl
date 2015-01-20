module BARON

using MathProgBase
importall MathProgBase.SolverInterface

export BaronSolver
immutable BaronSolver <: AbstractMathProgSolver
    options
end
BaronSolver(;kwargs...) = BaronSolver(kwargs)

const baron_exec = ENV["BARON_EXEC"]

type BaronMathProgModel <: AbstractMathProgModel
    options

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

    probfile::String
    sumfile::String
    resfile::String

    objval::Float64
    solution::Vector{Float64}
    status::Symbol

    d::AbstractNLPEvaluator

    function BaronMathProgModel(;options...)
	push!(options, (:ResName, joinpath(Pkg.dir("BARON"), ".solverdata", "res.lst")))
	push!(options, (:TimName, joinpath(Pkg.dir("BARON"), ".solverdata", "tim.lst")))
	push!(options, (:SumName, joinpath(Pkg.dir("BARON"), ".solverdata", "sum.lst")))
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
            "",
	    "",
	    "",
	    NaN,
	    zeros(0),
            :NotSolved)    
    end
end

MathProgBase.model(s::BaronSolver) = BaronMathProgModel()

verify_support(c) = c

function verify_support(c::Expr)
    if c.head == :comparison
        map(verify_support, c.args)
        return c
    end
    if c.head == :call
        if c.args[1] in [:+, :-, :*, :/, :exp, :log]
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

function MathProgBase.loadnonlinearproblem!(m::BaronMathProgModel, 
    nvar, ncon, xˡ, xᵘ, gˡ, gᵘ, sense, 
    d::MathProgBase.AbstractNLPEvaluator)

    @assert nvar == length(xˡ) == length(xᵘ)
    @assert ncon == length(gˡ) == length(gᵘ)

    m.xˡ, m.xᵘ = xˡ, xᵘ
    m.gˡ, m.gᵘ = gˡ, gᵘ
    m.sense = sense
    m.nvar, m.ncon = nvar, ncon

    m.v_names = ["x$i" for i in 1:nvar]
    m.c_names = ["e$i" for i in 1:ncon]

    MathProgBase.initialize(d, [:ExprGraph])

    m.obj = verify_support(MathProgBase.obj_expr(d))
    m.vartypes = fill(:Cont, nvar)

    m.constrs = map(1:ncon) do c
        verify_support(MathProgBase.constr_expr(d,c))
    end

    m.probfile = joinpath(Pkg.dir("BARON"), ".solverdata", "baron_problem.bar")
    m.sumfile  = joinpath(Pkg.dir("BARON"), ".solverdata", "sum.lst")
    m.resfile  = joinpath(Pkg.dir("BARON"), ".solverdata", "res.lst")
    m
end

function MathProgBase.setvartype!(m::BaronMathProgModel, cat::Vector{Symbol})
    @assert all(x-> (x in [:Cont,:Bin,:Int]), cat)
    m.vartypes = cat
end

function print_var_definitions(m, fp, header, condition)
    idx = filter(condition, 1:m.nvar)
    if !isempty(idx)
        println(fp, header, join([m.v_names[i] for i in idx], ", "), ";")
    end
end

to_str(x::Int) = string(x)
to_str(x) = string(float(x))

function to_str(c::Expr)
    if c.head == :comparison
        if length(c.args) == 3
            return join([to_str(c.args[1]), c.args[2], c.args[3]], " ")
        elseif length(c.args) == 5
            return join([c.args[1], c.args[2], to_str(c.args[3]),
                         c.args[4], c.args[5]], " ")
        end
    elseif c.head == :call
        if c.args[1] in [:+,:-,:*,:/,:^]
            if all(d->isa(d, Real), c.args[2:end]) # handle unary case
                return string(eval(c))
            elseif c.args[1] == :- && length(c.args) == 2
		return string("(-$(to_str(c.args[2])))")
	    else
		return string("(", join([to_str(d) for d in c.args[2:end]], string(c.args[1])), ")")
            end
        elseif c.args[1] in [:exp,:log]
            if isa(c.args[2], Real)
                return string(eval(c))
            else
                return string(c.args[1], "( ", to_str(c.args[2]), " )")
            end
        end
    elseif c.head == :ref
        if c.args[1] == :x
            @assert isa(c.args[2], Int)
            return "x$(c.args[2])"
        else
            error("Unrecognized reference expression $c")
        end
    end
end

function write_bar_file(m::BaronMathProgModel)
    fp = open(m.probfile, "w")

    # First: process any options
    println(fp, "OPTIONS{")
    for (opt,setting) in m.options
        if isa(setting, String) # wrap it in quotes
	    println(fp, unescape_string("$opt: $('"')$setting$('"');"))
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

const user_limits = [
    "Max. allowable nodes in memory reached",
    "Max. allowable BaR iterations reached",
    "Max. allowable CPU time exceeded",
    "Problem is numerically sensitive",
    "Insufficient Memory for Data structures"
]

function read_results(m::BaronMathProgModel)
    # First, we read the summary file to get the solution status
    fp = open(m.sumfile, "r")
    stat = :Undefined
    while true
        line = readline(fp)
	spl = split(chomp(line))
        if !isempty(spl) && spl[1] == "***"
            if spl[2] in user_limits
                stat = :UserLimit
            end
            break
        end
        eof(fp) && error("Reached EOF while searching for termination notice")
    end
    while true
        line = readline(fp)
	spl = split(chomp(line))
        if !isempty(spl) && spl[1:3] == ["Best","solution","found"]
            node = int(match(r"\d+", line).match)
            if node == -3
                stat = :Infeasible
            end
            break
        else
            stat = :Optimal
            break
        end
        eof(fp) && error("Reached OEF while looking for node with best solution")
    end
    m.status = stat
    close(fp)

    # Next, we read the results file to get the solution
    x = fill(NaN, m.nvar)
    m.objval = NaN
    if stat == :Optimal
        fp = open(m.resfile, "r")
        while true
            startswith(readline(fp), "The best solution found") && break
            eof(fp) && error()
        end
        readline(fp)
        readline(fp)

        while true
            line = chomp(readline(fp))
            parts = split(line)
            isempty(parts) && break
            mt = match(r"\d+", parts[1])
            mt == nothing && error("Cannot find appropriate variable index from $(parts[1])")
            v_idx = int(mt.match)
            v_val = float(parts[3])
            x[v_idx] = v_val
        end
        m.solution = x
        line = readline(fp)
        val = match(r"[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?", chomp(line))
        if val != nothing
            m.objval = float(val.match)
        end
    end
    nothing
end

MathProgBase.setwarmstart!(m::BaronMathProgModel, v::Vector{Float64}) = 
    m.x₀ = v

function MathProgBase.optimize!(m::BaronMathProgModel)
    write_bar_file(m)
    run(`$baron_exec $(m.probfile)`)

    read_results(m)
end

MathProgBase.status(m::BaronMathProgModel) = m.status

MathProgBase.numvar(m::BaronMathProgModel) = m.nvar
MathProgBase.getsolution(m::BaronMathProgModel) = m.solution
MathProgBase.getobjval(m::BaronMathProgModel) = m.objval

end
