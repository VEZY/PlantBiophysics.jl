m = ModelList(
    energy_balance=Monteith(),
    photosynthesis=Fvcb(),
    stomatal_conductance=Medlyn(0.0, 0.0011),
    status=(Rₛ=13.747, sky_fraction=1.0, d=0.03)
)

@testset "Single model dependency" begin
    # Should only return the type of model it depends on as a vector
    @test dep(m.models.energy_balance) == [AbstractAModel]
    @test dep(m.models.photosynthesis) == [AbstractGsModel]
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
