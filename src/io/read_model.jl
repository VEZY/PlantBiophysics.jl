# Reads a model file, which contains all parameters for simulating an object

"""
    read_model(file)

Read a model file. The model file holds the choice and the parameterization of the models.

# Arguments

- `file::String`: path to a model file

# Examples

```julia
models = read_model("path_to_a_model_file.yaml")
```
"""
function read_model(file)
    model = YAML.load_file(file; dicttype=OrderedDict{String,Any})

    !is_model(model) && error("model argument is not a model (e.g. as returned from `read_model()`)");
    group = model["Group"]
    types = collect(keys(model["Type"]))

    components = Dict{String,AbstractComponentModel}()

    for (i,j) in model["Type"]
        # i = "Leaf"
        # j = model["Type"][i]

        processes = OrderedDict{Symbol,Union{Missing,AbstractModel}}()
        for (k,l) in j
            # k = "Interception"
            # l = j[k]

            process = get_process(k)
            if !ismissing(process)
                # Checking if there are several models or just one given without the "use" keyword:
                if haskey(l,"model")
                    # Here we only have one model, and it is given as it is

                    #  Check if the user didn't mess up both approaches when writing:
                    haskey(l,"use") && error("Cannot use the name 'model' for a model name. ",
                    "Error happens in process `$k` of component type `$i`")

                    modelused = l
                elseif haskey(l,"use")
                    modelused = l[l["use"]]
                else
                    error("Error in parsing process `$k` of component type `$i`. Please check.")
                end

                model_process = get_model(pop!(modelused, "model"), process)
                model_process = instantiate(model_process,modelused)
                if !ismissing(model_process)
                    push!(processes, Symbol(process) => model_process)
                end
            end
        end

        sort!(processes)
        processes = (;processes...)

        # Get the component type based on the models used (*e.g.*, if photosynthetic, use `LeafModels`):
        componenttype = get_component_type(processes...)

        push!(components, i => componenttype(;processes...))
    end

    return components
end

"""
    get_component_type(processes)

Return the component type (the actual struct) given the processes passed as a named Tuple.
It is considered a `LeafModels` if it presents models for `photosynthesis` and
`stomatal_conductance`, and optionally for `interception` and `energy`.
"""
function get_component_type(::E,::I,::A,::Gs) where {E<:AbstractEnergyModel,
    I<:AbstractInterceptionModel,A<:AbstractAModel,Gs<:AbstractGsModel}

    return LeafModels
end

function get_component_type(::E,::A,::Gs) where {E<:AbstractEnergyModel,
    I<:AbstractInterceptionModel,A<:AbstractAModel,Gs<:AbstractGsModel}

    return LeafModels
end

function get_component_type(::I,::A,::Gs) where {I<:AbstractInterceptionModel,A<:AbstractAModel,Gs<:AbstractGsModel}

    return LeafModels
end

function get_component_type(::A,::Gs) where {A<:AbstractAModel,Gs<:AbstractGsModel}

    return LeafModels
end

"""
    get_component_type(processes)

Return the component type (the actual struct) given the processes passed as a named Tuple.

It is considered a `Component` if it presents models for `interception` and `energy` only.
"""
function get_component_type(::I,::E) where {I<:AbstractInterceptionModel,E<:AbstractEnergyModel}

    return Component
end

function get_component_type(::I) where I<:AbstractInterceptionModel

    return Component
end

# Default get_component_type if no component match the models inputed:
function get_component_type(processes...)
    error("Can't find any component type to hold models: $processes");
end


"""
    get_process(x)

Return the process type (the actual struct) given its name passed as a String.
"""
function get_process(x)
    x = lowercase(x)
    # All possible ways to write the processes in the input (compared to lowecase x):
    processes = Dict("interception" => "interception",
                        "energy" => "energy",
                        "photosynthesis" => "photosynthesis",
                        "stomatalconductance" => "stomatal_conductance",
                        "stomatal_conductance" => "stomatal_conductance")

    if !(haskey(processes,lowercase(x)))
        @warn "Process `$x` is not implemented yet. Did you make a typo?"
        return missing
    end

    return processes[x]
end

"""
    get_model(x)

Return the model (the actual struct) given its name passed as a String.
"""
function get_model(x,process)
    process = lowercase(process)
    if process == "photosynthesis"
        dict = Dict("farquharenbalance" => Fvcb, "fvcb" => Fvcb,
                    "fvcbiter" => FvcbIter, "ignore" => Ignore)
        # NB: dict keys all in lowercase because we transform x into lowercase too to avoid mismatches
    elseif process == "stomatalconductance" || process == "stomatal_conductance"
        dict = Dict("medlyn" => Medlyn)
    elseif process == "interception"
        dict = Dict("translucent" => Translucent, "ignore" => Ignore)
    elseif process == "energy"
        dict = Dict("monteith" => Monteith, "ignore" => Ignore)
    end

    x_lc = lowercase(x)

    !haskey(dict, x_lc) && error("Model type `$x` does not exist for process $process. ",
                                    "Available models are: $(keys(dict))");

    return dict[x_lc]
end


"""
    instantiate(x)

Instantiate a model given its parameter names, considering that parameter names can be
different compared to the model fields (used to insure compatibility with Archimed).
"""
function instantiate(model,param,correspondance,param_type)

    param_names = fieldnames(model)

    # For each parameter, we first search if there is the parameter named as in the fields of the input struct.
    # If yes, we add the key => value pair to param_model. If not, we try with a different name given by "correspondance".
    # If we still don't find it, we try to build the struct with default values and take those values. And if if we can't,
    # we return an error.
    param_model = Dict{Symbol,Any}()
    for i in param_names
        key = string(i)
        if haskey(param,key)
            # The parameter is found directly in param
            push!(param_model, i => convert(param_type[key],param[key]))
        elseif haskey(correspondance, i)
            # The parameter was not found in param, so we try using other names from correspondance
            push!(param_model, i => convert(param_type[key],param[correspondance[i]]))
        end
    end

    no_values = setdiff(collect(param_names),collect(keys(param_model)))
    if length(no_values) > 0
        @info "Using default values for parameters $no_values in model $model"  maxlog = 1
    end

    return model(;param_model...)
end

function instantiate(model::Union{Type{Fvcb},Type{FvcbIter}},param)
    correspondance = Dict(:Tᵣ => "tempCRef", :VcMaxRef => "vcMaxRef", :JMaxRef => "jMaxRef",
                        :RdRef => "rdRef", :θ => "theta")
    # Create a Dict holding the parameter type for each parameter
    param_type = Dict([string(i) => Float64 for i in fieldnames(model)]...)
    instantiate(model,param,correspondance,param_type)
end

function instantiate(model::Type{Monteith},param)
    correspondance = Dict(:ash => "aₛₕ", :asv => "aₛᵥ", :epsilon => "ε",:lambda => "ΔT")
    # Create a Dict holding the parameter type for each parameter
    param_type = Dict("aₛₕ" => Int, "aₛᵥ" => Int, "ε" => Float64,
                        "maxiter" => Int, "ΔT" => Float64)
    instantiate(model,param,correspondance,param_type)
end


function instantiate(model::Type{Medlyn},param)
    correspondance = Dict()
    param_type = Dict([string(i) => Float64 for i in fieldnames(model)]...)
    instantiate(model,param,correspondance,param_type)
end

function instantiate(model::Type{Translucent},param)

    if haskey(param,"optical_properties")
        isPAR = haskey(param["optical_properties"],"PAR")
        isNIR = haskey(param["optical_properties"],"NIR")

        if isPAR && isNIR
            param["optical_properties"] =
                instantiate(σ,param["optical_properties"],[],
                            Dict("PAR" => Float64,"NIR" => Float64))
        else
            missing_optic = ["PAR","NIR"][[!isPAR,!isNIR]]
            error("Missing Optical properties found in `$model` model for `$missing_optic`.")
        end
    else
        error("Optical properties not found in $model model. Please check file.")
    end

    correspondance = Dict()
    param_type = Dict("transparency" => Float64, "optical_properties" => OpticalProperties)

    instantiate(model,param,correspondance,param_type)
end


function instantiate(model::Type{Ignore},param)
    missing
end


"""
    is_model(model)

Check if a model object has the"Group" and "Type" keys as the first level of a Dict type
object. But the function is generic as long as the input struct has a `keys()` method.

# Examples

```julia
models = read_model("path_to_a_model_file.yaml")
is_model(models)
```
"""
function is_model(model)
    collect(keys(model)) == ["Group", "Type"]
end
