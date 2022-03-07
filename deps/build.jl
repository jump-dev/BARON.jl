depsfile = joinpath(dirname(@__FILE__),"path.jl")

if isfile(depsfile)
    rm(depsfile)
end

function write_depsfile(path)
    open(depsfile, "w") do io
        write(io, """const baron_exec = $(repr(path))\n""")
    end
end

function ci_installation()
    files = if Sys.islinux()
    [
        (ENV["SECRET_BARON_LIN64_JUMP_DEV"], "baron")
        (ENV["SECRET_BARON_LIC_JUMP_DEV"], "baronlice.txt")
    ]
    end
    for (url, file) in files
        local_filename = joinpath(@__DIR__, file)
        download(url, local_filename)
        chmod(local_filename, 0o777)
        if file == "baron"
            write_depsfile(local_filename)
        end
    end
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
"""
)
end
