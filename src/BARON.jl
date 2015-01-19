module BARON

using MathProgBase
importall MathProgBase.SolverInterface

export BaronSolver
immutable BaronSolver <: AbstractMathProgSolver
    options
end
BaronSolver(;kwargs...) = BaronSolver(kwargs)

try
    const baron_exec = ENV[:BARON_EXEC]
catch
    # error("Cannot locate Baron. Please set the BARON_EXEC environment variable pointing to the executable.")
end

type BaronMathProgModel <: AbstractMathProgModel
    options

    xˡ::Vector{Float64}
    xᵘ::Vector{Float64}
    gˡ::Vector{Float64}
    gᵘ::Vector{Float64}

    obj
    constrs

    vartypes::Vector{Symbol}

    v_names::Vector{String}
    c_names::Vector{String}

    sense::Symbol
    d::AbstractNLPEvaluator

    x₀::Vector{Float64}

    probfile::String
    resultfile::String

    function BaronMathProgModel(;options...)
        new(options)
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

    m.xˡ, m.xᵘ = xˡ,  xᵘ
    m.gˡ, m.gᵘ = gˡ, gᵘ
    m.sense = sense

    m.v_names = ["x$i" for i in 1:nvar]
    m.c_names = ["e$i" for i in 1:ncon]

    MathProgBase.initialize(d, [:ExprGraph])

    m.obj = verify_support(MathProgBase.obj_expr(d))
    m.vartypes = fill(:Cont, nvar)

    m.constrs = map(1:ncon) do c
        verify_support(MathProgBase.constr_expr(d,c))
    end

    m.probfile = joinpath(Pkg.dir("BARON"), ".baron_problem.bar")
    m
end

function MathProgBase.setvartype!(m::BaronMathProgModel, cat::Vector{Symbol})
    @assert all(x-> (x in [:Cont,:Bin,:Int]), cat)
    m.vartype = cat
end

function print_var_definitions(m, fp, header, condition)
    idx = filter(condition, 1:length(m.vartypes))
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
            if isa(c.args[2], Real) && isa(c.args[3], Real)
                return string(eval(c))
            else
                return join(["(", to_str(c.args[2]), c.args[1], to_str(c.args[3]), ")"], " ")
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
    # Note that this probably won't work, because it will print
    # Expr(:*, 2, x) as "2x", not as "2*x"
    println(fp, "EQUATIONS ", join(m.c_names, ", "), ";")
    for (i,c) in enumerate(m.constrs)
        str = to_str(c)
        println(fp, "$(m.c_names[i]): $str;")
    end
    println(fp)

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
    end
    close(fp)
end

MathProgBase.setwarmstart!(m::BaronMathProgModel, v::Vector{Float64}) = 
    m.x₀ = v

function MathProgBase.optimize!(m::BaronMathProgModel)
    write_bar_file(m)
    run(`$baron_exec $(m.probfile)`)
end

end
