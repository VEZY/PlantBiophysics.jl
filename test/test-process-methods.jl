function run_energy_case(; sky_fraction, meteo)
    scene = leaf_scene(
        Monteith(),
        Fvcb(α=0.24),
        Medlyn(0.03, 12.0);
        status=Status(
            Ra_SW_f=13.747,
            sky_fraction=sky_fraction,
            aPPFD=1500.0,
            d=0.03,
        ),
        environment=meteo,
    )
    run!(scene; constants=Constants())
    return leaf_status(scene)
end

function status_series(statuses, variable)
    return [status[variable] for status in statuses]
end

@testset "One leaf and one atmosphere" begin
    ref = (
        Dₗ=0.5021715623565368,
        Tₗ=17.659873993789848,
        Rn=21.266393383716945,
        Cᵢ=337.0202128385702,
        Cₛ=356.330207843304,
        A=29.35278783520552,
        λE=142.76456451000684,
        H=-121.49817112628988,
        Gₛ=1.506586807729961,
    )
    status = run_energy_case(
        sky_fraction=1.0,
        meteo=Atmosphere(
            T=20.0,
            Wind=1.0,
            P=101.3,
            Rh=0.65,
            duration=Hour(1),
        ),
    )
    for variable in keys(ref)
        @test status[variable] ≈ ref[variable] atol = 1e-2 rtol = 1e-2
    end
end

@testset "Several explicit leaf cases" begin
    meteo = (
        Atmosphere(
            T=20.0,
            Wind=1.0,
            P=101.3,
            Rh=0.65,
            duration=Hour(1),
        ),
        Atmosphere(
            T=25.0,
            Wind=1.0,
            P=101.3,
            Rh=0.65,
            duration=Hour(1),
        ),
    )
    statuses = [
        run_energy_case(; sky_fraction, meteo=meteo_row)
        for (sky_fraction, meteo_row) in zip((0.5, 1.0), meteo)
    ]
    @test status_series(statuses, :Tₗ) ≈
          [17.620920554013832, 22.18582388627161] atol = 1e-2
    @test status_series(statuses, :A) ≈
          [29.333909788282266, 31.25727853897744] atol = 1e-2
    @test status_series(statuses, :λE) ≈
          [141.26139453771634, 169.49292955280998] atol = 1e-2
end
