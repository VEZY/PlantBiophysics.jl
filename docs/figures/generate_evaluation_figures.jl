# PlantBiophysics-only adaptations of the three evaluation figures from
# PlantBiophysics-paper main (protocol commit 8853005a2910fb4315a294f6c5099bafddc27a8e).
# The simulation scenarios are shared with the numerical regression tests.
module EvaluationFigures

using CairoMakie
using CSV
using DataFrames
using Dates
using MonteCarloMeasurements
using Random
using Statistics
using PlantBiophysics
using PlantBiophysics.PlantMeteo
import PlantBiophysics.PlantSimEngine
using PlantBiophysics.PlantSimEngine: Status, model_objects, run!

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const OUTPUT_DIR = joinpath(ROOT, "docs", "src", "assets", "evaluation")

include(joinpath(ROOT, "test", "evaluation", "scenarios.jl"))

const COLOR_GLOBAL = "#F47C7C"
const COLOR_OBSERVED = "#FD6467"
const COLOR_SIMULATED = "#43658B"
const COLOR_LE = "#3D405B"
const COLOR_H = "#E07A5F"
const COLOR_RN = "#81B29A"
const COLOR_GRID = (:grey70, 0.32)

central_value(value::AbstractParticles) = pmean(value)
central_value(value) = value

function figure_metrics(observed, simulated)
    residuals = simulated .- observed
    rmse = sqrt(sum(abs2, residuals) / length(observed))
    observed_range = maximum(observed) - minimum(observed)
    ef = 1 - sum(abs2, residuals) / sum(abs2, observed .- mean(observed))
    return (
        NRMSE=central_value(rmse / observed_range),
        EF=central_value(ef),
    )
end

function metric_label(observed, simulated)
    metrics = figure_metrics(observed, simulated)
    nrmse = round(100 * metrics.NRMSE; digits=1)
    ef = round(metrics.EF; digits=2)
    return "NRMSE = $(nrmse)%    EF = $(ef)"
end

function add_metric_label!(axis, observed, simulated)
    text!(
        axis,
        0.04,
        0.96;
        text=metric_label(observed, simulated),
        space=:relative,
        align=(:left, :top),
        fontsize=12,
        color=:grey25,
    )
    return nothing
end

function style_axis!(axis)
    axis.xgridcolor = COLOR_GRID
    axis.ygridcolor = COLOR_GRID
    axis.xgridwidth = 0.8
    axis.ygridwidth = 0.8
    axis.spinewidth = 1.0
    return axis
end

function global_figure(scenario)
    figure = Figure(size=(920, 850), fontsize=14, backgroundcolor=:white)
    Label(
        figure[0, 1:2],
        "Global evaluation — PlantBiophysics only";
        fontsize=22,
        font=:bold,
        tellwidth=false,
    )

    specifications = (
        (
            variable=:A,
            title="a) Net CO₂ assimilation, A",
            unit="μmol CO₂ m⁻² s⁻¹",
            limits=(-10.0, 50.0),
        ),
        (
            variable=:E,
            title="b) Transpiration, E",
            unit="mmol H₂O m⁻² s⁻¹",
            limits=(-0.5, 10.0),
        ),
        (
            variable=:Gs,
            title="c) CO₂ stomatal conductance, Gₛ",
            unit="mol CO₂ m⁻² s⁻¹",
            limits=(-0.05, 0.85),
        ),
        (
            variable=:Tl,
            title="d) Leaf temperature, Tₗ",
            unit="°C",
            limits=(10.0, 36.0),
        ),
    )

    for (index, specification) in enumerate(specifications)
        row = index <= 2 ? 1 : 2
        column = isodd(index) ? 1 : 2
        axis = Axis(
            figure[row, column];
            title="$(specification.title)\n$(specification.unit)",
            titlealign=:left,
            aspect=1,
        )
        style_axis!(axis)

        lower, upper = specification.limits
        lines!(axis, [lower, upper], [lower, upper]; color=(:grey45, 0.65), linewidth=3)

        observed = getproperty(scenario.observed, specification.variable)
        simulated = getproperty(scenario.simulated, specification.variable)
        scatter!(
            axis,
            observed,
            simulated;
            color=(COLOR_GLOBAL, 0.35),
            markersize=5.5,
            strokewidth=0,
        )
        xlims!(axis, lower, upper)
        ylims!(axis, lower, upper)
        add_metric_label!(axis, observed, simulated)
    end

    Label(figure[3, 1:2], "Observed", fontsize=17, tellwidth=false)
    Label(figure[1:2, 0], "Simulated", rotation=pi / 2, fontsize=17, tellheight=false)

    Legend(
        figure[4, 1:2],
        [
            MarkerElement(color=(COLOR_GLOBAL, 0.65), marker=:circle, markersize=11),
            LineElement(color=(:grey45, 0.8), linewidth=3),
        ],
        ["PlantBiophysics", "1:1 line"];
        orientation=:horizontal,
        framevisible=false,
        tellwidth=false,
    )
    colgap!(figure.layout, 28)
    rowgap!(figure.layout, 16)
    resize_to_layout!(figure)
    return figure
end

function daily_figure(scenario)
    figure = Figure(size=(1050, 720), fontsize=14, backgroundcolor=:white)
    Label(
        figure[0, 1],
        "Daily evaluation — PlantBiophysics";
        fontsize=22,
        font=:bold,
        tellwidth=false,
    )
    plot_grid = figure[1, 1] = GridLayout()

    specifications = (
        (variable=:Dl, title="a) Leaf-to-air VPD, Dₗ", unit="kPa"),
        (variable=:Tl, title="b) Leaf temperature, Tₗ", unit="°C"),
        (variable=:A, title="c) Net CO₂ assimilation, A", unit="μmol CO₂ m⁻² s⁻¹"),
        (variable=:E, title="d) Transpiration, E", unit="mmol H₂O m⁻² s⁻¹"),
    )
    time_index = collect(eachindex(scenario.time))
    axes = Axis[]

    for (index, specification) in enumerate(specifications)
        row = index <= 2 ? 1 : 2
        column = isodd(index) ? 1 : 2
        axis = Axis(
            plot_grid[row, column];
            title=specification.title,
            titlealign=:left,
            ylabel=specification.unit,
            xticks=(time_index, scenario.time),
        )
        style_axis!(axis)
        push!(axes, axis)

        observed = getproperty(scenario.observed, specification.variable)
        simulated = getproperty(scenario.simulated, specification.variable)
        lower = pquantile.(simulated, 0.025)
        upper = pquantile.(simulated, 0.975)
        simulated_mean = pmean.(simulated)

        band!(axis, time_index, lower, upper; color=(COLOR_SIMULATED, 0.18))
        lines!(axis, time_index, simulated_mean; color=COLOR_SIMULATED, linewidth=2.8)
        scatter!(
            axis,
            time_index,
            observed;
            color=(COLOR_OBSERVED, 0.55),
            strokecolor=COLOR_OBSERVED,
            strokewidth=2,
            markersize=10,
        )
        xlims!(axis, 0.65, length(time_index) + 0.35)
        add_metric_label!(axis, observed, simulated)
    end

    hidexdecorations!(axes[1]; grid=false)
    hidexdecorations!(axes[2]; grid=false)
    Label(figure[2, 1], "Time (HH:MM)", fontsize=16, tellwidth=false)

    Legend(
        figure[3, 1],
        [
            MarkerElement(
                color=(COLOR_OBSERVED, 0.55),
                strokecolor=COLOR_OBSERVED,
                strokewidth=2,
                marker=:circle,
                markersize=11,
            ),
            LineElement(color=COLOR_SIMULATED, linewidth=3),
            PolyElement(color=(COLOR_SIMULATED, 0.18), strokecolor=:transparent),
        ],
        [
            "Observation",
            "PlantBiophysics mean",
            "95% propagated interval",
        ];
        orientation=:horizontal,
        framevisible=false,
        tellwidth=false,
        nbanks=1,
    )
    colgap!(plot_grid, 30)
    rowgap!(plot_grid, 16)
    rowgap!(figure.layout, 12)
    return figure
end

function schymanski_figure(scenario)
    figure = Figure(size=(1100, 650), fontsize=14, backgroundcolor=:white)
    Label(
        figure[0, 1],
        "Schymanski et al. (2017) evaluation";
        fontsize=22,
        font=:bold,
        tellwidth=false,
    )
    axis = Axis(
        figure[1, 1];
        xlabel="Wind speed (m s⁻¹)",
        ylabel="Leaf energy flux (W m⁻²)",
        width=760,
        height=430,
    )
    style_axis!(axis)

    wind = scenario.wind
    scatter!(
        axis,
        wind,
        scenario.observed.LE;
        color=COLOR_LE,
        markersize=9,
        strokecolor=:white,
        strokewidth=0.8,
    )
    scatter!(
        axis,
        wind,
        scenario.observed.H;
        color=COLOR_H,
        markersize=9,
        strokecolor=:white,
        strokewidth=0.8,
    )
    scatter!(
        axis,
        wind,
        scenario.observed.Rn;
        color=COLOR_RN,
        markersize=9,
        strokecolor=:white,
        strokewidth=0.8,
    )
    scatter!(
        axis,
        wind,
        scenario.observed.H .+ scenario.observed.LE;
        color=COLOR_RN,
        marker=:star5,
        markersize=13,
        strokecolor=:white,
        strokewidth=0.8,
    )

    lines!(axis, wind, scenario.simulated.LE; color=COLOR_LE, linewidth=2.8)
    lines!(axis, wind, scenario.simulated.H; color=COLOR_H, linewidth=2.8)
    lines!(axis, wind, scenario.simulated.Rn; color=COLOR_RN, linewidth=2.8)

    text!(
        axis,
        0.04,
        0.96;
        text="H: $(metric_label(scenario.observed.H, scenario.simulated.H))\n" *
             "λE: $(metric_label(scenario.observed.LE, scenario.simulated.LE))",
        space=:relative,
        align=(:left, :top),
        fontsize=12,
        color=:grey25,
    )

    Legend(
        figure[2, 1],
        [
            LineElement(color=COLOR_LE, linewidth=3),
            LineElement(color=COLOR_H, linewidth=3),
            LineElement(color=COLOR_RN, linewidth=3),
            MarkerElement(color=COLOR_RN, marker=:star5, markersize=12),
        ],
        ["λE", "H", "Rn", "H + λE"];
        orientation=:horizontal,
        framevisible=false,
        tellwidth=false,
    )
    Legend(
        figure[3, 1],
        [
            MarkerElement(color=:grey20, marker=:circle, markersize=10),
            LineElement(color=:grey20, linewidth=3),
        ],
        ["Observations (points)", "PlantBiophysics (lines)"];
        orientation=:horizontal,
        framevisible=false,
        tellwidth=false,
    )
    rowgap!(figure.layout, 12)
    return figure
end

function generate_evaluation_figures()
    mkpath(OUTPUT_DIR)
    CairoMakie.activate!(type="svg")

    global_scenario = run_global_evaluation()
    daily_scenario = run_daily_evaluation()
    schymanski_scenario = run_schymanski_evaluation()

    outputs = (
        medlyn_global=joinpath(OUTPUT_DIR, "medlyn_global.svg"),
        medlyn_daily=joinpath(OUTPUT_DIR, "medlyn_daily.svg"),
        schymanski_energy_fluxes=joinpath(OUTPUT_DIR, "schymanski_energy_fluxes.svg"),
    )
    save(outputs.medlyn_global, global_figure(global_scenario); pt_per_unit=1)
    save(outputs.medlyn_daily, daily_figure(daily_scenario); pt_per_unit=1)
    save(
        outputs.schymanski_energy_fluxes,
        schymanski_figure(schymanski_scenario);
        pt_per_unit=1,
    )
    return outputs
end

end

if abspath(PROGRAM_FILE) == @__FILE__
    EvaluationFigures.generate_evaluation_figures()
end
