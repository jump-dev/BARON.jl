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
    return
end

function ci_installation()
    zip_name, exe_name = if Sys.iswindows()
        "baron-win64", "baron.exe"
    elseif Sys.islinux()
        "baron-lin64", "baron"
    elseif Sys.isapple() && Sys.ARCH == :x86_64
        "baron-osx64", "baron"
    else
        "baron-osxarm64", "baron"
    end
    # Write the license file from ENV secret
    root = joinpath(dirname(@__DIR__), "test")
    write(joinpath(root, "baronlice.txt"), ENV["SECRET_BARON_LICENSE"])
    # The directory structure may change. If broken, double check by looking
    # at a manual dowload.
    local_filename = joinpath(@__DIR__, zip_name, exe_name)
    if isfile(local_filename)
        # If we've reloaded this in a CI job from a cache, the file may already
        # exist.
    else
        # Download BARON from pubic website. We do not automate this for users
        # because we do not have permission. We do have permission to test BARON
        # in CI.
        #
        # This URL may change at some point. If it does, find the latest at
        # https://minlp.com/baron-downloads
        url = "https://minlp-downloads.nyc3.cdn.digitaloceanspaces.com/xecs/baron/current/$zip_name.zip"
        zip_filename = joinpath(@__DIR__, "$zip_name.zip")
        download(url, zip_filename)
        run(`unzip $zip_filename`)
    end
    chmod(local_filename, 0o777)
    write_depsfile(local_filename)
    return
end

if haskey(ENV, "BARON_JL_SKIP_LIB_CHECK")
    # Skip!
elseif get(ENV, "JULIA_REGISTRYCI_AUTOMERGE", "false") == "true"
    write_depsfile("julia_registryci_automerge")
elseif get(ENV, "SECRET_BARON_LICENSE", "") != ""
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
