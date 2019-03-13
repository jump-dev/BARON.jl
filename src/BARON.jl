__precompile__()

module BARON

if haskey(ENV, "BARON_EXEC")
    const baron_exec = ENV["BARON_EXEC"]
else
    @warn("Unable to locate BARON executable. Make sure the solver has been separately downloaded, and that you properly set the BARON_EXEC environment variable.")
end

mutable struct VariableInfo
    lower_bound::Float64
    upper_bound::Float64
    category::Symbol
    start::Union{Nothing, Float64}
    name::Union{Nothing, String}
end

mutable struct ConstraintInfo
    expression::Expr
    lower_bound::Float64
    upper_bound::Float64
    name::Union{Nothing, String}
end

mutable struct ObjectiveInfo
    expression::Expr
    sense::Symbol
end

@enum BaronStatus begin
    NORMAL_COMPLETION
    INFEASIBLE
    UNBOUNDED
    NODE_LIMIT
    BAR_ITERATION_LIMIT
    CPU_TIME_LIMIT
    TIME_LIMIT
    NUMERICAL_SENSITIVITY
    INVALID_VARIABLE_BOUNDS
    USER_INTERRUPTION
    ACCESS_VIOLATION
end

mutable struct SolutionStatus
    feasible_point::Union{Nothing, Vector{Float64}}
    objective_value::Float64
    dual_bound::Float64
    wall_time::Float64
    status::BaronStatus

    SolutionStatus() = new(nothing)
end

mutable struct BaronModel
    options::Dict{Symbol, Any}

    variable_info::Vector{VariableInfo}
    constraint_info::Vector{ConstraintInfo}
    objective_info::ObjectiveInfo

    temp_dir_name::String
    problem_file_name::String
    summary_file_name::String
    result_file_name::String

    solution_info::Union{Nothing, SolutionStatus}

    function BaronModel(;kwargs...)
        options = Dict{Symbol, Any}(key=>val for (key,val) in kwargs)
	model = new()
	model.options = options
	model.variable_info = VariableInfo[]
	model.constraint_info = ConstraintInfo[]
	temp_dir = mktempdir()
	model.temp_dir_name = temp_dir
        model.problem_file_name = get!(options, :TimName, joinpath(temp_dir, "tim.lst"))
        model.summary_file_name = get!(options, :SumName, joinpath(temp_dir, "sum.lst"))
        model.result_file_name = get!(options, :ResName, joinpath(temp_dir, "res.lst"))
	return model
    end
end

include("util.jl")
include("MPB_wrapper.jl")
include("MOI_wrapper.jl")

end  # module
