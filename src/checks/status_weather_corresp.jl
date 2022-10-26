"""
    check_status_meteo(component,weather)
    check_status_meteo(status,weather)

Checks if a component status and the weather have the same length, or if they can be
recycled (length 1).
"""
function check_status_wheather(
    st::T,
    weather::Weather
) where {T<:TimeStepTable}

    length(st) > 1 && length(st) != length(weather.data) &&
        error("Component status should have the same number of time-steps than weather (or one only)")

    return nothing
end

# A Status (one time-step) is always authorized with a Weather (it is recycled).
# The status is updated at each time-step, but no intermediate saving though!
function check_status_wheather(
    st::T,
    weather::Weather
) where {T<:Status}
    return nothing
end

function check_status_wheather(component::T, w) where {T<:ModelList}
    check_status_wheather(status(component), w)
end

# for several components as an array
function check_status_wheather(component::T, weather::Weather) where {T<:AbstractArray{<:ModelList}}
    for i in component
        check_status_wheather(i, weather)
    end
end

# for several components as a Dict
function check_status_wheather(component::T, weather::Weather) where {T<:AbstractDict{N,<:ModelList}} where {N}
    for (key, val) in component
        check_status_wheather(val, weather)
    end
end
