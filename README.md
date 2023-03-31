# BARON.jl

[![Build Status](https://github.com/jump-dev/BARON.jl/workflows/CI/badge.svg?branch=master)](https://github.com/jump-dev/BARON.jl/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/jump-dev/BARON.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/jump-dev/BARON.jl)

[BARON.jl](https://github.com/jump-dev/BARON.jl) is a wrapper for [BARON by The Optimization Firm](http://minlp.com/baron).

## Affiliation

This wrapper is maintained by the JuMP community and is not officially supported
by The Optimization Firm.

## License

`BARON.jl` is licensed under the [MIT License](https://github.com/jump-dev/BARON.jl/blob/master/LICENSE.md).

The underlying solver is a closed-source commercial product for which you must
purchase a license from [The Optimization Firm](http://minlp.com), although a
small trial version is available for free.

## Installation

First, download a copy of [the BARON solver](http://minlp.com/) and unpack the executable in a location of your choosing.

Once installed, set the `BARON_EXEC` environment variable pointing to the BARON executable (full path, including file name as it differs across platforms), and
run `Pkg.add("BARON")`. For example:

```julia
ENV["BARON_EXEC"] = "/path/to/baron.exe"
using Pkg
Pkg.add("BARON")
```
