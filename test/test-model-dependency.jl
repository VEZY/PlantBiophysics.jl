m = ModelList(
    energy_balance=Monteith(),
    photosynthesis=Fvcb(),
    stomatal_conductance=Medlyn(0.0, 0.0011),
    status=(Rₛ=13.747, sky_fraction=1.0, d=0.03)
)

@testset "Single model dependency" begin
    # Should only return the type of model it depends on as a vector
    @test dep(m.models.energy_balance) == [AbstractPhotosynthesisModel]
    @test dep(m.models.photosynthesis) == [AbstractStomatal_ConductanceModel]
    @test dep(m.models.stomatal_conductance) == []
end

@testset "ModelList model dependency tree" begin
    # Should return the type of model it depends on as a dependency tree
    dep_tree = dep(m)
    dep_root = dep_tree.roots
    @test dep_root.value == typeof(m.models.energy_balance)
    @test dep_root.children[1].value == typeof(m.models.photosynthesis)
    @test dep_root.children[1].children[1].value == typeof(m.models.stomatal_conductance)

    @test dep_root.parent === nothing
    @test dep_root.children[1].parent === dep_root

    # All dependencies found in this case:
    @test dep_tree.not_found == DataType[]
end


@testset "ModelList dependency tree -> missing dep" begin
    # There is a missing dependency for the Monteith model:
    dep_tree = dep(ModelList(energy_balance=Monteith()))
    dep_root = dep_tree.root

    @test dep_root.value == typeof(m.models.energy_balance)
    @test dep_root.children == PlantBiophysics.DependencyNode[]
end

@testset "ModelList dependency tree -> missing dep with two models" begin
    # Two models are given, but still no photosynthesis is given:
    dep_tree = dep(ModelList(energy_balance=Monteith(), stomatal_conductance=Medlyn(0.0, 0.0011)))
    dep_root = dep_tree.root

    @test dep_root.value == typeof(m.models.energy_balance)
    @test dep_root.children[1].value == typeof(m.models.photosynthesis)
    @test dep_root.children[1].children[1].value == typeof(m.models.stomatal_conductance)

    @test dep_tree.parent === nothing
    @test dep_tree.children[1].parent === dep_tree
end


@testset "ModelList dependency tree printing" begin
    # Defining a dummy energy model that takes 2 dependencies:
    struct dummy_E{T} <: AbstractEnergy_BalanceModel
        A::T
    end
    PlantBiophysics.inputs_(::dummy_E) = (PPFD=-Inf, Tₗ=-Inf, Cₛ=-Inf)
    PlantBiophysics.outputs_(::dummy_E) = (A=-Inf, Gₛ=-Inf, Cᵢ=-Inf)
    PlantBiophysics.dep(::dummy_E) = (light_interception=AbstractLight_InterceptionModel, photosynthesis=AbstractPhotosynthesisModel)
    function PlantBiophysics.run!(::dummy_E, models, status, meteo, constants=Constants())
        return nothing
    end

    dep_tree = dep(ModelList(energy_balance=dummy_E(20.0), stomatal_conductance=Medlyn(0.0, 0.0011)))
    @test dep_tree.not_found == Dict{Symbol,DataType}(:light_interception => AbstractLight_InterceptionModel, :photosynthesis => AbstractPhotosynthesisModel)
    @test length(dep_tree.roots) == 2
    @test dep_tree.roots[:energy_balance].missing_dependency == Int[1, 2]
    @test dep_tree.roots[:energy_balance].dependency == (light_interception=AbstractLight_InterceptionModel, photosynthesis=AbstractPhotosynthesisModel)

    dep_tree_two_dep = dep(
        ModelList(
            light_interception=Beer(0.5),
            energy_balance=dummy_E(20.0),
            photosynthesis=Fvcb(),
            stomatal_conductance=Medlyn(0.0, 0.0011)
        )
    )

    @test dep_tree_two_dep.roots[:energy_balance].missing_dependency == Int[]
    @test dep_tree_two_dep.roots[:energy_balance].dependency == (
        light_interception=AbstractLight_InterceptionModel,
        photosynthesis=AbstractPhotosynthesisModel
    )
end
