# Copyright (c) 2015: Joey Huchette and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

const Bounds{T} =
    Union{MOI.EqualTo{T},MOI.GreaterThan{T},MOI.LessThan{T},MOI.Interval{T}}

mutable struct Optimizer <: MOI.AbstractOptimizer
    inner::BaronModel
    nlp_block_data::Union{Nothing,MOI.NLPBlockData}
end

Optimizer(; options...) = Optimizer(BaronModel(; options...), nothing)

MOI.get(model::Optimizer, ::MOI.SolverName) = "BARON"

function MOI.is_empty(model::Optimizer)
    return BARON.is_empty(model.inner) && model.nlp_block_data === nothing
end

function MOI.empty!(model::Optimizer)
    for key in ("ProName", "TimName", "SumName", "ResName")
        if startswith(model.inner.options[key], model.inner.temp_dir_name)
            delete!(model.inner.options, key)
        end
    end
    model.inner = BaronModel(;
        ((Symbol(key), val) for (key, val) in model.inner.options)...,
    )
    model.nlp_block_data = nothing
    return
end

MOI.supports_incremental_interface(::Optimizer) = true

function MOI.copy_to(dest::Optimizer, src::MOI.ModelLike)
    return MOI.Utilities.default_copy_to(dest, src)
end

function MOI.optimize!(model::Optimizer)
    if !IS_SOLVER_SET
        error(
            "BARON.jl was not built correctly.\nSet the environment variable " *
            "`BARON_EXEC` and run `using Pkg; Pkg.build(\"BARON\")`.",
        )
    end
    write_bar_file(model.inner)
    if model.inner.print_input_file
        println("\nBARON input file: $(model.inner.problem_file_name)\n")
        println(read(model.inner.problem_file_name, String))
    end
    try
        run(`$baron_exec $(model.inner.problem_file_name)`)
    catch e
        error(
            """
            Failed to call BARON exec `$baron_exec`.

            Check the BARON log for details.

            The Julia error was:
            ```
            $e
            ```

            The `.bar` file was:
            ```
            $(read(model.inner.problem_file_name, String))
            ```
            """,
        )
    end
    return read_results(model.inner)
end

MOI.supports(::Optimizer, ::MOI.RawOptimizerAttribute) = true

function MOI.set(model::Optimizer, param::MOI.RawOptimizerAttribute, value)
    model.inner.options[param.name] = value
    return
end

function MOI.get(model::Optimizer, param::MOI.RawOptimizerAttribute)
    return get(model.inner.options, param.name, nothing)
end

# TimeLimitSec

MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true

function MOI.set(model::Optimizer, ::MOI.TimeLimitSec, val::Real)
    model.inner.options["MaxTime"] = convert(Float64, val)
    return
end

function MOI.set(model::Optimizer, ::MOI.TimeLimitSec, ::Nothing)
    delete!(model.inner.options, "MaxTime")
    return
end

function MOI.get(model::Optimizer, ::MOI.TimeLimitSec)
    return get(model.inner.options, "MaxTime", nothing)
end

# Silent

MOI.supports(::Optimizer, ::MOI.Silent) = true

function MOI.get(model::Optimizer, ::MOI.Silent)
    return get(model.inner.options, "prlevel", 1) == 0
end

function MOI.set(model::Optimizer, ::MOI.Silent, value::Bool)
    model.inner.options["prlevel"] = value ? 0 : 1
    return
end

struct PrintInputFile <: MOI.AbstractOptimizerAttribute end

function MOI.set(model::Optimizer, ::PrintInputFile, val::Bool)
    model.inner.print_input_file = val
    return
end

function MOI.get(model::Optimizer, ::PrintInputFile)
    return model.inner.print_input_file
end

const _LIST_OF_SUPPORTED_NONLINEAR_OPERATORS =
    [:+, :-, :*, :/, :^, :exp, :log, :<=, :>=, :(==)]

function MOI.get(::Optimizer, ::MOI.ListOfSupportedNonlinearOperators)
    return _LIST_OF_SUPPORTED_NONLINEAR_OPERATORS
end

include(joinpath("moi", "util.jl"))
include(joinpath("moi", "variables.jl"))
include(joinpath("moi", "constraints.jl"))
include(joinpath("moi", "objective.jl"))
include(joinpath("moi", "nlp.jl"))
include(joinpath("moi", "results.jl"))
