"""
    check_status_meteo(component,weather)
    check_status_meteo(status,weather)

Checks if a component status and the wheather have the same length, or if they can be
recycled (length 1).
"""
function check_status_wheather(
    st::T,
    weather::Weather
) where {T<:Vector{MutableNamedTuples.MutableNamedTuple}}

    length(st) > 1 && length(st) != length(weather.data) &&
        error("Component status should have the same number of time-steps than weather (or one only)")

    return true
end

function check_status_wheather(st::T, weather::Weather) where {T<:MutableNamedTuples.MutableNamedTuple}
    # This is authorized, the component is update at each time-step, but no intermediate saving!
    nothing
end


function check_status_wheather(component::T, weather::Weather) where {T<:AbstractComponentModel}
    check_status_wheather(status(component), weather)
end

# for several components as an array
function check_status_wheather(component::T, weather::Weather) where {T<:AbstractArray{<:AbstractComponentModel}}
    for i in component
        check_status_wheather(i, weather)
    end
end

# for several components as a Dict
function check_status_wheather(component::T, weather::Weather) where {T<:AbstractDict{N,<:AbstractComponentModel}} where {N}
    for (key, val) in component
        check_status_wheather(val, weather)
    end
end
