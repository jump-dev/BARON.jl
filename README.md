BARON.jl
========

The BARON.jl package provides an interface for using [BARON by The Optimization Firm](http://minlp.com/baron) from the [Julia language](http://julialang.org/). You cannot use BARON.jl without having purchased and installed a copy of BARON from [The Optimization Firm](http://minlp.com/). This package is available free of charge and in no way replaces or alters any functionality of The Optimization Firm's Baron product.

BARON.jl is a Julia interface for the BARON optimization software. BARON.jl is intended for use with the [MathProgBase](https://github.com/JuliaOpt/MathProgBase.jl) solver interface.

Setting up BARON and BARON.jl
--------------------------------------------------

1) Obtain a copy of [the BARON solver](http://minlp.com/). Licenses must be purchased, though a small trial version is available for free.

2) Unpack the executable in a location of your choosing.

3) Add the ``BARON_EXEC`` environment variable pointing to the BARON executable (full path, including file name as it differs across platforms).

4) Install the ``BARON.jl`` wrapper by running 
```
Pkg.add("BARON")
```
