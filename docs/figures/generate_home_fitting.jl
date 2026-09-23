module HomeFitting

using CairoMakie
using DataFrames
using PlantBiophysics
using PlantSimEngine

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const DEFAULT_OUTPUT_DIR = joinpath(ROOT, "docs", "src", "assets")
const SOURCE_FILE = joinpath(
    pkgdir(PlantBiophysics), "test", "inputs", "data", "P1F20129.csv",
)

"""
    fitting_response()

Reproduce the measured-Cᵢ fit from `docs/src/fitting/parameter_fitting.md`.
Read the bundled WALZ file, exclude its humidity and light curves, and fit
`Fvcb` at a reference temperature of 25 °C. Return the fitted parameters and
predictions for every retained CO₂-curve observation, ordered by measured Cᵢ.

Each prediction uses that observation's measured Tₗ, aPPFD, and Cᵢ. No new
conditions, interpolated measurements, or additional fitting data are created.
"""
function fitting_response()
    observations = read_walz(SOURCE_FILE; ntasks=1)
    observations.source_row = collect(1:nrow(observations))
    filter!(row -> row.curve ∉ ("Rh Curve", "ligth Curve"), observations)
    @assert nrow(observations) > 0 "The tutorial's fitting-data selection is empty."
    for variable in (:Tₗ, :aPPFD, :Cᵢ, :A)
        @assert all(isfinite, observations[!, variable]) "Non-finite fitting observations."
    end

    fitted = Evaluation.fit(Fvcb, observations; Tᵣ=25.0)
    @assert fitted.Tᵣ == 25.0 "The fitted reference temperature must be preserved."
    @assert all(isfinite, values(fitted)) "The fitted parameters must be finite."

    co2_curve = subset(observations, :curve => ByRow(==("CO2 Curve")))
    sort!(co2_curve, :Cᵢ)
    @assert nrow(co2_curve) > 1 "At least two CO₂ observations are needed for the curve."
    @assert length(unique(co2_curve.source_row)) == nrow(co2_curve)
    @assert issorted(co2_curve.Cᵢ)

    photosynthesis = FvcbRaw(; fitted...)
    predicted = map(eachrow(co2_curve)) do row
        scene = leaf_scene(
            photosynthesis;
            status=Status(Tₗ=row.Tₗ, aPPFD=row.aPPFD, Cᵢ=row.Cᵢ),
        )
        run!(scene)
        leaf = model_object(scene, :leaf)
        # FvcbRaw must keep the measured drivers paired with this prediction.
        @assert leaf.status.Tₗ == row.Tₗ
        @assert leaf.status.aPPFD == row.aPPFD
        @assert leaf.status.Cᵢ == row.Cᵢ
        @assert isfinite(leaf.status.A) "A fitted prediction is not finite."
        return leaf.status.A
    end

    comparison = select(
        co2_curve, :source_row, :Tₗ, :aPPFD, :Cᵢ, :A => :A_measured,
    )
    comparison.A_simulated = predicted
    @assert nrow(comparison) == count(==("CO2 Curve"), observations.curve)
    rmse = Evaluation.RMSE(comparison.A_measured, comparison.A_simulated)
    @assert isfinite(rmse)

    return (
        source=SOURCE_FILE,
        fitting_rows=nrow(observations),
        fitted=fitted,
        comparison=comparison,
        rmse=rmse,
    )
end

"""
    generate_home_fitting(; output_dir=DEFAULT_OUTPUT_DIR)

Write `home-fitting.svg` for the documentation homepage and return its path,
source file, fitted parameters, row counts, and assimilation RMSE. The observed
points and fitted line use the same measured Cᵢ coordinates as the fitting
tutorial; line segments only join the predictions at those observations.

This is agreement with data used for fitting, not an independent validation.
"""
function generate_home_fitting(; output_dir=DEFAULT_OUTPUT_DIR)
    response = fitting_response()
    comparison = response.comparison

    figure = Figure(
        size=(680, 420),
        fontsize=17,
        backgroundcolor=:white,
        figure_padding=(18, 22, 16, 18),
    )
    axis = Axis(
        figure[1, 1];
        xlabel="Intercellular CO₂, Cᵢ (µmol mol⁻¹)",
        ylabel="Net assimilation, A\n(µmol CO₂ m⁻² s⁻¹)",
        xlabelsize=18,
        ylabelsize=18,
        xticklabelsize=15,
        yticklabelsize=15,
        xgridcolor=(:grey70, 0.22),
        ygridcolor=(:grey70, 0.22),
        spinewidth=1,
        xautolimitmargin=(0.04, 0.05),
        yautolimitmargin=(0.08, 0.12),
    )
    hidespines!(axis, :t, :r)

    # Keep the observation coordinates: this is not a synthetic smooth curve.
    lines!(
        axis, comparison.Cᵢ, comparison.A_simulated;
        color="#156f64", linewidth=3, label="Fitted model",
    )
    scatter!(
        axis, comparison.Cᵢ, comparison.A_measured;
        color="#b46237", markersize=10,
        strokecolor=:white, strokewidth=1.2, label="Measured",
    )
    axislegend(
        axis;
        position=:rb,
        labelsize=15,
        framevisible=false,
        backgroundcolor=(:white, 0.9),
        patchsize=(27, 16),
        padding=(10, 10, 8, 8),
    )

    mkpath(output_dir)
    output = joinpath(output_dir, "home-fitting.svg")
    save(output, figure)
    @assert isfile(output) && filesize(output) > 0 "The fitting SVG was not written."

    return (
        output=output,
        source=response.source,
        fitting_rows=response.fitting_rows,
        curve_rows=nrow(comparison),
        fitted=response.fitted,
        rmse=response.rmse,
    )
end

end
