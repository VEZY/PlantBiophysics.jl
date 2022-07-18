"""
    @gen_process_methods

This macro generate all standard methods for processes:

- The base method that calls the actual algorithms implemented using the process name
    suffixed by `_`, *e.g.* `photosynthesis_`.
- The method applying the computation over several objects (*e.g.* all leaves of a plant)
in an Array
- The same method over a Dict(-alike) of objects
- The method that applies the computation over several meteo time steps (called Weather) and
possibly several objects
- A method for calling the process without any meteo (*e.g.* for fitting)
- A method to apply the above over MTG nodes
- A non-mutating version of the function (make a copy before the call, and return the copy)

The macro returns two functions: the mutating one and the non-mutating one.
For example `energy_balance()` and `energy_balance!()` for the energy balance. And of course
the function that implements the computation is assumed to be `energy_balance!_()`.

# Examples

```julia
@macroexpand @gen_process_methods dummy_process
```
"""
macro gen_process_methods(f)

    non_mutating_f = f
    mutating_f = Symbol(string(f, "!"))
    f_ = Symbol(string(mutating_f, "_"))

    expr = quote

        function $(esc(f_))(object, meteo=nothing, constants=nothing)
            process_models = Dict(process => typeof(getfield(object, process)).name.wrapper for process in fieldnames(typeof(object)))
            pop!(process_models, :status) # status is not a model
            error(
                "No model was found for this combination of process simulation, component models and/or models:",
                "\nProcess simulation: ", $(String(non_mutating_f)),
                "\nComponent models: ", typeof(object).name.wrapper,
                "\nModels: ", join(["$(i.first) => $(i.second)" for i in process_models], ", ", " and ")
            )
        end

        # Base method that calls the actual algorithms:
        function $(esc(mutating_f))(object::AbstractComponentModel, meteo::AbstractAtmosphere, constants=Constants())
            !is_initialised(object) && error("Some variables must be initialized before simulation")

            $(esc(f_))(object, meteo, constants)
            return nothing
        end

        # Process method over several objects (e.g. all leaves of a plant) in an Array
        function $(esc(mutating_f))(object::O, meteo::AbstractAtmosphere, constants=Constants()) where {O<:AbstractArray{<:AbstractComponentModel}}
            for i in values(object)
                $(mutating_f)(i, meteo, constants)
            end
            return nothing
        end

        # Process method over several objects (e.g. all leaves of a plant) in a kind of Dict.
        function $(esc(mutating_f))(object::O, meteo::AbstractAtmosphere, constants=Constants()) where {O<:AbstractDict{N,<:AbstractComponentModel} where {N}}
            for (k, v) in object
                $(mutating_f)(v, meteo, constants)
            end
            return nothing
        end

        # Process method over several meteo time steps (called Weather) and possibly several components:
        function $(esc(mutating_f))(
            object::T,
            meteo::Weather,
            constants=Constants()
        ) where {T<:Union{AbstractArray{<:AbstractComponentModel},AbstractDict{N,<:AbstractComponentModel} where N}}

            # Check if the meteo data and the status have the same length (or length 1)
            check_status_wheather(object, meteo)

            # Each object:
            for obj in object
                # Computing for each time-step:
                for (i, meteo_i) in enumerate(meteo.data)
                    $(mutating_f)(copy(obj, obj[i]), meteo_i, constants)
                end
            end

        end

        # If we call weather with one component only:
        function $(esc(mutating_f))(object::AbstractComponentModel, meteo::Weather, constants=Constants())

            # Check if the meteo data and the status have the same length (or length 1)
            check_status_wheather(object, meteo)

            !is_initialised(object) && error("Some variables must be initialized before simulation")

            # Computing for each time-steps:
            for (i, meteo_i) in enumerate(meteo.data)
                $(esc(f_))(copy(object, object[i]), meteo_i, constants)
            end
        end

        # Method for calling the process without any meteo. In this case we need to check if
        # the status has one or several time-steps.
        function $(esc(mutating_f))(object::AbstractComponentModel, meteo::Nothing=nothing, constants=Constants())
            !is_initialised(object) && error("Some variables must be initialized before simulation (see info message for more details)")

            if typeof(status(object)) == MutableNamedTuples.MutableNamedTuple
                $(esc(f_))(object, meteo, constants)
            else
                # We have several time-steps here, we pass each time-step after another
                for i = eachindex(status(object))
                    $(esc(f_))(copy(object, object[i]), meteo, constants)
                end
            end
        end

        # Compatibility with MTG:
        function $(esc(mutating_f))(
            mtg::MultiScaleTreeGraph.Node,
            models::Dict{String,<:AbstractModel},
            meteo::AbstractAtmosphere,
            constants=Constants()
        )
            # Define the attribute name used for the models in the nodes
            attr_name = MultiScaleTreeGraph.cache_name("PlantBiophysics models")

            # Initialise the MTG nodes with the corresponding models:
            init_mtg_models!(mtg, models, attr_name=attr_name)

            MultiScaleTreeGraph.transform!(mtg, attr_name => (x -> $(mutating_f)(x, meteo, constants)), ignore_nothing=true)
        end

        # Compatibility with MTG + Weather:
        function $(esc(mutating_f))(
            mtg::MultiScaleTreeGraph.Node,
            models::Dict{String,<:AbstractModel},
            meteo::Weather,
            constants=Constants()
        )
            # Define the attribute name used for the models in the nodes
            attr_name = Symbol(MultiScaleTreeGraph.cache_name("PlantBiophysics models"))

            # Init the status for the meteo step only (with an AbstractAtmosphere)
            to_init = init_mtg_models!(mtg, models, 1, attr_name=attr_name)

            # Pre-allocate the node attributes based on the simulated variables and number of steps:
            nsteps = length(meteo)

            MultiScaleTreeGraph.traverse!(
                mtg,
                (x -> pre_allocate_attr!(x, nsteps; attr_name=attr_name)),
            )

            # Computing for each time-steps:
            for (i, meteo_i) in enumerate(meteo.data)
                # Then update the initialisation each time-step.
                update_mtg_models!(mtg, i, to_init, attr_name)

                MultiScaleTreeGraph.transform!(
                    mtg,
                    attr_name => (x -> $(mutating_f)(x, meteo_i, constants)),
                    (node) -> pull_status_step!(node, i, attr_name=attr_name),
                    ignore_nothing=true
                )
            end
        end

        # Non-mutating version (make a copy before the call, and return the copy):
        function $(esc(non_mutating_f))(
            object::O,
            meteo::Union{Nothing,AbstractAtmosphere,Weather}=nothing,
            constants=Constants()
        ) where {
            O<:Union{
                AbstractComponentModel,
                AbstractArray{<:AbstractComponentModel},
                AbstractDict{N,<:AbstractComponentModel} where N}
        }
            object_tmp = copy(object)
            $(esc(mutating_f))(object_tmp, meteo, constants)
            return object_tmp
        end
    end
end
