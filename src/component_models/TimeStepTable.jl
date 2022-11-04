"""
    TimeStepTable(vars)

`TimeStepTable` stores the values of the variables for each time step of a simulation. For example, it is used as the
structure in the status field of the [`ModelList`](@ref) type.

`TimeStepTable` implements the `Tables.jl` interface, so it can be used with any package that uses `Tables.jl` (like `DataFrames.jl`).

# Examples

```julia
# A leaf with several values for at least one of its variable will automatically use 
# TimeStepTable{Status} with the time steps:
leaf = ModelList(
    photosynthesis = Fvcb(),
    stomatal_conductance = Medlyn(0.03, 12.0),
    status=(Tₗ=[25.0, 26.0], PPFD=1000.0, Cₛ=400.0, Dₗ=1.0)
)

# The status of the leaf is a TimeStepTable:
status(leaf)


# Of course we can also create a TimeStepTable manually:
TimeStepTable(
    [
        Status(Tₗ=25.0, PPFD=1000.0, Cₛ=400.0, Dₗ=1.0),
        Status(Tₗ=26.0, PPFD=1200.0, Cₛ=400.0, Dₗ=1.2),
    ]
)
```
"""
struct TimeStepTable{T}
    names::NTuple{N,Symbol} where {N}
    ts::Vector{T}
end

TimeStepTable(ts::V) where {V<:Vector} = TimeStepTable(keys(ts[1]), ts)
# Case where we instantiate the table with one time step only, not given as a vector:
TimeStepTable(ts) = TimeStepTable(keys(ts), [ts])

struct TimeStepRow{T} <: Tables.AbstractRow
    row::Int
    source::TimeStepTable{T}
end

###### Tables.jl interface ######

Tables.istable(::Type{TimeStepTable{T}}) where {T} = true

# Keys should be the same between TimeStepTable so we only need the ones from the first timestep
Base.keys(ts::TimeStepTable) = getfield(ts, :names)
names(ts::TimeStepTable) = keys(ts)
# matrix(ts::TimeStepTable) = reduce(hcat, [[i...] for i in ts])'

function Tables.schema(m::TimeStepTable{T}) where {T<:Status}
    # This one is complicated because the types of the variables are hidden in the Status as RefValues:
    Tables.Schema(names(m), DataType[i.types[1] for i in T.parameters[2].parameters])
end

Tables.rowaccess(::Type{<:TimeStepTable}) = true

function Tables.rows(t::TimeStepTable)
    return [TimeStepRow(i, t) for i in 1:length(t)]
end

Base.eltype(::Type{TimeStepTable{T}}) where {T} = TimeStepRow{T}

function Base.length(A::TimeStepTable{T}) where {T}
    length(getfield(A, :ts))
end

Tables.columnnames(ts::TimeStepTable) = getfield(ts, :names)

# Iterate over all time-steps in a TimeStepTable object.
# Base.iterate(st::TimeStepTable{T}, i=1) where {T} = i > length(st) ? nothing : (getfield(st, :ts)[i], i + 1)
Base.iterate(t::TimeStepTable{T}, st=1) where {T} = st > length(t) ? nothing : (TimeStepRow(st, t), st + 1)
Base.size(t::TimeStepTable{T}, dim=1) where {T} = dim == 1 ? length(t) : length(getfield(t, :names))

function Tables.getcolumn(row::TimeStepRow, i::Int)
    return getfield(getfield(row, :source), :ts)[getfield(row, :row)][i]
end
Tables.getcolumn(row::TimeStepRow, nm::Symbol) =
    getfield(getfield(row, :source), :ts)[getfield(row, :row)][nm]
Tables.columnnames(row::TimeStepRow) = getfield(getfield(row, :source), :names)

function Base.setindex!(row::TimeStepRow, x, i::Int)
    st = getfield(getfield(row, :source), :ts)[getfield(row, :row)]
    setproperty!(st, i, x)
end

function Base.setproperty!(row::TimeStepRow, nm::Symbol, x)
    st = getfield(getfield(row, :source), :ts)[getfield(row, :row)]
    setproperty!(st, nm, x)
end

##### Indexing and setting:

# Indexing a TimeStepTable object with the dot syntax returns values of all time-steps for a
# variable (e.g. `status.A`).
function Base.getproperty(ts::TimeStepTable, key::Symbol)
    getproperty(Tables.columns(ts), key)
end

# Indexing with a Symbol extracts the variable (same as getproperty):
function Base.getindex(ts::TimeStepTable, index::Symbol)
    getproperty(ts, index)
end

# Setting the values of a variable in a TimeStepTable object is done by indexing the object
# and then providing the values for the variable (must match the length).
function Base.setproperty!(ts::TimeStepTable, s::Symbol, x)
    @assert length(x) == length(ts)
    for (i, row) in enumerate(Tables.rows(ts))
        setproperty!(row, s, x[i])
    end
end

@inline function Base.getindex(ts::TimeStepTable, row_ind::Integer, col_ind::Integer)
    rows = Tables.rows(ts)
    @boundscheck begin
        if col_ind < 1 || col_ind > length(keys(ts))
            throw(BoundsError(ts, (row_ind, col_ind)))
        end
        if row_ind < 1 || row_ind > length(ts)
            throw(BoundsError(ts, (row_ind, col_ind)))
        end
    end
    return @inbounds rows[row_ind][col_ind]
end

# Indexing a TimeStepTable in one dimension only gives the row (e.g. `ts[1] == ts[1,:]`)
@inline function Base.getindex(ts::TimeStepTable, i::Integer)
    rows = Tables.rows(ts)
    @boundscheck begin
        if i < 1 || i > length(ts)
            throw(BoundsError(ts, i))
        end
    end

    return @inbounds rows[i]
end

# Indexing a TimeStepTable with a colon (e.g. `ts[1,:]`) gives all values in column.
@inline function Base.getindex(ts::TimeStepTable, row_ind::Integer, ::Colon)
    return getindex(ts, row_ind)
end

# Indexing a TimeStepTable with a colon (e.g. `ts[:,1]`) gives all values in the row.
@inline function Base.getindex(ts::TimeStepTable, ::Colon, col_ind::Integer)
    return getproperty(Tables.columns(ts), col_ind)
end

# Pushing and appending to a TimeStepTable object:
function Base.push!(ts::TimeStepTable, x)
    push!(getfield(ts, :ts), x)
end

function Base.append!(ts::TimeStepTable, x)
    append!(getfield(ts, :ts), x)
end

# function Base.show(io::IO, t::TimeStepTable, limit=true)
#     length(t) == 0 && return

#     ts_all = getfield(t, :ts)
#     ts_print = []
#     for (i, ts) in enumerate(ts_all)
#         push!(ts_print, Term.highlight("Step $i: " * show_long_format_status(ts, true)))
#         limit && i >= displaysize(io)[1] && (push!(ts_print, "…"); break)
#     end

#     st_panel = Term.Panel(
#         join(ts_print, "\n"),
#         title="TimeStepTable",
#         style="red",
#         fit=false,
#     )

#     print(io, st_panel)
# end

function Base.show(io::IO, t::TimeStepTable)
    length(t) == 0 && return

    print(
        io,
        Term.RenderableText(
            "TimeStepTable ($(length(t)) x $(length(getfield(t,:names)))):";
            style="red bold"
        )
    )

    #! Note: There should be a better way to add the TimeStep as the first column. 
    # Here we transform the whole table into a matrix and pass the header manually... 
    # Also we manually replace last columns or rows by ellipsis if the table is too long or too wide.

    t_mat = Tables.matrix(t)
    col_names = [:Step, getfield(t, :names)...]
    ts_column = string.(1:size(t_mat, 1)) # TimeStep index column

    if get(io, :compact, false) || get(io, :limit, true)
        # We need the values in the matrix to be Strings to perform the truncation (and it is done afterwards too so...)
        typeof(t_mat) <: Matrix{String} || (t_mat = string.(t_mat))

        disp_size = displaysize(io)
        if size(t_mat, 1) * Term.Measures.height(t_mat[1, 1]) >= disp_size[1]
            t_mat = vcat(t_mat[1:disp_size[1], :], fill("...", (1, size(t_mat, 2))))
            # We need to add the TimeStep as the first column:
            ts_column = ts_column[1:disp_size[1]+1]
            ts_column[end] = "..."
        end

        # Header size (usually the widest):
        space_around_text = 8
        header_size = textwidth(join(col_names, join(fill(" ", space_around_text))))
        # Maximum column size:
        colsize = findmax(first, textwidth(join(t_mat[i, :], join(fill(" ", space_around_text)))) for i in axes(t_mat, 1))

        # Find the column that goes beyond the display:
        if header_size >= colsize[1]
            # The header is wider
            max_col_index = findfirst(x -> x > disp_size[2], cumsum(textwidth.(string.(col_names)) .+ space_around_text))
        else
            # One of the columns is wider
            max_col_index = findfirst(x -> x > disp_size[2], cumsum(textwidth.(t_mat[colsize[2], :]) .+ space_around_text))
        end

        if max_col_index !== nothing
            # We found a column that goes beyond the display, so we need to truncate starting from this one (also counting the extra ...)
            t_mat = t_mat[:, 1:max_col_index-2]
            # And we add an ellipsis to the last column for clarity:
            t_mat = hcat(t_mat, repeat(["..."], size(t_mat, 1)))
            # Add the ellipsis to the column names:
            col_names = [col_names[1:max_col_index-1]..., Symbol("...")]
            # remember that the first column is the TimeStep so we don't use max_col_index-2 here
        end
    end

    t_mat = Tables.table(hcat(ts_column, t_mat), header=col_names)

    st_panel = Term.Tables.Table(
        t_mat;
        box=:ROUNDED, style="red", compact=false
    )
    print(io, st_panel)
end


function Base.show(io::IO, row::TimeStepRow)
    limit = get(io, :limit, true)
    i = getfield(row, :row)
    st = getfield(getfield(row, :source), :ts)[i]
    ts_print = "Step $i: " * show_long_format_status(st, limit)

    st_panel = Term.Panel(
        ts_print,
        title="TimeStepRow",
        style="red",
        fit=false,
    )

    print(io, Term.highlight(st_panel))
end