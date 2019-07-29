__precompile__()

module BARON

if haskey(ENV, "BARON_EXEC")
    const baron_exec = ENV["BARON_EXEC"]
else
    @warn("Unable to locate BARON executable. Make sure the solver has been separately downloaded, and that you properly set the BARON_EXEC environment variable.")
end

mutable struct VariableInfo
    lower_bound::Union{Float64, Nothing}
    upper_bound::Union{Float64, Nothing}
    category::Symbol
    start::Union{Float64, Nothing}
    name::Union{String, Nothing}
end
VariableInfo() = VariableInfo(nothing, nothing, :Cont, nothing, nothing)

mutable struct ConstraintInfo
    expression::Expr
    lower_bound::Union{Float64, Nothing}
    upper_bound::Union{Float64, Nothing}
    name::Union{String, Nothing}
end

function ConstraintInfo()
    ConstraintInfo(:(), nothing, nothing, nothing)
end

mutable struct ObjectiveInfo
    expression::Union{Expr, Number}
    sense::Symbol
end
ObjectiveInfo() = ObjectiveInfo(0, :Feasibility)

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
end

@enum BaronModelStatus begin
    OPTIMAL = 1
    INFEASIBLE = 2
    UNBOUNDED = 3
    INTERMEDIATE_FEASIBLE = 4
    UNKNOWN = 5
end

mutable struct SolutionStatus
    feasible_point::Union{Nothing, Vector{Float64}}
    objective_value::Float64
    dual_bound::Float64
    wall_time::Float64
    solver_status::BaronSolverStatus
    model_status::BaronModelStatus

    SolutionStatus() = new(nothing)
end

mutable struct BaronModel
    options::Dict{Symbol, Any}

    variable_info::Vector{VariableInfo}
    constraint_info::Vector{ConstraintInfo}
    objective_info::ObjectiveInfo

    temp_dir_name::String
    problem_file_name::String
    times_file_name::String
    summary_file_name::String
    result_file_name::String

    solution_info::Union{Nothing, SolutionStatus}

    function BaronModel(; kwargs...)
        options = Dict{Symbol, Any}(key => val for (key,val) in kwargs)
        model = new()
        model.options = options
        model.variable_info = VariableInfo[]
        model.constraint_info = ConstraintInfo[]
        model.objective_info = ObjectiveInfo()
        temp_dir = mktempdir()
        model.temp_dir_name = temp_dir
        model.problem_file_name = get!(options, :ProName, joinpath(temp_dir, "baron_problem.bar"))
        model.times_file_name = get!(options, :TimName, joinpath(temp_dir, "tim.lst"))
        model.summary_file_name = get!(options, :SumName, joinpath(temp_dir, "sum.lst"))
        model.result_file_name = get!(options, :ResName, joinpath(temp_dir, "res.lst"))
        model.solution_info = nothing
        return model
    end
end

include("util.jl")
include("MPB_wrapper.jl")
include("MOI_wrapper.jl")

end  # module
