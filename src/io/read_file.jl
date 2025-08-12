"""
    read_file(file; column_names_start=1, data_start=column_names_start + 1, kwargs...)

Reads one or multiple CSV file(s) and returns a DataFrame.

# Arguments

- `file`: a string or a vector of strings containing the path to the file(s) to read.
- `column_names_start=1`: the row number to start reading column names from. Default is 1.
- `data_start=column_names_start+1`: the row number to start reading data from. Default is 2 (`column_names_start+1`).
- `kwargs...`: additional keyword arguments to pass to the CSV reader (*e.g.*, `decimal=','`).
"""
function read_file(file; column_names_start=1, data_start=column_names_start + 1, kwargs...)
    error_on_xlsx(file)
    if typeof(file) <: Vector{T} where {T<:AbstractString}
        df = CSV.read(file, DataFrame; header=column_names_start, skipto=data_start, source=:source, kwargs...)
    else
        df = CSV.read(file, DataFrame; header=column_names_start, skipto=data_start, kwargs...)
    end
end

"""
    error_on_xlsx(file)

Rises an error if the file is in XLSX format.
"""
function error_on_xlsx(file)
    # Check if the file extension is XLSX
    if splitext(basename(file))[2] == ".xlsx"
        error("The file is in XLSX format. Please convert it to CSV before using this function.")
    end
    return nothing
end