BARON.jl
========

| **Build Status** | **Social** |
|:----------------:|:----------:|
| [![Build Status][build-img]][build-url] [![Codecov branch][codecov-img]][codecov-url] | [![Gitter][gitter-img]][gitter-url] [<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/a/af/Discourse_logo.png/799px-Discourse_logo.png" width="64">][discourse-url] |


[build-img]: https://github.com/jump-dev/BARON.jl/workflows/CI/badge.svg?branch=master
[build-url]: https://github.com/jump-dev/BARON.jl/actions?query=workflow%3ACI
[codecov-img]: http://codecov.io/github/jump-dev/BARON.jl/coverage.svg?branch=master
[codecov-url]: http://codecov.io/github/jump-dev/BARON.jl?branch=master

[gitter-url]: https://gitter.im/JuliaOpt/JuMP-dev?utm_source=share-link&utm_medium=link&utm_campaign=share-link
[gitter-img]: https://badges.gitter.im/JuliaOpt/JuMP-dev.svg
[discourse-url]: https://discourse.julialang.org/c/domain/opt

The BARON.jl package provides an interface for using [BARON by The Optimization Firm](http://minlp.com/baron) from the [Julia language](http://julialang.org/). You cannot use BARON.jl without having purchased and installed a copy of BARON from [The Optimization Firm](http://minlp.com/). This package is available free of charge and in no way replaces or alters any functionality of The Optimization Firm's Baron product.

BARON.jl is a Julia interface for the BARON optimization software. BARON.jl is intended for use with the [MathOptInterface](https://github.com/jump-dev/MathOptInterface.jl) solver interface.

Setting up BARON and BARON.jl
--------------------------------------------------

1) Obtain a copy of [the BARON solver](http://minlp.com/). Licenses must be purchased, though a small trial version is available for free.

2) Unpack the executable in a location of your choosing.

3) Add the ``BARON_EXEC`` environment variable pointing to the BARON executable (full path, including file name as it differs across platforms).

4) Install the ``BARON.jl`` wrapper by running
```
using Pkg
Pkg.add("BARON")
```
