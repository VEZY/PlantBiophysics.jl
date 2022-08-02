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
    f_ = Symbol(string(mutating_f, "_")) # The actual function implementing the process

    expr = quote

        function $(esc(f_))(mod_type, models, status, meteo=nothing, constants=nothing)
            process_models = Dict(process => typeof(getfield(models, process)).name.wrapper for process in keys(models))
            error(
                "No model was found for this combination of processes:",
                "\nProcess simulation: ", $(String(non_mutating_f)),
                "\nModels: ", join(["$(i.first) => $(i.second)" for i in process_models], ", ", " and ")
            )
        end

        # Base method that calls the actual algorithms:
        function $(esc(mutating_f))(object::ModelList{T,Status}, meteo::AbstractAtmosphere, constants=Constants()) where {T}
            !is_initialized(object) && error("Some variables must be initialized before simulation")

            $(esc(f_))(object.models.$(f), object.models, object.status, meteo, constants)
            return nothing
        end

        # Method for a status with several TimeSteps but one meteo only:
        function $(esc(mutating_f))(object::ModelList{T,TimeSteps}, meteo::AbstractAtmosphere, constants=Constants()) where {T}
            !is_initialized(object) && error("Some variables must be initialized before simulation")

            for i in status(object)
                $(esc(f_))(object.models.$(f), object.models, i, meteo, constants)
            end

            return nothing
        end



        # Process method over several objects (e.g. all leaves of a plant) in an Array
        function $(esc(mutating_f))(object::O, meteo::AbstractAtmosphere, constants=Constants()) where {O<:AbstractArray}
            for i in values(object)
                $(mutating_f)(i, meteo, constants)
            end
            return nothing
        end

        # Process method over several objects (e.g. all leaves of a plant) in a kind of Dict.
        function $(esc(mutating_f))(object::O, meteo::AbstractAtmosphere, constants=Constants()) where {O<:AbstractDict}
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
        ) where {T<:Union{AbstractArray,AbstractDict}}

            # Check if the meteo data and the status have the same length (or length 1)
            check_status_wheather(object, meteo)

            # Each object:
            for obj in object
                # Computing for each time-step:
                for (i, meteo_i) in enumerate(meteo.data)
                    $(esc(f_))(obj.models.$(f), obj.models, obj[i], meteo_i, constants)
                end
            end

        end

        # If we call weather with one component only:
        function $(esc(mutating_f))(object::T, meteo::Weather, constants=Constants()) where {T<:ModelList}

            # Check if the meteo data and the status have the same length (or length 1)
            check_status_wheather(object, meteo)

            !is_initialized(object) && error("Some variables must be initialized before simulation")

            # Computing for each time-steps:
            for (i, meteo_i) in enumerate(meteo.data)
                $(esc(f_))(object.models.$(f), object.models, object.status[i], meteo_i, constants)
            end
        end

        # Method for calling the process without any meteo. In this case we need to check if
        # the status has one or several time-steps.
        function $(esc(mutating_f))(object, meteo::Nothing=nothing, constants=Constants())
            !is_initialized(object) && error("Some variables must be initialized before simulation (see info message for more details)")

            if isa(status(object), PlantBiophysics.Status)
                $(esc(f_))(object.models.$(f), object.models, object.status, meteo, constants)
            else
                # We have several time-steps here, we pass each time-step after another
                for i in status(object)
                    $(esc(f_))(object.models.$(f), object.models, i, meteo, constants)
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

            # initialize the MTG nodes with the corresponding models:
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
            #! Here we use only one time-step for the status whatever the number of timesteps
            #! to simulate. Then we use this status for all the meteo steps (we re-initialize
            #! its values at each step). We do this to not replicate much data, but it is not
            #! the best way to do it because we don't use the nice methods from above that
            #! control the simulations for meteo / status timesteps. What we could do instead
            #! is to have a TimeSteps status for several timesteps, and then use pointers to
            #! the values in the node attributes. This we would avoid to replicate the data
            #! and we could use the fancy methods from above.

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
                    attr_name => (x -> Symbol($(esc(f))) in keys(x.models) && $(mutating_f)(x, meteo_i, constants)),
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
        ) where {O<:Union{ModelList,AbstractArray,AbstractDict}}
            object_tmp = copy(object)
            $(esc(mutating_f))(object_tmp, meteo, constants)
            return object_tmp
        end
    end
end
