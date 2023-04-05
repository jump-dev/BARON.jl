# BARON.jl

[![Build Status](https://github.com/jump-dev/BARON.jl/workflows/CI/badge.svg?branch=master)](https://github.com/jump-dev/BARON.jl/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/jump-dev/BARON.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/jump-dev/BARON.jl)

[BARON.jl](https://github.com/jump-dev/BARON.jl) is a wrapper for
[BARON by The Optimization Firm](http://minlp.com/baron).

## Affiliation

This wrapper is maintained by the JuMP community and is not officially supported
by The Optimization Firm.

## License

`BARON.jl` is licensed under the [MIT License](https://github.com/jump-dev/BARON.jl/blob/master/LICENSE.md).

The underlying solver is a closed-source commercial product for which you must
obtain a license from [The Optimization Firm](http://minlp.com), although a
small trial version is available for free.

## Installation

First, download a copy of [the BARON solver](http://minlp.com/) and unpack the
executable in a location of your choosing.

Once installed, set the `BARON_EXEC` environment variable pointing to the BARON
executable (full path, including file name as it differs across platforms), and
run `Pkg.add("BARON")`. For example:

```julia
ENV["BARON_EXEC"] = "/path/to/baron.exe"
using Pkg
Pkg.add("BARON")
```

## Use with JuMP

```julia
using JuMP, BARON
model = Model(BARON.Optimizer)
```

## MathOptInterface API

The BARON optimizer supports the following constraints and attributes.

List of supported objective functions:

 * [`MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}`](@ref)
 * [`MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Float64}}`](@ref)

List of supported variable types:

 * [`MOI.Reals`](@ref)

List of supported constraint types:

 * [`MOI.ScalarAffineFunction{Float64}`](@ref) in [`MOI.EqualTo{Float64}`](@ref)
 * [`MOI.ScalarAffineFunction{Float64}`](@ref) in [`MOI.GreaterThan{Float64}`](@ref)
 * [`MOI.ScalarAffineFunction{Float64}`](@ref) in [`MOI.Interval{Float64}`](@ref)
 * [`MOI.ScalarAffineFunction{Float64}`](@ref) in [`MOI.LessThan{Float64}`](@ref)
 * [`MOI.ScalarQuadraticFunction{Float64}`](@ref) in [`MOI.EqualTo{Float64}`](@ref)
 * [`MOI.ScalarQuadraticFunction{Float64}`](@ref) in [`MOI.GreaterThan{Float64}`](@ref)
 * [`MOI.ScalarQuadraticFunction{Float64}`](@ref) in [`MOI.Interval{Float64}`](@ref)
 * [`MOI.ScalarQuadraticFunction{Float64}`](@ref) in [`MOI.LessThan{Float64}`](@ref)
 * [`MOI.VariableIndex`](@ref) in [`MOI.EqualTo{Float64}`](@ref)
 * [`MOI.VariableIndex`](@ref) in [`MOI.GreaterThan{Float64}`](@ref)
 * [`MOI.VariableIndex`](@ref) in [`MOI.Integer`](@ref)
 * [`MOI.VariableIndex`](@ref) in [`MOI.Interval{Float64}`](@ref)
 * [`MOI.VariableIndex`](@ref) in [`MOI.LessThan{Float64}`](@ref)
 * [`MOI.VariableIndex`](@ref) in [`MOI.ZeroOne`](@ref)

List of supported model attributes:

 * [`MOI.NLPBlock()`](@ref)
 * [`MOI.ObjectiveSense()`](@ref)
