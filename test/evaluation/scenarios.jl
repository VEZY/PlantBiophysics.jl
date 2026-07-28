"""
Shared empirical-evaluation scenarios.

The regression tests and the documentation figure generator both include this
file so that the model setup, input filtering, and unit conversions cannot
drift apart.
"""

evaluation_leaf_status(scene) = only(model_objects(scene; scale=:Leaf)).status

struct PaperForcedGs{T} <: PlantBiophysics.AbstractStomatal_ConductanceModel
    g0::T
end

PaperForcedGs() = PaperForcedGs(0.0)

# Preserve the closure used by the paper's daily evaluation instead of silently
# replacing it with the package's general-purpose ConstantGs implementation.
function PlantBiophysics.gs_closure(
    ::PaperForcedGs,
    models,
    status,
    meteo=missing,
    constants=nothing,
    extra=nothing,
)
    status.A < 1.0e-9 && return status.Gₛ
    return status.A / (status.Gₛ - models.stomatal_conductance.g0)
end

PlantSimEngine.inputs_(::PaperForcedGs) = (Gₛ=-Inf,)
PlantSimEngine.outputs_(::PaperForcedGs) = (Gₛ=-Inf,)

function PlantSimEngine.run!(
    ::PaperForcedGs,
    models,
    status,
    meteo,
    constants=nothing,
    extra=nothing,
)
    return nothing
end

function read_evaluation_parameters(file)
    parameters = Dict{String,Float64}()
    for line in eachline(file)
        key, value = strip.(split(line, "="; limit=2))
        parameters[key] = parse(Float64, value)
    end
    return parameters
end

"""
    run_global_evaluation()

Run the PlantBiophysics-only global Medlyn evaluation. Each of the 536
observations passing the paper's `Ca > 150 ppm` filter is evaluated exactly
once.
"""
function run_global_evaluation()
    fixture_dir = normpath(joinpath(@__DIR__, "..", "inputs", "evaluation"))
    observations = CSV.read(joinpath(fixture_dir, "medlyn_global.csv"), DataFrame)
    parameters = CSV.read(
        joinpath(fixture_dir, "medlyn_global_parameters.csv"),
        DataFrame,
    )

    n_observations = nrow(observations)
    n_parameters = nrow(parameters)
    parameter_curves_unique = allunique(parameters.curve)
    curves_match = Set(observations.curve) == Set(parameters.curve)

    filter!(row -> row.Ca > 150.0, observations)
    evaluation = leftjoin(observations, parameters; on=:curve)
    disallowmissing!(evaluation)

    constants = Constants()
    simulated_A = Vector{Float64}(undef, nrow(evaluation))
    simulated_E = similar(simulated_A)
    simulated_Gs = similar(simulated_A)
    simulated_Tl = similar(simulated_A)

    for (index, row) in enumerate(eachrow(evaluation))
        meteo = Atmosphere(
            T=row.T,
            Wind=20.0,
            P=row.P,
            Rh=row.Rh,
            Cₐ=row.Ca,
            duration=Minute(1),
        )
        scene = leaf_scene(
            Monteith(aₛₕ=2, aₛᵥ=1, ε=0.95, maxiter=100),
            Fvcb(
                Tᵣ=row.Tr,
                VcMaxRef=row.VcMaxRef,
                JMaxRef=row.JMaxRef,
                RdRef=row.RdRef,
                TPURef=row.TPURef,
                α=0.425,
                θ=0.7,
            ),
            Medlyn(row.g0, row.g1);
            status=Status(
                Ra_SW_f=row.aPPFD / 4.57,
                sky_fraction=1.0,
                aPPFD=row.aPPFD,
                d=sqrt(row.area) / 100,
            ),
            environment=meteo,
        )
        run!(scene; constants=constants)
        status = evaluation_leaf_status(scene)

        simulated_A[index] = status.A
        simulated_E[index] = status.λE / (meteo.λ * constants.Mₕ₂ₒ) * 1000
        simulated_Gs[index] = status.Gₛ
        simulated_Tl[index] = status.Tₗ
    end

    return (
        observed=(
            A=collect(evaluation.A),
            E=collect(evaluation.E),
            Gs=collect(evaluation.Gs),
            Tl=collect(evaluation.Tl),
        ),
        simulated=(
            A=simulated_A,
            E=simulated_E,
            Gs=simulated_Gs,
            Tl=simulated_Tl,
        ),
        metadata=(
            n_observations=n_observations,
            n_parameters=n_parameters,
            parameter_curves_unique=parameter_curves_unique,
            curves_match=curves_match,
            n_evaluated=nrow(evaluation),
        ),
    )
end

"""
    run_daily_evaluation(; seed=0x5eed)

Run the six-observation daily Medlyn evaluation with measured stomatal
conductance forced and uncertainty propagated with 2,000 particles.
"""
function run_daily_evaluation(; seed=0x5eed)
    Random.seed!(seed)

    fixture = normpath(
        joinpath(@__DIR__, "..", "inputs", "evaluation", "medlyn_daily.csv"),
    )
    observations = CSV.read(fixture, DataFrame)

    # Fitted on the 29 main-branch A-Ci observations for leaf age 1 on
    # 2001-11-14. Freezing the fit keeps this a simulation-quality regression.
    fitted = (
        VcMaxRef=76.92258957980812,
        JMaxRef=144.11325631779883,
        RdRef=0.0,
        TPURef=10.824455548761254,
    )
    constants = Constants()

    rows = MonteCarloMeasurements.@unsafe map(eachrow(observations)) do row
        meteo = Atmosphere(
            T=row.T ± 0.1,
            Wind=40.0 ± 10.0,
            P=row.P ± (0.001 * row.P),
            Rh=(row.RH_percent / 100) ± 0.01,
            Cₐ=row.Ca ± 10.0,
            duration=Minute(1),
        )
        absorbed_ppfd = row.PPFD * 0.85
        measured_Gs = gsw_to_gsc(row.Gsw)
        scene = leaf_scene(
            Monteith(maxiter=100),
            Fvcb(; fitted...),
            PaperForcedGs();
            status=Status(
                Ra_SW_f=(absorbed_ppfd ± (0.1 * absorbed_ppfd)) / 4.57,
                sky_fraction=1.0,
                aPPFD=absorbed_ppfd ± (0.1 * absorbed_ppfd),
                d=MonteCarloMeasurements.:..(0.01, 0.10),
                Gₛ=measured_Gs ± 0.0,
            ),
            environment=meteo,
        )
        run!(scene; constants=constants)
        status = evaluation_leaf_status(scene)

        return (
            Dl=status.Dₗ,
            Tl=status.Tₗ,
            A=status.A,
            E=status.λE / (meteo.λ * constants.Mₕ₂ₒ) * 1000,
        )
    end

    return (
        time=Dates.format.(observations.time, dateformat"HH:MM"),
        observed=(
            Dl=collect(observations.Dl),
            Tl=collect(observations.Tl),
            A=collect(observations.A),
            E=collect(observations.E),
        ),
        simulated=(
            Dl=getproperty.(rows, :Dl),
            Tl=getproperty.(rows, :Tl),
            A=getproperty.(rows, :A),
            E=getproperty.(rows, :E),
        ),
        metadata=(n_observations=nrow(observations), seed=seed),
    )
end

"""
    run_schymanski_evaluation()

Run the PlantBiophysics energy-balance scenario against the observations used
for figure 6a of Schymanski et al. (2017).
"""
function run_schymanski_evaluation()
    data_dir = normpath(
        joinpath(@__DIR__, "..", "..", "docs", "src", "data", "schymanski_et_al_2017"),
    )
    observations = CSV.read(joinpath(data_dir, "results1_6a.csv"), DataFrame)
    parameters = read_evaluation_parameters(joinpath(data_dir, "vdict_6a.txt"))
    sort!(observations, :v_w)

    constants = Constants(
        Cₚ=1010.0,
        ε=parameters["epsilon"],
        λ₀=parameters["lambda_E"],
        R=parameters["R_mol"],
        σ=parameters["sigm"],
        Mₕ₂ₒ=parameters["M_w"],
    )

    rows = map(eachrow(observations)) do row
        temperature = row.T_a - parameters["T0"]
        pressure = row.P_a / 1000
        meteo = Atmosphere(
            T=temperature,
            Wind=row.v_w,
            P=pressure,
            Rh=rh_from_e(row.P_wa / 1000, temperature),
            duration=Minute(1),
        )
        measured_Gs = gsw_to_gsc(ms_to_mol(row.g_sw, temperature, pressure))
        scene = leaf_scene(
            Monteith(aₛᵥ=parameters["a_s"], maxiter=20),
            ConstantA(0.0);
            status=Status(
                Ra_SW_f=row.Rn_leaf,
                sky_fraction=2.0,
                d=row.L_l,
                Gₛ=measured_Gs,
            ),
            environment=meteo,
        )
        run!(scene; constants=constants)
        status = evaluation_leaf_status(scene)
        return (H=status.H, LE=status.λE, Rn=status.Rn)
    end

    return (
        wind=collect(observations.v_w),
        observed=(
            H=collect(observations.Hlmeas),
            LE=collect(observations.Elmeas),
            Rn=collect(observations.Rn_leaf),
        ),
        simulated=(
            H=getproperty.(rows, :H),
            LE=getproperty.(rows, :LE),
            Rn=getproperty.(rows, :Rn),
        ),
        metadata=(n_observations=nrow(observations),),
    )
end
