if haskey(ENV, "BARON_EXEC")
    path = ENV["BARON_EXEC"]
else
    error("Unable to locate BARON executable. Make sure the solver has been separately downloaded, and that you properly set the BARON_EXEC environment variable.")
end

open(joinpath(@__DIR__, "path.jl"), "w") do io
    write(io, """const baron_exec = "$path"\n""")
end
