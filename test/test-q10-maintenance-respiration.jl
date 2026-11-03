module Q10MaintenanceRespirationTests

using Test, Dates
using PlantBiophysics, PlantSimEngine, PlantMeteo

PlantSimEngine.@process "respiration_temperature_fixture" verbose=false
PlantSimEngine.@process "respiration_rate_fixture" verbose=false
struct AlternatingOrganTemperature <: AbstractRespiration_Temperature_FixtureModel end
struct CoarseRespirationRate <: AbstractRespiration_Rate_FixtureModel end
PlantSimEngine.inputs_(::AlternatingOrganTemperature) = NamedTuple()
PlantSimEngine.outputs_(::AlternatingOrganTemperature) = (organ_temperature_C=25.0, temperature_calls=0)
PlantSimEngine.environment_inputs_(::AlternatingOrganTemperature) = NamedTuple()
PlantSimEngine.variable_contracts_(::AlternatingOrganTemperature) = (
    organ_temperature_C=VariableContract(unit=:degree_celsius,basis=:object,
        temporal=:instantaneous,aggregation=:state,extent=:intensive),)
function PlantSimEngine.run!(::AlternatingOrganTemperature,s,environment,constants,context=nothing)
    s.temperature_calls += 1
    s.organ_temperature_C = isodd(s.temperature_calls) ? 25.0 : 35.0
    return nothing
end
PlantSimEngine.inputs_(::CoarseRespirationRate) = (rate_in=Required(Real),)
PlantSimEngine.outputs_(::CoarseRespirationRate) = (mean_rate=0.0,)
PlantSimEngine.environment_inputs_(::CoarseRespirationRate) = NamedTuple()
PlantSimEngine.variable_contracts_(::CoarseRespirationRate) = (
    rate_in=VariableContract(unit=:g_ch2o_equivalent,basis=:object,
        temporal=:day,aggregation=:rate,extent=:extensive),
    mean_rate=VariableContract(unit=:g_ch2o_equivalent,basis=:object,
        temporal=:day,aggregation=:rate,extent=:extensive))
function PlantSimEngine.run!(::CoarseRespirationRate,s,environment,constants,context=nothing)
    s.mean_rate = s.rate_in
    return nothing
end

function rate_at(model, mass, temperature)
    s = Status(structural_mass_gDM=mass, organ_temperature_C=temperature,
        Rm_gCH2O_per_day_at_T=zero(model.Mr), Rm_CO2_umol_s=zero(model.Mr))
    run!(model, s, nothing, PlantMeteo.Constants(), nothing)
    return s
end

@testset "Q10 organ maintenance respiration" begin
    for T in (Float32, Float64)
        m = Q10MaintenanceRespiration(Q10=T(2), Mr=T(.002), T_ref=T(25), P_alive=T(.5))
        reference = rate_at(m, T(1000), T(25))
        warmer = rate_at(m, T(1000), T(35))
        cooler = rate_at(m, T(1000), T(15))
        @test eltype(m) == T
        @test reference.Rm_gCH2O_per_day_at_T isa T
        @test reference.Rm_CO2_umol_s isa T
        # Independent unit oracle: 1000g × 0.5 × .002 = 1 gCH2O/day;
        # divide by the molar mass, then by seconds/day, then convert mol→µmol.
        @test reference.Rm_gCH2O_per_day_at_T ≈ T(1)
        @test reference.Rm_CO2_umol_s ≈ T(1e6/30.026/86400)
        @test warmer.Rm_gCH2O_per_day_at_T ≈ T(2)
        @test cooler.Rm_gCH2O_per_day_at_T ≈ T(.5)
        half = rate_at(m, T(500), T(25))
        @test 2half.Rm_CO2_umol_s ≈ reference.Rm_CO2_umol_s
        @test rate_at(m,T(0),T(35)).Rm_CO2_umol_s == 0
        dead = Q10MaintenanceRespiration(Q10=T(2),Mr=T(.002),T_ref=T(25),P_alive=T(0))
        @test rate_at(dead,T(1000),T(35)).Rm_CO2_umol_s == 0
        # Six hours at the reference rate release .25g, not 1g per step.
        six_hour_release_g = reference.Rm_CO2_umol_s*T(21600)/T(1e6)*T(30.026)
        @test six_hour_release_g ≈ T(.25)
    end

    m = Q10MaintenanceRespiration(Q10=2.,Mr=.002,T_ref=25.,P_alive=.5)
    for mass in (-1.,NaN,Inf)
        @test_throws ArgumentError rate_at(m,mass,25.)
    end
    for temperature in (-273.15,NaN,Inf)
        @test_throws ArgumentError rate_at(m,1000.,temperature)
    end
    @test_throws ArgumentError Q10MaintenanceRespiration(Q10=0.,Mr=.002,T_ref=25.,P_alive=1.)
    @test_throws ArgumentError Q10MaintenanceRespiration(Q10=2.,Mr=-.002,T_ref=25.,P_alive=1.)
    @test_throws ArgumentError Q10MaintenanceRespiration(Q10=2.,Mr=.002,T_ref=-273.15,P_alive=1.)
    @test_throws ArgumentError Q10MaintenanceRespiration(Q10=2.,Mr=.002,T_ref=25.,P_alive=1.1)
    @test_throws ArgumentError Q10MaintenanceRespiration(Q10=2.,Mr=.002,T_ref=25.,P_alive=1.,grams_CH2O_per_mol_CO2=0.)
    explosive = Q10MaintenanceRespiration(Q10=1e100,Mr=.002,T_ref=25.,P_alive=1.)
    @test_throws DomainError rate_at(explosive,1000.,125.)

    @testset "Rates preserve their units across clocks" begin
        @test PlantMeteo.MeanWeighted()([1.,3.],[60.,180.]) == 2.5
        for duration in (Minute(5), Hour(1))
            scene = CompositeModel(m;
                status=Status(structural_mass_gDM=1000.,organ_temperature_C=25.),
                environment=Atmosphere(T=5.,Rh=.5,Wind=1.,duration=duration))
            run!(scene)
            s = only(model_objects(scene)).status
            @test s.Rm_gCH2O_per_day_at_T ≈ 1.
            @test s.Rm_CO2_umol_s ≈ 1e6/30.026/86400
        end

        # Exercise the actual compiled producer policy, not only its reducer:
        # changing organ temperature gives daily-equivalent rates 1,3,1,3.
        # A two-minute consumer must receive mean rate 2, not sum 4 or 240.
        model = CompositeModel(Object(:organ;scale=:Organ,
                status=Status(structural_mass_gDM=1000.));
            applications=(
                ModelSpec(AlternatingOrganTemperature();name=:temperature,
                    on=One(scale=:Organ),every=Minute(1)),
                ModelSpec(Q10MaintenanceRespiration(Q10=3.,Mr=.002,T_ref=25.,P_alive=.5);
                    name=:respiration,on=One(scale=:Organ),every=Minute(1),
                    inputs=(organ_temperature_C=One(within=Self(),
                        application=:temperature,var=:organ_temperature_C),)),
                ModelSpec(CoarseRespirationRate();name=:coarse,
                    on=One(scale=:Organ),every=Minute(2),
                    inputs=(rate_in=One(within=Self(),application=:respiration,
                        var=:Rm_gCH2O_per_day_at_T,window=Minute(2)),)),
            ),environment=[(duration=Minute(1),) for _ in 1:4])
        run!(model;steps=4,outputs=:all)
        s = only(model_objects(model)).status
        @test s.temperature_calls == 4
        @test s.mean_rate ≈ 2.
    end

    @testset "Respiration is explicit and does not subtract FvCB Rd twice" begin
        weather = Atmosphere(T=25.,Rh=.6,Wind=1.,P=101.3,Cₐ=400.,duration=Hour(1))
        leaf = Status(Tₗ=25.,aPPFD=600.,Cₛ=400.,Dₗ=1.,
            structural_mass_gDM=1000.,organ_temperature_C=25.)
        biochemistry = Fvcb(VcMaxRef=70.,JMaxRef=120.,RdRef=.6)
        with_respiration = CompositeModel(biochemistry,Medlyn(g0=.01,g1=5.5),m;
            status=leaf,environment=weather)
        without_respiration = CompositeModel(biochemistry,Medlyn(g0=.01,g1=5.5);
            status=Status(Tₗ=25.,aPPFD=600.,Cₛ=400.,Dₗ=1.),environment=weather)
        run!(with_respiration)
        run!(without_respiration)
        s = only(model_objects(with_respiration)).status
        @test s.A ≈ only(model_objects(without_respiration)).status.A
        @test s.Rm_CO2_umol_s > 0
        # The application explicitly subtracts nonleaf respiration after
        # matching its boundary and units. No automatic area conversion occurs.
        represented_leaf_area = 2.
        uptake = represented_leaf_area*s.A-s.Rm_CO2_umol_s
        @test uptake < represented_leaf_area*s.A
    end
end

end
