# Copyright (c) 2015: Joey Huchette and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module BARON

import MathOptInterface as MOI

const IS_SOLVER_SET = try
    include(joinpath(@__DIR__, "..", "deps", "path.jl"))
    true
catch
    @warn(
        """BARON.jl was not built correctly.
           Set the environment variable `BARON_EXEC` and run `using Pkg; Pkg.build("BARON")`."""
    )
    false
end

mutable struct VariableInfo
    lower_bound::Union{Float64,Nothing}
    upper_bound::Union{Float64,Nothing}
    category::Symbol
    start::Union{Float64,Nothing}

    VariableInfo() = new(nothing, nothing, :Cont, nothing)
end


mutable struct ConstraintInfo
    expression::Expr
    lower_bound::Union{Float64,Nothing}
    upper_bound::Union{Float64,Nothing}
end

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

mutable struct SolutionStatus
    feasible_point::Union{Nothing,Vector{Float64}}
    objective_value::Float64
    dual_bound::Float64
    wall_time::Float64
    solver_status::BaronSolverStatus
    model_status::BaronModelStatus

    SolutionStatus() = new(nothing)
end

mutable struct BaronModel
    options::Dict{String,Any}

    variable_info::Vector{VariableInfo}
    constraint_info::Vector{ConstraintInfo}
    objective_sense::Symbol
    objective_expr::Union{Nothing,Real,Expr}

    temp_dir_name::String
    problem_file_name::String
    times_file_name::String
    summary_file_name::String
    result_file_name::String

    solution_info::Union{Nothing,SolutionStatus}

    print_input_file::Bool

    function BaronModel(; kwargs...)
        options = Dict{String,Any}(string(key) => val for (key, val) in kwargs)
        model = new()
        model.options = options
        model.variable_info = VariableInfo[]
        model.constraint_info = ConstraintInfo[]
        model.objective_sense = :Feasibility
        model.objective_expr = nothing
        temp_dir = mktempdir()
        model.temp_dir_name = temp_dir
        model.problem_file_name =
            get!(options, "ProName", joinpath(temp_dir, "baron_problem.bar"))
        model.times_file_name =
            get!(options, "TimName", joinpath(temp_dir, "tim.lst"))
        model.summary_file_name =
            get!(options, "SumName", joinpath(temp_dir, "sum.lst"))
        model.result_file_name =
            get!(options, "ResName", joinpath(temp_dir, "res.lst"))
        model.solution_info = nothing
        model.print_input_file = false
        return model
    end
end

include("util.jl")
include("MOI_wrapper.jl")

end  # module
