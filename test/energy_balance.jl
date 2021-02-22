constants = Constants()


# Monteith, John L., et Mike H. Unsworth. 2013. « Chapter 13 - Steady-State Heat Balance: (i)
# Water Surfaces, Soil, and Vegetation ». In Principles of Environmental Physics (Fourth Edition),
# edited by John L. Monteith et Mike H. Unsworth, 217‑47. Boston: Academic Press.

# p 230:

# In Monteith and Unsworth (2013) p.230, they say at a standard pressure of 101.3 kPa,
# λ has a value of about 66 Pa K−1 at 0 ◦C increasing to 67 Pa K−1 at 20 ◦C:
@testset "Psychrometer constant" begin
    λ₀ = latent_heat_vaporization(0.0, constants.λ₀)
    @test psychrometer_constant(101.3,λ₀) * 1000 ≈ 65.9651894869062 # in Pa K-1
    λ₂₀ = latent_heat_vaporization(20.0, constants.λ₀)
    @test psychrometer_constant(101.3,λ₂₀) * 1000 ≈ 67.23680111943287 # in Pa K-1
end;

@testset "Black body" begin
    # Testing that both calls return the same value with default parameters:
    @test black_body(25.0, constants.K₀, constants.σ) == black_body(25.0)
    @test black_body(25.0, constants.K₀, constants.σ) ≈ 448.07517457669354 # checked
end;


@testset "grey body" begin
    # Testing that both calls return the same value with default parameters:
    @test grey_body(25.0, 0.96, constants.K₀, constants.σ) == grey_body(25.0, 0.96)
    @test grey_body(25.0, 0.96, constants.K₀, constants.σ) ≈ 430.1521675936258
end;


@testset "Rₗₗ" begin
    # Testing that both calls return the same value with default parameters:
    @test net_longwave_radiation(25.0,20.0,0.955,1.0,1.0,constants.K₀,constants.σ) ==
            net_longwave_radiation(25.0,20.0,0.955,1.0,1.0)
    # Example from Cengel (2003), Example 12-7 (p. 627):
    # Cengel, Y, et Transfer Mass Heat. 2003. A practical approach. New York, NY, USA: McGraw-Hill.
    @test net_longwave_radiation(526.85,226.85000000000002,0.2,0.7,1.0,constants.K₀,constants.σ) ≈ -3625.6066521315793
    # NB: we compute it opposite (negative when energy is lost, positive for a gain)
end;



@testset "energy_balance(Leaf{.,Monteith{Float64,Int64},Fvcb{Float64},Medlyn{Float64},.})" begin
    # Reference value:
    ref = (Tₗ = 17.683040276741586, Rn = 21.192838205401863,
        Cₛ = 348.98760802257027, H = -120.2353875816707, λE = 141.42822578707253,
        A = 34.27207394773156, Gₛ = 1.4261995419918079, Cᵢ = 325.51680897777874,
        Gbₕ = 0.02133679097176768, Dₗ = 0.8214484239448965, Rₗₗ = 7.445838205401865,
        Gbc = 0.6718382067419053)

    meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
    leaf = Leaf(energy = Monteith(),
                photosynthesis = Fvcb(),
                stomatal_conductance = Medlyn(0.03, 12.0),
                Rn = 13.747, skyFraction = 1.0, PPFD = 1500.0, d = 0.03)

    non_mutating = energy_balance(leaf,meteo)

    for i in keys(ref)
        @test non_mutating[i] ≈ ref[i]
    end

    # Mutating the leaf:
    energy_balance!(leaf,meteo)
    for i in keys(ref)
        @test leaf.status[i] ≈ ref[i]
    end
end;
