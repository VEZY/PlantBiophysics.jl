module SteadyHydraulicsTests

using Test, Dates
using PlantBiophysics, PlantSimEngine, PlantMeteo
const PB = PlantBiophysics

# Independent prescribed-flux oracle. It is an ordinary composable energy
# model; the hydraulic controller still exercises public PSE calls/writers.
struct PrescribedLeafWaterFlux{T} <: PB.AbstractEnergy_BalanceModel
    flux::T
end
PlantSimEngine.inputs_(::PrescribedLeafWaterFlux) = (Ψₗ=Required(Real),)
PlantSimEngine.outputs_(m::PrescribedLeafWaterFlux) = (λE=zero(m.flux),)
PlantSimEngine.environment_inputs_(::PrescribedLeafWaterFlux) = (λ=2.45e6,)
PlantSimEngine.variable_contracts_(::PrescribedLeafWaterFlux) = (
    Ψₗ=PB.WATER_POTENTIAL_CONTRACT,
)
function PlantSimEngine.run!(m::PrescribedLeafWaterFlux, status, environment,
    constants, context)
    status.λE = m.flux * environment.λ * constants.Mₕ₂ₒ
    return nothing
end

function hydraulic_scene(; K_plant=0.01, Ψ_soil=0.0,
    leaves=((id=:leaf1, area=0.4, height=0.8),),
    energy=PrescribedLeafWaterFlux(0.005), photosynthesis=nothing,
    stomata=nothing)
    environment = Atmosphere(T=28.0, Wind=0.4, P=101.3, Rh=0.65,
        Cₐ=410.0, ε=1.0, duration=Minute(5))
    objects = Any[Object(:plant; scale=:Plant, kind=:plant, status=Status(; Ψ_soil))]
    for leaf in leaves
        push!(objects, Object(leaf.id; scale=:Leaf, kind=:leaf, parent=:plant,
            status=Status(leaf_area=leaf.area, leaf_height=leaf.height,
                Ra_SW_f=175.0, aPPFD=800.0, sky_fraction=2.0, d=0.04)))
    end
    applications = Any[
        ModelSpec(SteadyPlantHydraulics(; K_plant); name=:plant_hydraulics,
            on=One(scale=:Plant), outputs_to=(OutputTo(Many(scale=:Leaf, within=Subtree())),)),
        ModelSpec(HydraulicLeafEnergy(); name=:leaf_hydraulics, on=Many(scale=:Leaf)),
        ModelSpec(energy; name=:energy_balance, on=Many(scale=:Leaf)),
    ]
    if !isnothing(photosynthesis)
        push!(applications, ModelSpec(photosynthesis; name=:photosynthesis,
            on=Many(scale=:Leaf)))
    end
    if !isnothing(stomata)
        push!(applications, ModelSpec(stomata; name=:stomatal_conductance,
            on=Many(scale=:Leaf)))
    end
    return CompositeModel(objects...; applications=Tuple(applications), environment)
end

function plant_status(scene)
    return only(model_objects(scene; scale=:Plant)).status
end

@testset "Steady plant hydraulics" begin
    @testset "Numerical balance and numeric types" begin
        for T in (Float32, Float64)
            model = SteadyPlantHydraulics(K_plant=T(0.01))
            @test eltype(model) == T
            root = PB._solve_steady_hydraulics(model, T(-0.1), _ -> T(0.004))
            @test root.Ψ_base isa T
            @test root.Ψ_base ≈ T(-0.5) atol=4model.potential_tolerance
            @test root.supply ≈ T(0.004) atol=model.flux_tolerance
            @test abs(root.residual) <= model.flux_tolerance
            zero_flow = PB._solve_steady_hydraulics(model, T(-0.1), _ -> zero(T))
            @test zero_flow.Ψ_base == T(-0.1)
            @test zero_flow.supply == zero(T)
            @test zero_flow.iterations == 0
        end
        small = SteadyPlantHydraulics(K_plant=0.003f0)
        nonbinary = PB._solve_steady_hydraulics(small, -0.05f0, _ -> 0.001f0)
        @test nonbinary.Ψ_base isa Float32
        @test nonbinary.Ψ_base ≈ -0.05f0-0.001f0/0.003f0 atol=4small.potential_tolerance
        @test abs(nonbinary.residual) <= small.flux_tolerance
        large = SteadyPlantHydraulics(K_plant=1000f0)
        high_supply = PB._solve_steady_hydraulics(large, 0f0, _ -> 0.003f0)
        @test abs(high_supply.residual) <= large.flux_tolerance
        @test abs(high_supply.residual) < 1e-5 * high_supply.E_plant
        # Mixed-typed constructors must promote parameters and splat fields.
        tuzet = Tuzet(g0=0, g1=6.0, Ψᵥ=-1.5, sf=2, Γ=40)
        medlyn = Medlyn(g0=0, g1=6.0)
        @test eltype(tuzet) == Float64
        @test eltype(medlyn) == Float64
        @test tuzet.Γ == 40.0 && tuzet.sf == 2.0 && tuzet.g0 == 0.0
        @test_throws ArgumentError SteadyPlantHydraulics(K_plant=0.0)
        @test_throws ArgumentError SteadyPlantHydraulics(K_plant=Inf)
        @test_throws ArgumentError SteadyPlantHydraulics(K_plant=0.01, potential_tolerance=0.0)
        @test_throws ArgumentError SteadyPlantHydraulics(K_plant=0.01, maxiter=true)
        @test_throws ArgumentError HydraulicLeafEnergy(water_density=-1)
        @test_throws ArgumentError HydraulicLeafEnergy(gravity=-1)
        model = SteadyPlantHydraulics(K_plant=0.01)
        @test_throws ArgumentError PB._solve_steady_hydraulics(model, -10.0, _ -> 0.0)
        @test_throws DomainError PB._solve_steady_hydraulics(model, 0.0, _ -> -0.001)
        @test_throws DomainError PB._solve_steady_hydraulics(model, 0.0, _ -> Inf)
        @test_throws DomainError PB._solve_steady_hydraulics(model, 0.0, _ -> 100.0)
        too_short = SteadyPlantHydraulics(K_plant=0.01, maxiter=1)
        @test_throws ErrorException PB._solve_steady_hydraulics(too_short, 0.0, _ -> 0.004)
        # A discontinuous demand with no root eventually hits machine precision.
        # It must fail rather than silently clip to either side of the jump.
        discontinuous = SteadyPlantHydraulics(K_plant=0.01,
            potential_tolerance=eps(Float64)^2, flux_tolerance=eps(Float64)^2,
            maxiter=200)
        @test_throws ErrorException PB._solve_steady_hydraulics(discontinuous, 0.0,
            Ψ -> Ψ < -0.3 ? 0.001 : 0.01)
    end

    @testset "Closed-form one- and two-leaf balance, area and gravity" begin
        one = hydraulic_scene()
        run!(one)
        p = plant_status(one)
        leaf = only(model_objects(one; scale=:Leaf)).status
        @test p.E_plant ≈ 0.4*0.005
        @test p.Ψ_base ≈ -0.2 atol=1e-8
        @test leaf.Ψ_base_leaf ≈ p.Ψ_base
        @test leaf.Ψₗ ≈ p.Ψ_base-1000*9.80665*0.8/1e6
        @test leaf.E_leaf ≈ 0.005
        @test p.hydraulic_supply ≈ p.E_plant atol=1e-9
        @test abs(p.hydraulic_residual) <= 1e-9

        two = hydraulic_scene(leaves=((id=:sun, area=0.4, height=10.0),
            (id=:shade, area=0.2, height=0.0)))
        run!(two)
        p2 = plant_status(two)
        @test p2.E_plant ≈ 0.6*0.005
        @test p2.Ψ_base ≈ -0.3 atol=1e-8
        for object in model_objects(two; scale=:Leaf)
            st = object.status
            @test st.Ψₗ ≈ p2.Ψ_base-0.00980665*st.leaf_height
        end
        same_area = hydraulic_scene(leaves=((id=:whole, area=0.6, height=0.0),))
        run!(same_area)
        @test plant_status(same_area).Ψ_base ≈ p2.Ψ_base atol=1e-8

        dry = hydraulic_scene(Ψ_soil=-0.5)
        run!(dry)
        @test plant_status(dry).Ψ_base ≈ -0.7 atol=1e-8
    end

    @testset "Only accepted trials appear in retained output" begin
        scene = hydraulic_scene(leaves=((id=:a, area=0.4, height=1.0),
            (id=:b, area=0.2, height=0.0)))
        simulation = run!(scene; outputs=:all)
        rows = collect_outputs(simulation; sink=nothing)
        energies = [row for row in rows if row.application_id == :energy_balance && row.variable == :λE]
        potentials = [row for row in rows if row.application_id == :leaf_hydraulics && row.variable == :Ψₗ]
        @test length(energies) == 2
        @test length(potentials) == 2
        @test plant_status(scene).hydraulic_iterations > 1
        @test all(isapprox(row.value, 0.005*latent_heat_vaporization(28.0)*Constants().Mₕ₂ₒ) for row in energies)
    end

    @testset "Two plants keep independent supply and descendant leaves" begin
        environment = Atmosphere(T=25.0, Wind=1.0, Rh=0.6, duration=Minute(5))
        scene = CompositeModel(
            Object(:scene; scale=:Scene, kind=:scene),
            Object(:p1; scale=:Plant, kind=:plant, parent=:scene, status=Status(Ψ_soil=0.0)),
            Object(:p2; scale=:Plant, kind=:plant, parent=:scene, status=Status(Ψ_soil=-0.5)),
            Object(:l1; scale=:Leaf, kind=:leaf, parent=:p1,
                status=Status(leaf_area=0.4, leaf_height=1.0)),
            Object(:l2; scale=:Leaf, kind=:leaf, parent=:p2,
                status=Status(leaf_area=0.2, leaf_height=2.0));
            applications=(
                ModelSpec(SteadyPlantHydraulics(K_plant=0.01); name=:p1_water,
                    on=One(id=:p1), outputs_to=(OutputTo(Many(scale=:Leaf, within=Subtree())),)),
                ModelSpec(SteadyPlantHydraulics(K_plant=0.02); name=:p2_water,
                    on=One(id=:p2), outputs_to=(OutputTo(Many(scale=:Leaf, within=Subtree())),)),
                ModelSpec(HydraulicLeafEnergy(); name=:leaf_hydraulics, on=Many(scale=:Leaf)),
                ModelSpec(PrescribedLeafWaterFlux(0.005); name=:energy_balance, on=Many(scale=:Leaf)),
            ), environment)
        run!(scene)
        palms = model_objects(scene; scale=:Plant)
        @test sort([p.status.Ψ_base for p in palms]) ≈ [-0.55,-0.2] atol=1e-8
        @test sort([p.status.E_plant for p in palms]) ≈ [0.001,0.002]
    end

    @testset "Real Tuzet, photosynthesis and energy balance" begin
        stomata = Tuzet(g0=0.012, g1=6.0, Ψᵥ=-1.5, sf=2.0, Γ=40.0)
        function real_scene(K)
            hydraulic_scene(K_plant=K,
                leaves=((id=:sun,area=0.4,height=0.8),
                    (id=:shade,area=0.2,height=0.4)),
                energy=Monteith(maxiter=100, ΔT=1e-6),
                photosynthesis=Fvcb(VcMaxRef=70.,JMaxRef=120.,RdRef=.6,α=.32),
                stomata=stomata)
        end
        low, high = real_scene(0.001), real_scene(0.01)
        run!(low)
        run!(high)
        plow, phigh = plant_status(low), plant_status(high)
        @test plow.Ψ_base < phigh.Ψ_base < 0
        @test 0 < plow.E_plant < phigh.E_plant
        @test abs(plow.hydraulic_residual) <= 1e-9
        @test abs(phigh.hydraulic_residual) <= 1e-9
        # Exercise the newly ported transport/cuticle model in the same
        # hydraulic hard-call chain, rather than only the legacy FvCB solver.
        revised = hydraulic_scene(K_plant=0.003,
            leaves=((id=:sun,area=0.4,height=0.8),
                (id=:shade,area=0.2,height=0.4)),
            energy=Monteith(maxiter=100, ΔT=1e-6),
            photosynthesis=JohnsonBerryThermal(
                base=Fvcb(VcMaxRef=70.,JMaxRef=120.,RdRef=.6,α=.32),
                Cb6fMaxRef=90.0),
            stomata=CuticularConductance(stomata;gcw=0.005))
        run!(revised)
        @test abs(plant_status(revised).hydraulic_residual) <= 1e-9
        @test plant_status(revised).Ψ_base < 0
        for object in model_objects(revised; scale=:Leaf)
            st = object.status
            @test all(isfinite,(st.A,st.C꜀,st.Gₗw,st.Ψₗ,st.E_leaf_total))
            @test st.Gₗw ≈ Constants().Gsc_to_Gsw*st.Gₛ+0.005
        end
        for scene in (low, high), object in model_objects(scene; scale=:Leaf)
            st = object.status
            @test all(isfinite,(st.A,st.Tₗ,st.λE,st.Ψₗ,st.E_leaf_total))
            @test st.Ψₗ < plant_status(scene).Ψ_base
            @test abs(st.Rn-st.H-st.λE) <= 1e-6
        end
    end
end

end # module
