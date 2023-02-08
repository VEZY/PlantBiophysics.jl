# To make the reference values again:
function make_ref(leaf)
    merged_dict = Dict()
    for i in keys(status(leaf))
        push!(merged_dict, i => [j[i] for j in status(leaf)])
    end
    return (; merged_dict...)
end

@testset "One time step status + Atmosphere" begin
    # Reference value (use make_ref(leaf) to update):
    ref = (
        Dₗ=[0.5021715623565368],
        Tₗ=[17.659873993789848],
        Rn=[21.266393383716945],
        Cᵢ=[337.0202128385702],
        Cₛ=[356.330207843304],
        d=[0.03],
        PPFD=[1500.0],
        A=[29.35278783520552],
        sky_fraction=[1.0],
        Rₛ=[13.747],
        λE=[142.76456451000684],
        Rₗₗ=[7.5193933837169435],
        iter=[2],
        H=[-121.49817112628988],
        Gₛ=[1.506586807729961],
        Gbc=[0.6721531380291846],
        Gbₕ=[0.021346792818908434]
    )

    meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65)
    leaf = ModelList(
        energy_balance=Monteith(),
        photosynthesis=Fvcb(),
        stomatal_conductance=Medlyn(0.03, 12.0),
        status=(Rₛ=13.747, sky_fraction=1.0, PPFD=1500.0, d=0.03)
    )

    run!(leaf, meteo)
    for i in keys(ref)
        @test leaf[i] ≈ ref[i][1]
    end
end

@testset "Two time step status + Atmosphere" begin
    # Reference value (use make_ref(leaf) to update):
    ref = (
        Dₗ=[0.4971967247887157, 0.5021715623565368],
        Tₗ=[17.620920554013832, 17.659873993789848],
        Rn=[17.568517340824783, 21.266393383716945],
        Cᵢ=[337.11579838230546, 337.0202128385702],
        Cₛ=[356.3923101667511, 356.330207843304],
        d=[0.03, 0.03],
        PPFD=[1500.0, 1500.0],
        A=[29.333909788282266, 29.35278783520552],
        sky_fraction=[0.5, 1.0],
        Rₛ=[13.747, 13.747],
        λE=[141.26139453771634, 142.76456451000684],
        Rₗₗ=[3.8215173408247853, 7.5193933837169435],
        iter=[2, 2],
        H=[-123.69287719689156, -121.49817112628988],
        Gₛ=[1.5125652369202054, 1.506586807729961],
        Gbc=[0.6726774543767848, 0.6721531380291846],
        Gbₕ=[0.021363444489205775, 0.021346792818908434]
    )

    meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65)
    leaf = ModelList(
        energy_balance=Monteith(),
        photosynthesis=Fvcb(),
        stomatal_conductance=Medlyn(0.03, 12.0),
        status=(Rₛ=13.747, sky_fraction=[0.5, 1.0], PPFD=1500.0, d=0.03)
    )

    run!(leaf, meteo)

    for i in keys(ref)
        @test all(isapprox.(leaf[i], ref[i], rtol=1e-10))
    end
end


@testset "Two time step status + Weather" begin
    # Reference value (use make_ref(leaf) to update):
    ref = (
        Dₗ=[0.4971967247887157, 0.6170383529946637],
        Tₗ=[17.620920554013832, 22.18582388627161],
        Rn=[17.568517340824783, 23.625527284092865],
        Cᵢ=[337.11579838230546, 332.4076725301661],
        Cₛ=[356.3923101667511, 353.4010193797825],
        d=[0.03, 0.03],
        PPFD=[1500.0, 1500.0],
        A=[29.333909788282266, 31.25727853897744],
        sky_fraction=[0.5, 1.0],
        Rₛ=[13.747, 13.747],
        λE=[141.26139453771634, 169.49292955280998],
        Rₗₗ=[3.8215173408247853, 9.878527284092865],
        iter=[2, 2],
        H=[-123.69287719689156, -145.86740226871711],
        Gₛ=[1.5125652369202054, 1.4684199787541639],
        Gbc=[0.6726774543767848, 0.670771723392939],
        Gbₕ=[0.021363444489205775, 0.021666265772813036]
    )

    meteo =
        Weather(
            [
            Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65),
            Atmosphere(T=25.0, Wind=1.0, P=101.3, Rh=0.65),
        ]
        )

    leaf = ModelList(
        energy_balance=Monteith(),
        photosynthesis=Fvcb(),
        stomatal_conductance=Medlyn(0.03, 12.0),
        status=(Rₛ=13.747, sky_fraction=[0.5, 1.0], PPFD=1500.0, d=0.03)
    )

    run!(leaf, meteo)

    for i in keys(ref)
        @test all(isapprox.(leaf[i], ref[i], rtol=1e-10))
    end
end
