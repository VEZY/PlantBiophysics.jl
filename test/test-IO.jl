

file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "models", "plant_coffee.yml")

@testset "read_model()" begin
    model = read_model(file)

    @test all([haskey(model, i) for i in ["Metamer", "Leaf"]])

    model = model["Leaf"]
    @test typeof(model) <: Tuple{Vararg{AbstractModel}}
    @test typeof(model[1]) == Monteith{Float64,Int64}
    @test typeof(model[4]) == Medlyn{Float64}
    @test typeof(model[2]) == Translucent{Float64}
    @test typeof(model[3]) == Fvcb{Float64}

    @test model[4].g0 == -0.03
    @test model[4].g1 == 12.0

    @test model[2].transparency == 0.0
    @test model[2].optical_properties == σ(0.15, 0.9)

    @test model[3].VcMaxRef == 200.0 # Given in the file
    @test model[3].O₂ == 210.0 # Use default value
end;


@testset "read_walz()" begin
    absorptance = 0.85
    file_walz_gfs3000 = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "data", "P1F20129.csv")
    data_walz = read_walz(file_walz_gfs3000; abs=absorptance)
    required_names = [:Dₗ, :Cₐ, :Cᵢ, :A, :Gₛ, :Rh, :VPD, :T, :Tₗ, :P, :aPPFD]
    @test all(hasproperty(data_walz, name) for name in required_names) # All computed columns are available
    @test nrow(dropmissing(data_walz[:, required_names])) == nrow(data_walz) # No data is missing
    @test all(extrema(data_walz.T) .≈ (22.95, 28.08)) # Control that we are in °C
    @test all(extrema(data_walz.Rh) .≈ (0.3592, 0.7712)) # Control that we are in [0,1]
    @test data_walz.aPPFD[1] ≈ absorptance * data_walz.PARtop[1] # Control that we are in μmol m⁻² s⁻¹
end;

@testset "read_licor6400()" begin
    absorptance = 0.85
    file_licor6400 = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "data", "6400.csv")
    data_licor6400 = read_licor6400(file_licor6400; abs=absorptance)
    required_names = [:Dₗ, :Cₐ, :Cᵢ, :A, :Gₛ, :Rh, :VPD, :T, :Tₗ, :P, :aPPFD]
    @test all(hasproperty(data_licor6400, name) for name in required_names) # All computed columns are available
    @test nrow(dropmissing(data_licor6400[:, required_names])) == nrow(data_licor6400) # No data is missing
    @test all(extrema(data_licor6400.T) .≈ (29.83, 29.96)) # Control that we are in °C
    @test all(extrema(data_licor6400.Rh) .≈ (0.5215, 0.6498999999999999)) # Control that we are in [0,1]
    @test data_licor6400.aPPFD[1] ≈ absorptance * data_licor6400.PARi[1] # Control that we are in μmol m⁻² s⁻¹
end;

@testset "read_licor6800()" begin
    file_licor6800 = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "data", "6800.csv")
    data_licor6800 = read_licor6800(file_licor6800)
    required_names = [:Dₗ, :Cₐ, :Cᵢ, :A, :Gₛ, :Rh, :VPD, :T, :Tₗ, :P, :aPPFD]
    @test all(hasproperty(data_licor6800, name) for name in required_names) # All computed columns are available
    @test nrow(dropmissing(data_licor6800[:, required_names])) == nrow(data_licor6800) # No data is missing
    @test all(extrema(data_licor6800.T) .≈ (28.98541818, 29.02936)) # Control that we are in °C
    @test all(extrema(data_licor6800.Rh) .≈ (0.6477531371, 0.6501544731)) # Control that we are in [0,1]
end;



@testset "read_ciras4()" begin
    file_ciras4 = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "data", "ciras4.csv")
    data_ciras4 = read_ciras4(file_ciras4)
    required_names = [:Dₗ, :Cᵢ, :A, :Gₛ, :Rh, :VPD, :T, :Tₗ, :P, :aPPFD]
    @test all(hasproperty(data_ciras4, name) for name in required_names) # All computed columns are available
    @test nrow(dropmissing(data_ciras4[:, required_names])) == nrow(data_ciras4) # No data is missing
    @test all(extrema(data_ciras4.T) .≈ (24.173282745646993, 31.37502194789174)) # Control that we are in °C
    @test all(extrema(data_ciras4.Rh) .≈ (0.5516815549361279, 0.8500860468849767)) # Control that we are in [0,1]
end;