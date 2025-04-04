# Copyright (c) 2015: Joey Huchette and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

depsfile = joinpath(dirname(@__FILE__), "path.jl")

if isfile(depsfile)
    rm(depsfile)
end

function write_depsfile(path)
    open(depsfile, "w") do io
        return write(io, """const baron_exec = $(repr(path))\n""")
    end
end

function ci_installation()
    @assert Sys.islinux()
    write("baronlice.txt", ENV["SECRET_BARON_LICENSE"])
    local_filename = joinpath(@__DIR__, "baron")
    download(ENV["SECRET_BARON_LIN64_JUMP_DEV"], local_filename)
    chmod(local_filename, 0o777)
    write_depsfile(local_filename)
    return
end

if haskey(ENV, "BARON_JL_SKIP_LIB_CHECK")
    # Skip!
elseif get(ENV, "JULIA_REGISTRYCI_AUTOMERGE", "false") == "true"
    write_depsfile("julia_registryci_automerge")
elseif get(ENV, "SECRET_BARON_LIN64_JUMP_DEV", "") != ""
    ci_installation()
elseif haskey(ENV, "BARON_EXEC")
    path = ENV["BARON_EXEC"]
    write_depsfile(path)
else
    error(
        """
        Unable to locate BARON executable.
        Make sure the solver has been separately downloaded from https://minlp.com/baron-downloads
        And that you properly set the `BARON_EXEC` environment variable.
        """,
    )
end
