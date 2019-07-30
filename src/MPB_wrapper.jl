import MathProgBase
import MathProgBase.SolverInterface

export BaronSolver
struct BaronSolver <: MathProgBase.AbstractMathProgSolver
    options
end

BaronSolver(;kwargs...) = BaronSolver(kwargs)

mutable struct BaronMathProgModel <: MathProgBase.AbstractNonlinearModel
    inner::BaronModel
end

MathProgBase.NonlinearModel(s::BaronSolver) = BaronMathProgModel(;s.options...)
MathProgBase.LinearQuadraticModel(s::BaronSolver) = MathProgBase.NonlinearToLPQPBridge(MathProgBase.NonlinearModel(s))

function MathProgBase.loadproblem!(mpb_model::BaronMathProgModel,
    nvar, ncon, xˡ, xᵘ, gˡ, gᵘ, sense,
    d::MathProgBase.AbstractNLPEvaluator)

    model = mpb_model.inner
    MathProgBase.initialize(d, [:ExprGraph])

    @assert nvar == length(xˡ) == length(xᵘ)
    for i in 1:nvar
        push!(model.variable_info, VariableInfo(xˡ[i], xᵘ[i], :Cont, "x$i"))
    end

    @assert ncon == length(gˡ) == length(gᵘ)
    for i in 1:ncon
    	constr_expr = verify_support(MathProgBase.constr_expr(d, c))
        push!(model.constraint_info, ConstraintInfo(constr_expr, gˡ[i], gᵘ[i], "e$i"))
    end

    m.objective_info = ObjectiveInfo(verify_support(MathProgBase.obj_expr(d)), sense)

    m.probfile = joinpath(m.temp_dir, "baron_problem.bar")
    m.sumfile  = joinpath(m.temp_dir, "sum.lst")
    m.resfile  = joinpath(m.temp_dir, "res.lst")
    return m
end

function MathProgBase.setvartype!(m::BaronMathProgModel, cat::Vector{Symbol})
    @assert length(cat) == length(m.inner.variable_info)
    for i in 1:length(cat)
        var_cat = cat[i]
        @assert var_cat in (:Cont, :Bin, :Int)
        m.inner.variable_info[i].category = var_cat
    end
    return
end

function MathProgBase.setwarmstart!(m::BaronMathProgModel, v::Vector{Float64})
    @assert length(v) == length(m.inner.variable_info)
    for i in 1:length(v)
        m.inner.variable_info[i].start = v[i]
    end
    return
end

function MathProgBase.optimize!(mpb_model::BaronMathProgModel)
    write_bar_file(m.inner)
    run(`$baron_exec $(m.inner.prob_file)`)

    read_results(m.inner)
end

function MathProgBase.status(m::BaronMathProgModel)
    status = m.solution_info.status
    if status == NORMAL_COMPLETION
    	return :Optimal
    elseif status == INFEASIBLE
        return :Infeasible
    elseif status == UNBOUNDED
        return :Unbounded
    elseif status in (CPU_TIME_LIMIT, TIME_LIMIT, USER_INTERRUPTION)
        return :UserLimit
    else
        return :Error
    end
end

MathProgBase.numvar(m::BaronMathProgModel) = length(m.inner.variable_info)
MathProgBase.getsolution(m::BaronMathProgModel) = m.inner.solution_info.feasible_point
MathProgBase.getobjval(m::BaronMathProgModel) = m.inner.solution_info.objective_value
MathProgBase.getobjbound(m::BaronMathProgModel) = m.inner.solution_info.dual_bound
MathProgBase.getsolvetime(m::BaronMathProgModel) = m.inner.solution_info.wall_time

