

# Importing the physical constants:
constants = Constants()

m = ModelList(light_interception=Beer(0.5), status=(LAI=2.0,))

meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0)

# Computing the light interception using the Beer-Lambert law:
@testset "Beer-Lambert" begin
    @test Beer <: AbstractLightModel
    light_interception!(m, meteo, constants)
    @test status(m).PPFD ≈ 504.3627138460475 # in μmol[PAR] m[leaf]⁻² s⁻¹
end;
