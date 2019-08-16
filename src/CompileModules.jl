module CompileModules

export compilecache, loadcache, ensure_compilecache

using Logging

function defaultcache(input::AbstractString)
    path = dirname(input)
    ispath(path) || error("Invalid path")

    name = join([split(basename(input), '.')[1:end-1]..., "ji"], '.')
    name == "ji" && (name = basename(input) * ".ji")

    joinpath(path, name)
end#function

# This is a lightly modified copy of compilecache from Base/loading.jl
function compilecache(input::AbstractString,
                      output::AbstractString=defaultcache(input))
    concrete_deps = copy(Base._concrete_dependencies)
    for (key, mod) in Base.loaded_modules
        if !(mod === Main || mod === Core || mod === Base)
            push!(concrete_deps, key => Base.module_build_id(mod))
        end
    end

    verbosity = isinteractive() ? Logging.Info : Logging.Debug
    if isfile(output)
        @logmsg verbosity "Recompiling cache file $output for $input"
    else
        @logmsg verbosity "Precompiling $input"
    end
    p = Base.create_expr_cache(input, output, concrete_deps, nothing)
    if success(p)
        # append checksum to the end of the .ji file:
        open(output, "a+") do f
            write(f, Base._crc32c(seekstart(f)))
        end
    elseif p.exitcode == 125
        throw(Base.PrecompilableError())
    else
        error("Failed to precompile $input to $output.")
    end
    output
end#function

loadcache(cache::AbstractString=defaultcache(PROGRAM_FILE)) =
    # TODO: test whether cache is stale
    Base._require_from_serialized(cache)

ensure_compilecache(input::AbstractString,
                    output::AbstractString=defaultcache(input)) =
    !isfile(output) && compilecache(input, output)

end#module
