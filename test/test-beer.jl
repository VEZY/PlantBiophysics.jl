constants = Constants()
meteo = Atmosphere(
    T=20.0,
    Wind=1.0,
    P=101.3,
    Rh=0.65,
    Ri_PAR_f=300.0,
    duration=Hour(1),
)

function canopy_light_scene(model, environment; lai=2.0)
    return CompositeModel(
        Object(:plant; scale=:Plant, status=Status(LAI=lai));
        applications=(
            ModelSpec(model; name=:canopy_light, on=One(scale=:Plant)),
        ),
        environment=environment,
    )
end

PlantSimEngine.@process "ground_radiation_probe" verbose = false

struct GroundRadiationProbe <: AbstractGround_Radiation_ProbeModel end

PlantSimEngine.inputs_(::GroundRadiationProbe) = (
    aPPFD=PlantSimEngine.Required(Real),
    Ra_SW_f=PlantSimEngine.Required(Real),
)
PlantSimEngine.outputs_(::GroundRadiationProbe) = (
    seen_aPPFD=-Inf,
    seen_Ra_SW_f=-Inf,
)
PlantSimEngine.variable_contracts_(::GroundRadiationProbe) = (
    aPPFD=PlantBiophysics.GROUND_PAR_PHOTON_FLUX_CONTRACT,
    Ra_SW_f=PlantBiophysics.GROUND_IRRADIANCE_CONTRACT,
)
function PlantSimEngine.run!(
    ::GroundRadiationProbe,
    status,
    environment,
    constants,
    context=nothing,
)
    status.seen_aPPFD = status.aPPFD
    status.seen_Ra_SW_f = status.Ra_SW_f
    return nothing
end

function ground_rate_scene(environment)
    return CompositeModel(
        Object(:plant; scale=:Plant, status=Status(LAI=2.0));
        applications=(
            ModelSpec(
                GroundRadiationProbe();
                name=:ground_probe,
                on=One(scale=:Plant),
            ),
            ModelSpec(
                BeerShortwave(0.5);
                name=:canopy_light,
                on=One(scale=:Plant),
            ),
        ),
        environment=environment,
    )
end

@testset "Beer-Lambert" begin
    @test Beer <: AbstractLight_InterceptionModel
    scene = canopy_light_scene(Beer(0.5), meteo)
    run!(scene; constants=constants)
    @test model_object(scene, :plant).status.aPPFD ≈
          300.0 * (1.0 - exp(-0.5 * 2.0)) * constants.J_to_umol
end

@testset "Radiation basis contracts" begin
    beer_contracts = variable_contracts(Beer(0.5))
    @test beer_contracts.LAI == PlantBiophysics.LEAF_AREA_INDEX_CONTRACT
    @test beer_contracts.aPPFD ==
          PlantBiophysics.GROUND_PAR_PHOTON_FLUX_CONTRACT

    shortwave_contracts = variable_contracts(BeerShortwave(0.5))
    @test shortwave_contracts.LAI == PlantBiophysics.LEAF_AREA_INDEX_CONTRACT
    @test shortwave_contracts.aPPFD ==
          PlantBiophysics.GROUND_PAR_PHOTON_FLUX_CONTRACT
    @test shortwave_contracts.Ra_SW_f ==
          PlantBiophysics.GROUND_IRRADIANCE_CONTRACT
    @test all(
        variable ∉ keys(shortwave_contracts)
        for variable in (:Ra_PAR_f, :Ra_NIR_f)
    )

    ppfd_adapter_contracts = variable_contracts(GroundToMeanLeafPPFD())
    @test ppfd_adapter_contracts == (
        LAI=PlantBiophysics.LEAF_AREA_INDEX_CONTRACT,
        aPPFD_ground=PlantBiophysics.GROUND_PAR_PHOTON_FLUX_CONTRACT,
        aPPFD_leaf_mean=PlantBiophysics.LEAF_PAR_PHOTON_FLUX_CONTRACT,
    )

    shortwave_adapter_contracts =
        variable_contracts(GroundToMeanLeafShortwave())
    @test shortwave_adapter_contracts == (
        LAI=PlantBiophysics.LEAF_AREA_INDEX_CONTRACT,
        Ra_SW_f_ground=PlantBiophysics.GROUND_IRRADIANCE_CONTRACT,
        Ra_SW_f_leaf_mean=PlantBiophysics.LEAF_IRRADIANCE_CONTRACT,
    )

    for model in (Fvcb(), FvcbRaw(), FvcbIter())
        @test variable_contracts(model).aPPFD ==
              PlantBiophysics.LEAF_PAR_PHOTON_FLUX_CONTRACT
    end
    @test variable_contracts(Monteith()).Ra_SW_f ==
          PlantBiophysics.LEAF_IRRADIANCE_CONTRACT

    ppfd_mesh_contracts = variable_contracts(RadiativeMeshToLeafPPFD())
    @test ppfd_mesh_contracts == (
        aPPFD_radiative=
            PlantBiophysics.RADIATIVE_MESH_PAR_PHOTON_FLUX_CONTRACT,
        radiative_mesh_area=PlantBiophysics.RADIATIVE_MESH_AREA_CONTRACT,
        botanical_leaf_area=PlantBiophysics.BOTANICAL_LEAF_AREA_CONTRACT,
        aPPFD_leaf_mean=PlantBiophysics.LEAF_PAR_PHOTON_FLUX_CONTRACT,
    )
    shortwave_mesh_contracts =
        variable_contracts(RadiativeMeshToLeafShortwave())
    @test shortwave_mesh_contracts == (
        Ra_SW_f_radiative=
            PlantBiophysics.RADIATIVE_MESH_IRRADIANCE_CONTRACT,
        radiative_mesh_area=PlantBiophysics.RADIATIVE_MESH_AREA_CONTRACT,
        botanical_leaf_area=PlantBiophysics.BOTANICAL_LEAF_AREA_CONTRACT,
        Ra_SW_f_leaf_mean=PlantBiophysics.LEAF_IRRADIANCE_CONTRACT,
    )
end

@testset "BeerShortwave extinction and numerical outputs" begin
    model = BeerShortwave(0.6)
    @test model.k_PAR == 0.6
    @test model.k_NIR == 0.48

    shortwave_meteo = Atmosphere(
        T=20.0,
        Wind=1.0,
        P=101.3,
        Rh=0.65,
        Ri_PAR_f=300.0,
        Ri_NIR_f=250.0,
        duration=Hour(1),
    )
    scene = canopy_light_scene(model, shortwave_meteo)
    run!(scene; constants=constants)

    absorbed_par_fraction = 1.0 - exp(-0.6 * 2.0)
    absorbed_nir_fraction = 1.0 - exp(-0.48 * 2.0)
    status = model_object(scene, :plant).status
    @test status.Ra_PAR_f ≈ 300.0 * absorbed_par_fraction
    @test status.Ra_NIR_f ≈ 250.0 * absorbed_nir_fraction
    @test status.Ra_SW_f ≈
          300.0 * absorbed_par_fraction + 250.0 * absorbed_nir_fraction
    @test status.aPPFD ≈ status.Ra_PAR_f * constants.J_to_umol
end

@testset "Explicit ground-to-mean-leaf adapters" begin
    ppfd_scene = CompositeModel(
        Object(
            :plant;
            scale=:Plant,
            status=Status(LAI=2.0),
        ),
        Object(
            :leaf;
            scale=:Leaf,
            parent=:plant,
            status=Status(Tₗ=25.0, Cᵢ=300.0),
        );
        applications=(
            ModelSpec(
                Beer(0.5);
                name=:canopy_light,
                on=One(scale=:Plant),
            ),
            ModelSpec(
                GroundToMeanLeafPPFD();
                name=:mean_leaf_ppfd,
                on=One(scale=:Plant),
                inputs=(
                    :aPPFD_ground => One(
                        within=Self(),
                        application=:canopy_light,
                        var=:aPPFD,
                        policy=HoldLast(),
                    ),
                ),
            ),
            ModelSpec(
                FvcbRaw();
                name=:photosynthesis,
                on=One(scale=:Leaf),
                inputs=(
                    :aPPFD => One(
                        scale=:Plant,
                        within=SelfPlant(),
                        application=:mean_leaf_ppfd,
                        var=:aPPFD_leaf_mean,
                        policy=HoldLast(),
                    ),
                ),
            ),
        ),
        environment=meteo,
    )
    Advanced.compile_composite_model(ppfd_scene)
    run!(ppfd_scene; constants=constants, outputs=:none)

    expected_ground_ppfd =
        300.0 * (1.0 - exp(-0.5 * 2.0)) * constants.J_to_umol
    plant_status = model_object(ppfd_scene, :plant).status
    @test plant_status.aPPFD ≈ expected_ground_ppfd
    @test plant_status.aPPFD_leaf_mean ≈ expected_ground_ppfd / 2.0
    @test isfinite(leaf_status(ppfd_scene).A)

    shortwave_meteo = Atmosphere(
        T=20.0,
        Wind=1.0,
        P=101.3,
        Rh=0.65,
        Ri_PAR_f=300.0,
        Ri_NIR_f=250.0,
        duration=Hour(1),
    )
    shortwave_scene = CompositeModel(
        Object(
            :plant;
            scale=:Plant,
            status=Status(LAI=2.0),
        ),
        Object(
            :leaf;
            scale=:Leaf,
            parent=:plant,
            status=Status(sky_fraction=1.0, d=0.03),
        );
        applications=(
            ModelSpec(
                BeerShortwave(0.5, 0.5);
                name=:canopy_light,
                on=One(scale=:Plant),
            ),
            ModelSpec(
                GroundToMeanLeafShortwave();
                name=:mean_leaf_shortwave,
                on=One(scale=:Plant),
                inputs=(
                    :Ra_SW_f_ground => One(
                        within=Self(),
                        application=:canopy_light,
                        var=:Ra_SW_f,
                        policy=HoldLast(),
                    ),
                ),
            ),
            ModelSpec(
                Monteith();
                name=:energy_balance,
                on=One(scale=:Leaf),
                inputs=(
                    :Ra_SW_f => One(
                        scale=:Plant,
                        within=SelfPlant(),
                        application=:mean_leaf_shortwave,
                        var=:Ra_SW_f_leaf_mean,
                        policy=HoldLast(),
                    ),
                ),
            ),
            ModelSpec(
                ConstantAGs();
                name=:photosynthesis,
                on=One(scale=:Leaf),
            ),
            ModelSpec(
                ConstantGs(0.0, 0.2);
                name=:stomatal_conductance,
                on=One(scale=:Leaf),
            ),
        ),
        environment=shortwave_meteo,
    )
    Advanced.compile_composite_model(shortwave_scene)
    run!(shortwave_scene; constants=constants, outputs=:none)

    expected_ground_shortwave = 550.0 * (1.0 - exp(-0.5 * 2.0))
    plant_status = model_object(shortwave_scene, :plant).status
    @test plant_status.Ra_SW_f ≈ expected_ground_shortwave
    @test plant_status.Ra_SW_f_leaf_mean ≈
          expected_ground_shortwave / 2.0
    @test isfinite(leaf_status(shortwave_scene).Tₗ)
end

@testset "Ground radiation cannot couple directly to leaf physiology" begin
    direct_ppfd_scene = CompositeModel(
        Object(
            :plant;
            scale=:Plant,
            status=Status(LAI=2.0),
        ),
        Object(
            :leaf;
            scale=:Leaf,
            parent=:plant,
            status=Status(Tₗ=25.0, Cₛ=400.0, Dₗ=1.2),
        );
        applications=(
            ModelSpec(Beer(0.5); name=:canopy_light, on=One(scale=:Plant)),
            ModelSpec(
                Fvcb();
                name=:photosynthesis,
                on=One(scale=:Leaf),
                inputs=(
                    :aPPFD => One(
                        scale=:Plant,
                        within=SelfPlant(),
                        application=:canopy_light,
                        var=:aPPFD,
                        policy=HoldLast(),
                    ),
                ),
            ),
            ModelSpec(
                Medlyn(0.03, 12.0);
                name=:stomatal_conductance,
                on=One(scale=:Leaf),
            ),
        ),
        environment=meteo,
    )
    @test_throws "Incompatible variable contracts" Advanced.compile_composite_model(
        direct_ppfd_scene,
    )

    direct_shortwave_scene = CompositeModel(
        Object(
            :plant;
            scale=:Plant,
            status=Status(LAI=2.0),
        ),
        Object(
            :leaf;
            scale=:Leaf,
            parent=:plant,
            status=Status(sky_fraction=1.0, d=0.03),
        );
        applications=(
            ModelSpec(
                BeerShortwave(0.5);
                name=:canopy_light,
                on=One(scale=:Plant),
            ),
            ModelSpec(
                Monteith();
                name=:energy_balance,
                on=One(scale=:Leaf),
                inputs=(
                    :Ra_SW_f => One(
                        scale=:Plant,
                        within=SelfPlant(),
                        application=:canopy_light,
                        var=:Ra_SW_f,
                        policy=HoldLast(),
                    ),
                ),
            ),
            ModelSpec(
                ConstantAGs();
                name=:photosynthesis,
                on=One(scale=:Leaf),
            ),
            ModelSpec(
                ConstantGs(0.0, 0.2);
                name=:stomatal_conductance,
                on=One(scale=:Leaf),
            ),
        ),
        environment=Atmosphere(
            T=20.0,
            Wind=1.0,
            P=101.3,
            Rh=0.65,
            Ri_PAR_f=300.0,
            Ri_NIR_f=250.0,
            duration=Hour(1),
        ),
    )
    @test_throws "Incompatible variable contracts" Advanced.compile_composite_model(
        direct_shortwave_scene,
    )

    nir_as_shortwave_scene = CompositeModel(
        Object(:plant; scale=:Plant, status=Status(LAI=2.0));
        applications=(
            ModelSpec(
                BeerShortwave(0.5);
                name=:canopy_light,
                on=One(scale=:Plant),
            ),
            ModelSpec(
                GroundToMeanLeafShortwave();
                name=:mean_leaf_shortwave,
                on=One(scale=:Plant),
                inputs=(
                    :Ra_SW_f_ground => One(
                        within=Self(),
                        application=:canopy_light,
                        var=:Ra_NIR_f,
                        policy=HoldLast(),
                    ),
                ),
            ),
        ),
        environment=Atmosphere(
            T=20.0,
            Wind=1.0,
            P=101.3,
            Rh=0.65,
            Ri_PAR_f=300.0,
            Ri_NIR_f=250.0,
            duration=Hour(1),
        ),
    )
    @test_throws "source output `Ra_NIR_f`" Advanced.compile_composite_model(
        nir_as_shortwave_scene,
    )
end


@testset "Radiative-mesh adapters conserve absorbed quantity" begin
    ppfd_status = Status(
        aPPFD_radiative=900.0,
        radiative_mesh_area=0.4,
        botanical_leaf_area=0.6,
        aPPFD_leaf_mean=-Inf,
    )
    PlantSimEngine.run!(
        RadiativeMeshToLeafPPFD(),
        ppfd_status,
        nothing,
        constants,
        nothing,
    )
    @test ppfd_status.aPPFD_leaf_mean ≈ 600.0
    @test ppfd_status.aPPFD_radiative * ppfd_status.radiative_mesh_area ≈
          ppfd_status.aPPFD_leaf_mean * ppfd_status.botanical_leaf_area

    shortwave_status = Status(
        Ra_SW_f_radiative=120.0,
        radiative_mesh_area=0.4,
        botanical_leaf_area=0.6,
        Ra_SW_f_leaf_mean=-Inf,
    )
    PlantSimEngine.run!(
        RadiativeMeshToLeafShortwave(),
        shortwave_status,
        nothing,
        constants,
        nothing,
    )
    @test shortwave_status.Ra_SW_f_leaf_mean ≈ 80.0
    @test shortwave_status.Ra_SW_f_radiative *
          shortwave_status.radiative_mesh_area ≈
          shortwave_status.Ra_SW_f_leaf_mean *
          shortwave_status.botanical_leaf_area

    for invalid_area in (0.0, -1.0, Inf, -Inf, NaN)
        invalid_ppfd = Status(
            aPPFD_radiative=900.0,
            radiative_mesh_area=invalid_area,
            botanical_leaf_area=0.6,
            aPPFD_leaf_mean=-Inf,
        )
        @test_throws DomainError PlantSimEngine.run!(
            RadiativeMeshToLeafPPFD(),
            invalid_ppfd,
            nothing,
            constants,
            nothing,
        )
        invalid_ppfd_botanical = Status(
            aPPFD_radiative=900.0,
            radiative_mesh_area=0.4,
            botanical_leaf_area=invalid_area,
            aPPFD_leaf_mean=-Inf,
        )
        @test_throws DomainError PlantSimEngine.run!(
            RadiativeMeshToLeafPPFD(),
            invalid_ppfd_botanical,
            nothing,
            constants,
            nothing,
        )

        invalid_shortwave = Status(
            Ra_SW_f_radiative=120.0,
            radiative_mesh_area=0.4,
            botanical_leaf_area=invalid_area,
            Ra_SW_f_leaf_mean=-Inf,
        )
        @test_throws DomainError PlantSimEngine.run!(
            RadiativeMeshToLeafShortwave(),
            invalid_shortwave,
            nothing,
            constants,
            nothing,
        )
        invalid_shortwave_radiative = Status(
            Ra_SW_f_radiative=120.0,
            radiative_mesh_area=invalid_area,
            botanical_leaf_area=0.6,
            Ra_SW_f_leaf_mean=-Inf,
        )
        @test_throws DomainError PlantSimEngine.run!(
            RadiativeMeshToLeafShortwave(),
            invalid_shortwave_radiative,
            nothing,
            constants,
            nothing,
        )
    end

    for invalid_radiation in (-1.0, Inf, -Inf, NaN)
        @test_throws DomainError PlantSimEngine.run!(
            RadiativeMeshToLeafPPFD(),
            Status(
                aPPFD_radiative=invalid_radiation,
                radiative_mesh_area=0.4,
                botanical_leaf_area=0.6,
                aPPFD_leaf_mean=-Inf,
            ),
            nothing,
            constants,
            nothing,
        )
        @test_throws DomainError PlantSimEngine.run!(
            RadiativeMeshToLeafShortwave(),
            Status(
                Ra_SW_f_radiative=invalid_radiation,
                radiative_mesh_area=0.4,
                botanical_leaf_area=0.6,
                Ra_SW_f_leaf_mean=-Inf,
            ),
            nothing,
            constants,
            nothing,
        )
    end
end


@testset "Beer outputs are current rates unless explicitly integrated" begin
    @test output_policy(Beer(0.5)) == NamedTuple()
    @test output_policy(BeerShortwave(0.5)) == NamedTuple()

    rate_weather = Weather([
        Atmosphere(
            T=20.0,
            Wind=1.0,
            P=101.3,
            Rh=0.65,
            Ri_PAR_f=100.0,
            Ri_NIR_f=50.0,
            duration=Hour(1),
        ),
        Atmosphere(
            T=20.0,
            Wind=1.0,
            P=101.3,
            Rh=0.65,
            Ri_PAR_f=200.0,
            Ri_NIR_f=80.0,
            duration=Hour(1),
        ),
    ])
    par_fraction = 1.0 - exp(-0.5 * 2.0)
    nir_fraction = 1.0 - exp(-0.48 * 2.0)
    expected_ppfd = [100.0, 200.0] .* par_fraction .* constants.J_to_umol
    expected_shortwave =
        [100.0, 200.0] .* par_fraction .+
        [50.0, 80.0] .* nir_fraction

    binding_scene = ground_rate_scene(rate_weather)
    compiled = Advanced.refresh_bindings!(binding_scene)
    bindings = [
        row for row in Diagnostics.explain_bindings(compiled)
        if row.application_id == :ground_probe &&
           row.input in (:aPPFD, :Ra_SW_f)
    ]
    @test length(bindings) == 2
    @test all(row.origin == :inferred_same_object for row in bindings)
    @test all(row.source_application_ids == [:canopy_light] for row in bindings)
    @test all(row.policy == HoldLast() for row in bindings)
    @test all(row.carrier_hint == :shared_ref for row in bindings)
    @test all(row.carrier_kind == :ref for row in bindings)
    @test all(row.copy_semantics == :live_references for row in bindings)
    @test all(row.has_reference_carrier for row in bindings)

    no_history_scene = ground_rate_scene(rate_weather)
    no_history = run!(
        no_history_scene;
        steps=2,
        constants=constants,
        outputs=:none,
    )
    no_history_status = final_state(no_history, :plant)
    @test no_history_status.aPPFD ≈ expected_ppfd[2]
    @test no_history_status.Ra_SW_f ≈ expected_shortwave[2]
    @test no_history_status.seen_aPPFD ≈ expected_ppfd[2]
    @test no_history_status.seen_Ra_SW_f ≈ expected_shortwave[2]
    @test isempty(Diagnostics.explain_output_retention(no_history))

    all_history_scene = ground_rate_scene(rate_weather)
    all_history = run!(
        all_history_scene;
        steps=2,
        constants=constants,
        outputs=:all,
    )
    @test last.(outputs(all_history)[
        (:canopy_light, ObjectId(:plant), :aPPFD)
    ]) ≈ expected_ppfd
    @test last.(outputs(all_history)[
        (:canopy_light, ObjectId(:plant), :Ra_SW_f)
    ]) ≈ expected_shortwave
    raw_retention = [
        row for row in Diagnostics.explain_output_retention(all_history)
        if row.application_id == :canopy_light &&
           row.variable in (:aPPFD, :Ra_SW_f)
    ]
    @test length(raw_retention) == 2
    @test all(row.reasons == (:all_outputs,) for row in raw_retention)
    @test all(:temporal_dependency ∉ row.reasons for row in raw_retention)

    request_scene = ground_rate_scene(rate_weather)
    requested = run!(
        request_scene;
        steps=2,
        constants=constants,
        outputs=[
            OutputRequest(
                One(scale=:Plant),
                :aPPFD;
                name=:absorbed_photon_fluence,
                application=:canopy_light,
                policy=Integrate(PlantMeteo.DurationSumReducer()),
                clock=ClockSpec(2.0, 2.0),
            ),
            OutputRequest(
                One(scale=:Plant),
                :Ra_SW_f;
                name=:absorbed_shortwave_energy,
                application=:canopy_light,
                policy=Integrate(PlantMeteo.RadiationEnergy()),
                clock=ClockSpec(2.0, 2.0),
            ),
        ],
    )
    @test only(collect_outputs(
        requested,
        :absorbed_photon_fluence;
        sink=nothing,
    )).value ≈ sum(expected_ppfd) * 3600.0
    @test only(collect_outputs(
        requested,
        :absorbed_shortwave_energy;
        sink=nothing,
    )).value ≈ sum(expected_shortwave) * 3600.0e-6
end

@testset "Mean-leaf adapters require finite positive LAI" begin
    for invalid_lai in (0.0, -1.0, Inf, -Inf, NaN)
        ppfd_status = Status(
            LAI=invalid_lai,
            aPPFD_ground=1000.0,
            aPPFD_leaf_mean=-Inf,
        )
        @test_throws DomainError PlantSimEngine.run!(
            GroundToMeanLeafPPFD(),
            ppfd_status,
            nothing,
            constants,
            nothing,
        )

        shortwave_status = Status(
            LAI=invalid_lai,
            Ra_SW_f_ground=100.0,
            Ra_SW_f_leaf_mean=-Inf,
        )
        @test_throws DomainError PlantSimEngine.run!(
            GroundToMeanLeafShortwave(),
            shortwave_status,
            nothing,
            constants,
            nothing,
        )
    end

    for invalid_radiation in (-1.0, Inf, -Inf, NaN)
        @test_throws DomainError PlantSimEngine.run!(
            GroundToMeanLeafPPFD(),
            Status(
                LAI=2.0,
                aPPFD_ground=invalid_radiation,
                aPPFD_leaf_mean=-Inf,
            ),
            nothing,
            constants,
            nothing,
        )
        @test_throws DomainError PlantSimEngine.run!(
            GroundToMeanLeafShortwave(),
            Status(
                LAI=2.0,
                Ra_SW_f_ground=invalid_radiation,
                Ra_SW_f_leaf_mean=-Inf,
            ),
            nothing,
            constants,
            nothing,
        )
    end
end
