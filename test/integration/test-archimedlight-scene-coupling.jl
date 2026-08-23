module PlantBiophysicsArchimedLightIntegrationSupport

using ArchimedLight
using Dates
using GeometryBasics
using PlantBiophysics
using PlantGeom
using PlantMeteo
using PlantSimEngine
using Statistics

const LEAF_IDS = (:leaf_beta, :leaf_alpha)
const SKY_FRACTIONS = Dict(:leaf_alpha => 1.0, :leaf_beta => 0.65)
const COUPLING_OUTPUTS = (
    :Ri_PAR_f,
    :Ri_NIR_f,
    :Ra_PAR_f,
    :Ra_NIR_f,
    :Ra_SW_f,
    :aPPFD,
    :radiative_mesh_area,
)

function triangle_mesh()
    return GeometryBasics.Mesh(
        GeometryBasics.Point3f[
            GeometryBasics.Point3f(0, 0, 0),
            GeometryBasics.Point3f(1, 0, 0),
            GeometryBasics.Point3f(0, 1, 0),
        ],
        GeometryBasics.TriangleFace{Int}[
            GeometryBasics.TriangleFace{Int}(1, 2, 3),
        ],
    )
end

function radiative_fixture()
    mesh = triangle_mesh()
    scene = PlantGeom.make_scene(domain=(-1.0, -1.0, 5.0, 3.0)) do builder
        PlantGeom.add_object!(
            builder,
            mesh;
            group="plants",
            type="Leaf",
            id=101,
            at=(0.0, 0.0, 1.0),
            rotate=(x=15.0,),
            deg=true,
        )
        PlantGeom.add_object!(
            builder,
            mesh;
            group="plants",
            type="Leaf",
            id=202,
            at=(2.0, 0.0, 1.0),
            scale=1.4,
            rotate=(x=55.0,),
            deg=true,
        )
    end
    models = ArchimedLight.models_for(
        "plants" => (
            "Leaf" => ArchimedLight.translucent(par=0.15, nir=0.30),
        ),
    )
    options = ArchimedLight.LightOptions(
        turtle_sectors=1,
        all_in_turtle=false,
        scattering=false,
        toricity=false,
        pixel_size=0.05,
        cache_radiation=true,
    )
    return scene, models, options
end

function comparable_radiative_fixture(component_count::Int)
    component_count in (2, 3) || error(
        "The comparable fixture supports two or three leaf components.",
    )
    mesh = triangle_mesh()
    scene = PlantGeom.make_scene(domain=(-1.0, -1.0, 7.0, 3.0)) do builder
        for instance_id in 1:component_count
            PlantGeom.add_object!(
                builder,
                mesh;
                group="plants",
                type="Leaf",
                id=300 + instance_id,
                at=(2.0 * (instance_id - 1), 0.0, 1.0),
            )
        end
    end
    models = ArchimedLight.models_for(
        "plants" => (
            "Leaf" => ArchimedLight.translucent(par=0.15, nir=0.30),
        ),
    )
    options = ArchimedLight.LightOptions(
        turtle_sectors=1,
        all_in_turtle=false,
        scattering=false,
        toricity=false,
        pixel_size=0.05,
        cache_radiation=true,
    )
    return scene, models, options
end

function coupled_environment()
    atmosphere = PlantMeteo.Atmosphere(
        T=22.0,
        Wind=1.0,
        P=101.3,
        Rh=0.65,
        Cₐ=400.0,
        duration=Dates.Minute(1),
    )
    return merge(
        NamedTuple(atmosphere),
        (
            sun_azimuth_deg=180.0,
            sun_elevation_deg=75.0,
            Ri_PAR_f=180.0,
            Ri_NIR_f=120.0,
            direct_fraction=0.8,
        ),
    )
end

function sky(environment=coupled_environment())
    return ArchimedLight.SkyState(
        Float64(environment.sun_azimuth_deg),
        Float64(environment.sun_elevation_deg),
        Float64(environment.Ri_PAR_f),
        Float64(environment.Ri_NIR_f),
        Float64(environment.direct_fraction),
        1.0 - Float64(environment.direct_fraction),
    )
end

function source_values(light, environment=coupled_environment())
    return ArchimedLight.component_values(ArchimedLight.run_light(
        light,
        sky(environment);
        step_duration_seconds=60.0,
    ))
end

function destinations(values)
    length(values.source_owner) == 2 || error(
        "The integration fixture must produce exactly two radiative components.",
    )
    source_instance_ids = Set(
        owner.source_instance_id for owner in values.source_owner
    )
    source_instance_ids == Set((1, 2)) || error(
        "The integration fixture requires source instance ids 1 and 2.",
    )
    # Invert source-instance identity explicitly: the resolved source order
    # [1, 2] becomes [:leaf_beta, :leaf_alpha], whereas OutputTargets uses
    # stable ObjectId order [:leaf_alpha, :leaf_beta].
    return Dict(
        owner => if owner.source_instance_id == 1
            :leaf_beta
        elseif owner.source_instance_id == 2
            :leaf_alpha
        else
            error("Unexpected source instance id $(owner.source_instance_id).")
        end
        for owner in values.source_owner
    )
end

function light_application(kernel)
    return PlantSimEngine.ModelSpec(
        kernel;
        name=:archimed_light,
        on=PlantSimEngine.One(scale=:Scene),
        outputs_to=(
            organs=PlantSimEngine.OutputTo(
                PlantSimEngine.Many(
                    scale=:Leaf,
                    within=PlantSimEngine.SceneScope(),
                );
                vars=ArchimedLight.archimed_light_outputs(:coupling),
            ),
        ),
        every=Dates.Minute(1),
    )
end

function leaf_objects(; manual_light::Bool=false)
    function leaf_status(id)
        base = (
            sky_fraction=SKY_FRACTIONS[id],
            d=id === :leaf_alpha ? 0.03 : 0.04,
            Tₗ=id === :leaf_alpha ? 24.0 : 25.0,
            Cₛ=id === :leaf_alpha ? 398.0 : 392.0,
            Dₗ=id === :leaf_alpha ? 1.0 : 1.2,
        )
        return PlantSimEngine.Status(
            manual_light ? merge(base, (aPPFD=0.0, Ra_SW_f=0.0)) : base,
        )
    end

    return PlantSimEngine.Object[
        PlantSimEngine.Object(:scene; scale=:Scene, kind=:scene),
        PlantSimEngine.Object(:plant_beta; scale=:Plant, parent=:scene),
        PlantSimEngine.Object(
            :leaf_beta;
            scale=:Leaf,
            parent=:plant_beta,
            status=leaf_status(:leaf_beta),
        ),
        PlantSimEngine.Object(:plant_alpha; scale=:Plant, parent=:scene),
        PlantSimEngine.Object(
            :leaf_alpha;
            scale=:Leaf,
            parent=:plant_alpha,
            status=leaf_status(:leaf_alpha),
        ),
    ]
end

function physiology_applications(mode::Symbol)
    mode in (:fvcb, :chain) || throw(ArgumentError("Unknown physiology mode $mode."))
    photosynthesis = PlantSimEngine.ModelSpec(
        PlantBiophysics.Fvcb(α=0.24);
        name=:photosynthesis,
        on=PlantSimEngine.Many(scale=:Leaf),
        every=Dates.Minute(1),
    )
    stomatal_conductance = PlantSimEngine.ModelSpec(
        PlantBiophysics.Medlyn(0.03, 12.0);
        name=:stomatal_conductance,
        on=PlantSimEngine.Many(scale=:Leaf),
        every=Dates.Minute(1),
    )
    mode === :fvcb && return (photosynthesis, stomatal_conductance)
    energy_balance = PlantSimEngine.ModelSpec(
        PlantBiophysics.Monteith();
        name=:energy_balance,
        on=PlantSimEngine.Many(scale=:Leaf),
        every=Dates.Minute(1),
    )
    return (energy_balance, photosynthesis, stomatal_conductance)
end

function build_scenario(mode::Symbol; distributed_light::Bool=true)
    scene, models, options = radiative_fixture()
    light = ArchimedLight.LightSimulation(scene, models; options=options)
    initial_values = source_values(light)
    owner_to_leaf = destinations(initial_values)
    physiology = physiology_applications(mode)
    applications = if distributed_light
        kernel = ArchimedLight.ArchimedLightModel(
            light;
            object_resolver=owner -> owner_to_leaf[owner],
        )
        # Put the scene writer last in declaration order. The compiled dependency, not
        # declaration order, must schedule it before ordinary leaf consumers.
        (physiology..., light_application(kernel))
    else
        physiology
    end
    runtime = PlantSimEngine.CompositeModel(
        leaf_objects(; manual_light=!distributed_light)...;
        applications=applications,
        environment=coupled_environment(),
    )
    return (
        runtime=runtime,
        light=light,
        owner_to_leaf=owner_to_leaf,
        initial_values=initial_values,
    )
end

function assign_manual_light!(runtime, values, owner_to_leaf)
    for row in eachindex(values.source_owner)
        object_id = owner_to_leaf[values.source_owner[row]]
        status = PlantSimEngine.model_object(runtime, object_id).status
        status.aPPFD = values.aPPFD[row]
        status.Ra_SW_f = values.Ra_SW_f[row]
    end
    return nothing
end

function start_manual!(scenario; outputs=:none)
    values = source_values(scenario.light)
    assign_manual_light!(scenario.runtime, values, scenario.owner_to_leaf)
    return PlantSimEngine.run!(scenario.runtime; outputs=outputs)
end

function continue_manual!(simulation, scenario)
    values = source_values(scenario.light)
    assign_manual_light!(scenario.runtime, values, scenario.owner_to_leaf)
    PlantSimEngine.continue!(simulation)
    return nothing
end

function expected_for_leaf(scenario, id, variable)
    row = only(
        i for i in eachindex(scenario.initial_values.source_owner)
        if scenario.owner_to_leaf[scenario.initial_values.source_owner[i]] == id
    )
    return getproperty(scenario.initial_values, variable)[row]
end

history(simulation, application, id, variable) =
    PlantSimEngine.outputs(simulation)[
        (application, PlantSimEngine.ObjectId(id), variable)
    ]

function steady_path_comparison(; samples::Int=30)
    samples > 0 || throw(ArgumentError("samples must be positive."))

    distributed = build_scenario(:chain)
    distributed_simulation = PlantSimEngine.run!(distributed.runtime; outputs=:none)
    manual = build_scenario(:chain; distributed_light=false)
    manual_simulation = start_manual!(manual; outputs=:none)

    # One unmeasured steady-state continuation after compilation and first caches.
    PlantSimEngine.continue!(distributed_simulation)
    continue_manual!(manual_simulation, manual)

    distributed_allocations = @allocated PlantSimEngine.continue!(distributed_simulation)
    manual_allocations = @allocated continue_manual!(manual_simulation, manual)

    distributed_times = Vector{Float64}(undef, samples)
    manual_times = Vector{Float64}(undef, samples)
    GC.gc()
    for i in eachindex(distributed_times)
        started = time_ns()
        PlantSimEngine.continue!(distributed_simulation)
        distributed_times[i] = time_ns() - started

        started = time_ns()
        continue_manual!(manual_simulation, manual)
        manual_times[i] = time_ns() - started
    end

    distributed_median_ns = Statistics.median(distributed_times)
    manual_median_ns = Statistics.median(manual_times)
    return (
        distributed_median_ns=distributed_median_ns,
        manual_median_ns=manual_median_ns,
        time_ratio=distributed_median_ns / manual_median_ns,
        distributed_allocations=distributed_allocations,
        manual_allocations=manual_allocations,
        allocation_ratio=distributed_allocations / max(manual_allocations, 1),
        distributed_simulation=distributed_simulation,
        manual_simulation=manual_simulation,
    )
end

end

const CouplingSupport = PlantBiophysicsArchimedLightIntegrationSupport

@testset "ArchimedLight automatically feeds ordinary leaf FvCB" begin
    scenario = CouplingSupport.build_scenario(:fvcb)
    @test !isapprox(
        scenario.initial_values.aPPFD[1],
        scenario.initial_values.aPPFD[2];
        rtol=1.0e-6,
        atol=0.0,
    )
    compiled = PlantSimEngine.Advanced.refresh_bindings!(scenario.runtime)

    schedule_rows = PlantSimEngine.Diagnostics.explain_schedule(compiled)
    schedule = Dict(
        row.application_id => row.execution_index
        for row in schedule_rows
    )
    @test schedule[:archimed_light] < schedule[:photosynthesis]
    @test all(row.timestep == Dates.Minute(1) for row in schedule_rows)
    @test all(row.dt_seconds == 60.0 for row in schedule_rows)
    @test only(
        row for row in schedule_rows if row.application_id == :archimed_light
    ).root_scheduled
    @test only(
        row for row in schedule_rows if row.application_id == :photosynthesis
    ).root_scheduled
    @test only(
        row for row in schedule_rows if row.application_id == :stomatal_conductance
    ).manual_call_only

    aPPFD_bindings = [
        row for row in PlantSimEngine.Diagnostics.explain_bindings(compiled)
        if row.application_id == :photosynthesis && row.input == :aPPFD
    ]
    @test length(aPPFD_bindings) == 2
    @test all(
        row.source_application_ids == [:archimed_light]
        for row in aPPFD_bindings
    )

    writers = PlantSimEngine.Diagnostics.explain_writers(compiled)
    @test all(
        any(
            row.variable == variable &&
            row.object_id == id &&
            :archimed_light in row.application_ids
            for row in writers
        )
        for variable in CouplingSupport.COUPLING_OUTPUTS
        for id in CouplingSupport.LEAF_IDS
    )
    @test !any(
        row.variable == :sky_fraction && :archimed_light in row.application_ids
        for row in writers
    )
    @test :sky_fraction ∉ propertynames(ArchimedLight.archimed_light_outputs())
    output_target_order = Tuple(
        id.value
        for id in PlantSimEngine.object_ids(scenario.runtime; scale=:Leaf)
    )
    source_destination_order = Tuple(
        scenario.owner_to_leaf[owner]
        for owner in scenario.initial_values.source_owner
    )
    @test output_target_order == (:leaf_alpha, :leaf_beta)
    @test source_destination_order == reverse(output_target_order)

    simulation = PlantSimEngine.run!(scenario.runtime; steps=2, outputs=:all)
    for id in CouplingSupport.LEAF_IDS
        state = PlantSimEngine.final_state(simulation, id)
        @test state.aPPFD ≈ CouplingSupport.expected_for_leaf(
            scenario,
            id,
            :aPPFD,
        )
        @test state.sky_fraction == CouplingSupport.SKY_FRACTIONS[id]
        @test 0.0 <= state.sky_fraction <= 2.0
        @test state.Ra_SW_f ≈ state.Ra_PAR_f + state.Ra_NIR_f
        @test state.aPPFD ≈ 4.57 * state.Ra_PAR_f
        @test isfinite(state.A) && state.A > 0.0
        @test isfinite(state.Gₛ) && state.Gₛ > 0.0
        @test 0.0 < state.Cᵢ <= state.Cₛ

        light_history = CouplingSupport.history(
            simulation,
            :archimed_light,
            id,
            :aPPFD,
        )
        assimilation_history = CouplingSupport.history(
            simulation,
            :photosynthesis,
            id,
            :A,
        )
        @test length(light_history) == 2
        @test length(assimilation_history) == 2
        @test last(light_history)[2] ≈ state.aPPFD
        @test last(assimilation_history)[2] ≈ state.A
    end
end

@testset "ArchimedLight feeds the Monteith to FvCB to Medlyn hard-call chain" begin
    scenario = CouplingSupport.build_scenario(:chain)
    compiled = PlantSimEngine.Advanced.refresh_bindings!(scenario.runtime)

    schedule_rows = PlantSimEngine.Diagnostics.explain_schedule(compiled)
    schedule = Dict(
        row.application_id => row.execution_index
        for row in schedule_rows
    )
    @test schedule[:archimed_light] < schedule[:energy_balance]
    @test all(row.timestep == Dates.Minute(1) for row in schedule_rows)
    @test all(row.dt_seconds == 60.0 for row in schedule_rows)
    @test only(
        row for row in schedule_rows if row.application_id == :archimed_light
    ).root_scheduled
    @test only(
        row for row in schedule_rows if row.application_id == :energy_balance
    ).root_scheduled
    manual_rows = [
        row for row in schedule_rows
        if row.application_id in (:photosynthesis, :stomatal_conductance)
    ]
    @test length(manual_rows) == 2
    @test all(row.manual_call_only for row in manual_rows)

    shortwave_bindings = [
        row for row in PlantSimEngine.Diagnostics.explain_bindings(compiled)
        if row.application_id == :energy_balance && row.input == :Ra_SW_f
    ]
    @test length(shortwave_bindings) == 2
    @test all(
        row.source_application_ids == [:archimed_light]
        for row in shortwave_bindings
    )

    calls = PlantSimEngine.Diagnostics.explain_calls(compiled)
    energy_calls = [
        row for row in calls if row.application_id == :energy_balance
    ]
    photosynthesis_calls = [
        row for row in calls if row.application_id == :photosynthesis
    ]
    @test length(energy_calls) == 2
    @test length(photosynthesis_calls) == 2
    @test Set(row.consumer_id for row in energy_calls) ==
          Set(CouplingSupport.LEAF_IDS)
    @test Set(row.consumer_id for row in photosynthesis_calls) ==
          Set(CouplingSupport.LEAF_IDS)
    @test all(
        row.callee_application_ids == [:photosynthesis]
        for row in energy_calls
    )
    @test all(
        row.callee_application_ids == [:stomatal_conductance]
        for row in photosynthesis_calls
    )

    simulation = PlantSimEngine.run!(scenario.runtime; steps=2, outputs=:all)
    published_applications = Set(
        row.application_id
        for row in PlantSimEngine.collect_outputs(simulation; sink=nothing)
    )
    @test :archimed_light in published_applications
    @test :energy_balance in published_applications
    @test :photosynthesis ∉ published_applications
    @test :stomatal_conductance ∉ published_applications

    for id in CouplingSupport.LEAF_IDS
        state = PlantSimEngine.final_state(simulation, id)
        @test state.aPPFD ≈ CouplingSupport.expected_for_leaf(
            scenario,
            id,
            :aPPFD,
        )
        @test state.Ra_SW_f ≈ CouplingSupport.expected_for_leaf(
            scenario,
            id,
            :Ra_SW_f,
        )
        @test state.sky_fraction == CouplingSupport.SKY_FRACTIONS[id]
        @test 0.0 <= state.sky_fraction <= 2.0
        @test state.Ra_SW_f ≈ state.Ra_PAR_f + state.Ra_NIR_f
        @test state.aPPFD ≈ 4.57 * state.Ra_PAR_f
        @test all(isfinite, (state.Tₗ, state.Rn, state.H, state.λE, state.A, state.Gₛ))
        @test state.A > 0.0
        @test state.Gₛ > 0.0
        @test state.Rn ≈ state.Ra_SW_f + state.Ra_LW_f
        @test state.Rn ≈ state.H + state.λE atol = 1.0

        @test length(CouplingSupport.history(
            simulation,
            :archimed_light,
            id,
            :Ra_SW_f,
        )) == 2
        energy_history = CouplingSupport.history(
            simulation,
            :energy_balance,
            id,
            :A,
        )
        @test length(energy_history) == 2
        @test last(energy_history)[2] ≈ state.A
    end
end

@testset "Distributed and keyed manual reference paths agree" begin
    distributed = CouplingSupport.build_scenario(:chain)
    distributed_simulation = PlantSimEngine.run!(distributed.runtime; outputs=:none)

    manual = CouplingSupport.build_scenario(:chain; distributed_light=false)
    manual_simulation = CouplingSupport.start_manual!(manual; outputs=:none)

    for id in CouplingSupport.LEAF_IDS
        distributed_state = PlantSimEngine.final_state(distributed_simulation, id)
        manual_state = PlantSimEngine.final_state(manual_simulation, id)
        for variable in (
            :aPPFD,
            :Ra_SW_f,
            :Tₗ,
            :Rn,
            :H,
            :λE,
            :A,
            :Gₛ,
            :Cᵢ,
        )
            @test getproperty(distributed_state, variable) ≈
                  getproperty(manual_state, variable)
        end
    end
end

@testset "Mounted heterogeneous physiology templates follow dynamic scene light" begin
    initial_scene, light_models, light_options =
        CouplingSupport.comparable_radiative_fixture(2)
    grown_scene, _, _ = CouplingSupport.comparable_radiative_fixture(3)
    @test grown_scene !== initial_scene

    environment = CouplingSupport.coupled_environment()
    light = ArchimedLight.LightSimulation(
        initial_scene,
        light_models;
        options=light_options,
    )
    initial_radiation = CouplingSupport.source_values(light, environment)
    @test length(initial_radiation.source_owner) == 2
    @test initial_radiation.aPPFD[1] ≈ initial_radiation.aPPFD[2]
    @test initial_radiation.Ra_SW_f[1] ≈ initial_radiation.Ra_SW_f[2]

    owner_to_leaf = Dict(
        1 => :low_leaf,
        2 => :high_leaf,
        3 => :high_leaf_new,
    )
    current_scene = Ref(initial_scene)
    provider_calls = Ref(0)
    provider = _ -> begin
        provider_calls[] += 1
        current_scene[]
    end
    light_kernel = ArchimedLight.ArchimedLightModel(
        light;
        scene_provider=provider,
        object_resolver=owner -> owner_to_leaf[owner.source_instance_id],
    )

    low_fvcb = PlantBiophysics.Fvcb(
        VcMaxRef=60.0,
        JMaxRef=80.0,
        α=0.24,
    )
    high_fvcb = PlantBiophysics.Fvcb(
        VcMaxRef=220.0,
        JMaxRef=300.0,
        α=0.24,
    )
    low_template = PlantSimEngine.CompositeModelTemplate(
        (
            PlantSimEngine.ModelSpec(
                low_fvcb;
                name=:photosynthesis,
                on=PlantSimEngine.Many(scale=:Leaf),
                every=Dates.Minute(1),
            ),
            PlantSimEngine.ModelSpec(
                PlantBiophysics.Medlyn(0.03, 12.0);
                name=:stomatal_conductance,
                on=PlantSimEngine.Many(scale=:Leaf),
                every=Dates.Minute(1),
            ),
        );
        kind=:plant,
        species=:low_capacity,
    )
    high_template = PlantSimEngine.CompositeModelTemplate(
        (
            PlantSimEngine.ModelSpec(
                high_fvcb;
                name=:photosynthesis,
                on=PlantSimEngine.Many(scale=:Leaf),
                every=Dates.Minute(1),
            ),
            PlantSimEngine.ModelSpec(
                PlantBiophysics.Medlyn(0.03, 12.0);
                name=:stomatal_conductance,
                on=PlantSimEngine.Many(scale=:Leaf),
                every=Dates.Minute(1),
            ),
        );
        kind=:plant,
        species=:high_capacity,
    )
    @test low_template !== high_template
    @test (low_fvcb.VcMaxRef, low_fvcb.JMaxRef) !=
          (high_fvcb.VcMaxRef, high_fvcb.JMaxRef)

    physiology_status() = PlantSimEngine.Status(
        Tₗ=24.0,
        Cₛ=400.0,
        Dₗ=1.0,
        sky_fraction=1.0,
        d=0.03,
    )
    low_instance = PlantSimEngine.ObjectInstance(
        :low_capacity,
        low_template;
        root=PlantSimEngine.Object(
            :low_plant;
            scale=:Plant,
            parent=:scene,
        ),
        objects=(
            PlantSimEngine.Object(
                :low_leaf;
                scale=:Leaf,
                parent=:low_plant,
                status=physiology_status(),
            ),
        ),
    )
    high_instance = PlantSimEngine.ObjectInstance(
        :high_capacity,
        high_template;
        root=PlantSimEngine.Object(
            :high_plant;
            scale=:Plant,
            parent=:scene,
        ),
        objects=(
            PlantSimEngine.Object(
                :high_leaf;
                scale=:Leaf,
                parent=:high_plant,
                status=physiology_status(),
            ),
        ),
    )
    runtime = PlantSimEngine.CompositeModel(
        PlantSimEngine.Object(:scene; scale=:Scene, kind=:scene),
        low_instance,
        high_instance;
        applications=(CouplingSupport.light_application(light_kernel),),
        environment=environment,
    )

    initial_instances = PlantSimEngine.Diagnostics.explain_instances(runtime)
    @test Set(row.name for row in initial_instances) ==
          Set((:low_capacity, :high_capacity))
    @test :low_capacity__photosynthesis in only(
        row.application_ids
        for row in initial_instances
        if row.name == :low_capacity
    )
    @test :high_capacity__photosynthesis in only(
        row.application_ids
        for row in initial_instances
        if row.name == :high_capacity
    )

    simulation = PlantSimEngine.run!(runtime; steps=2, outputs=:all)
    @test provider_calls[] == 0
    low_state = PlantSimEngine.final_state(simulation, :low_leaf)
    high_state = PlantSimEngine.final_state(simulation, :high_leaf)
    @test low_state.aPPFD ≈ high_state.aPPFD
    @test low_state.Ra_SW_f ≈ high_state.Ra_SW_f
    @test !isapprox(low_state.A, high_state.A; rtol=1.0e-3, atol=1.0e-6)
    @test low_state.A > 0.0
    @test high_state.A > low_state.A

    current_scene[] = grown_scene
    PlantSimEngine.register_object!(
        runtime,
        PlantSimEngine.Object(
            :high_leaf_new;
            scale=:Leaf,
            status=physiology_status(),
        );
        parent=:high_plant,
    )
    high_instance_after_registration = only(
        row for row in PlantSimEngine.Diagnostics.explain_instances(runtime)
        if row.name == :high_capacity
    )
    @test :high_leaf_new in high_instance_after_registration.object_ids

    PlantSimEngine.continue!(simulation)
    @test provider_calls[] == 1

    refreshed = PlantSimEngine.Advanced.refresh_bindings!(runtime)
    high_photosynthesis = only(
        row for row in PlantSimEngine.Diagnostics.explain_applications(refreshed)
        if row.application_id == :high_capacity__photosynthesis
    )
    @test Set(high_photosynthesis.target_ids) ==
          Set((:high_leaf, :high_leaf_new))

    high_state = PlantSimEngine.final_state(simulation, :high_leaf)
    new_state = PlantSimEngine.final_state(simulation, :high_leaf_new)
    @test new_state.aPPFD > 0.0
    @test new_state.A > 0.0
    @test new_state.Gₛ > 0.0
    @test new_state.aPPFD ≈ high_state.aPPFD
    @test new_state.A ≈ high_state.A
    @test new_state.Gₛ ≈ high_state.Gₛ

    new_light_history = CouplingSupport.history(
        simulation,
        :archimed_light,
        :high_leaf_new,
        :aPPFD,
    )
    new_assimilation_history = CouplingSupport.history(
        simulation,
        :high_capacity__photosynthesis,
        :high_leaf_new,
        :A,
    )
    new_conductance_history = CouplingSupport.history(
        simulation,
        :high_capacity__photosynthesis,
        :high_leaf_new,
        :Gₛ,
    )
    @test first.(new_light_history) == [3.0]
    @test first.(new_assimilation_history) == [3.0]
    @test first.(new_conductance_history) == [3.0]
    @test last(new_light_history)[2] ≈ new_state.aPPFD
    @test last(new_assimilation_history)[2] ≈ new_state.A
    @test last(new_conductance_history)[2] ≈ new_state.Gₛ
end

if lowercase(get(ENV, "PLANTBIOPHYSICS_RUN_SCENE_LIGHT_BENCHMARK", "false")) == "true"
    @testset "Steady distributed versus manual light-to-physiology path" begin
        comparison = CouplingSupport.steady_path_comparison()
        @info "Scene-light coupling performance" comparison=(
            distributed_median_ns=comparison.distributed_median_ns,
            manual_median_ns=comparison.manual_median_ns,
            time_ratio=comparison.time_ratio,
            distributed_allocations=comparison.distributed_allocations,
            manual_allocations=comparison.manual_allocations,
            allocation_ratio=comparison.allocation_ratio,
        )

        for id in CouplingSupport.LEAF_IDS
            distributed_state = PlantSimEngine.final_state(
                comparison.distributed_simulation,
                id,
            )
            manual_state = PlantSimEngine.final_state(
                comparison.manual_simulation,
                id,
            )
            @test distributed_state.A ≈ manual_state.A
            @test distributed_state.Tₗ ≈ manual_state.Tₗ
        end
    end
end
