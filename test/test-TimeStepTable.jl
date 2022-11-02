@testset "Testing TimeStepTable" begin
    vars = Status(Rₛ=13.747, sky_fraction=1.0, d=0.03, PPFD=1500)
    ts = TimeStepTable([vars, vars])

    @test Tables.istable(typeof(ts))

    ts_rows = Tables.rows(ts)
    @test length(ts_rows) == length(ts)

    @test Tables.rowaccess(typeof(ts))
    # test that it defines column access
    ts_first = first(ts)
    @test eltype(ts) == typeof(ts_first)
    # now we can test our `Tables.AbstractRow` interface methods on our MatrixRow
    @test ts_first.Rₛ == 13.747
    @test Tables.getcolumn(ts_first, :Rₛ) == 13.747
    @test Tables.getcolumn(ts_first, 1) == 13.747
    @test keys(ts) == propertynames(ts_first) == (:Rₛ, :sky_fraction, :d, :PPFD)

    # Get column value using getcolumn:
    @test Tables.getcolumn(ts_rows[1], 1) == vars[1]
    @test Tables.getcolumn(ts_rows[1], :Rₛ) == vars.Rₛ

    # Get column value using indexing and/or the dot syntax:
    @test ts_rows[1].Rₛ == vars.Rₛ
    @test ts_rows[1][2] == vars[2]
    @test ts_rows[1][:Rₛ] == vars[1]

    # Get column values for all rows at once:
    cols = Tables.columns(ts)
    @test ts.Rₛ == cols.Rₛ
    @test ts[1, 1] == cols.Rₛ[1]

    # Indexing as a Matrix:
    @test ts[1, :] == ts_first
    @test ts[:, 1] == cols.Rₛ

    # Get column names:
    @test Tables.columnnames(ts) == keys(vars)

    # Get column names for a single row:
    @test Tables.columnnames(ts_rows[1]) == keys(vars)

    # setting the column value using indexing and/or the dot syntax:
    ts_rows[1].Rₛ = 12.2
    @test ts_rows[1].Rₛ == 12.2

    ts_rows[1][2] = 0.8
    @test ts_rows[1][2] == 0.8

    # Setting all values in a column row by row:
    for row in Tables.rows(ts)
        row.Rₛ = 4.0
    end
    @test ts.Rₛ == [4.0, 4.0]

    # Setting all values in a column at once:
    ts.Rₛ = [5.0, 5.0]
    @test ts.Rₛ == [5.0, 5.0]

    # Testing transforming into a DataFrame:
    df = DataFrame(ts)

    @test size(df) == (2, 4)
    @test df.Rₛ == [5.0, 5.0]
    @test df.sky_fraction == [0.8, 0.8]
    @test names(df) == [string.(keys(vars))...]
end