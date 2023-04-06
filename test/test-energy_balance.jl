constants = Constants()

# Monteith, John L., et Mike H. Unsworth. 2013. « Chapter 13 - Steady-State Heat Balance: (i)
# Water Surfaces, Soil, and Vegetation ». In Principles of Environmental Physics (Fourth Edition),
# edited by John L. Monteith et Mike H. Unsworth, 217‑47. Boston: Academic Press.

# p 230:

# In Monteith and Unsworth (2013) p.230, they say at a standard pressure of 101.3 kPa,
# λ has a value of about 66 Pa K−1 at 0 ◦C increasing to 67 Pa K−1 at 20 ◦C:
@testset "Psychrometer constant" begin
    λ₀ = latent_heat_vaporization(0.0, constants.λ₀)
    @test psychrometer_constant(101.3, λ₀) * 1000 ≈ 65.9651894869062 # in Pa K-1
    λ₂₀ = latent_heat_vaporization(20.0, constants.λ₀)
    @test psychrometer_constant(101.3, λ₂₀) * 1000 ≈ 67.23680111943287 # in Pa K-1
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


@testset "Ra_LW_f" begin
    # Testing that both calls return the same value with default parameters:
    @test net_longwave_radiation(25.0, 20.0, 0.955, 1.0, 1.0, constants.K₀, constants.σ) ==
          net_longwave_radiation(25.0, 20.0, 0.955, 1.0, 1.0)
    # Example from Cengel (2003), Example 12-7 (p. 627):
    # Cengel, Y, et Transfer Mass Heat. 2003. A practical approach. New York, NY, USA: McGraw-Hill.
    @test net_longwave_radiation(526.85, 226.85000000000002, 0.2, 0.7, 1.0, constants.K₀, constants.σ) ≈ -3625.6066521315793
    # NB: we compute it opposite (negative when energy is lost, positive for a gain)
end;



@testset "run!" begin
    # Reference value:
    ref = (
        Ra_SW_f=13.747,
        sky_fraction=1.0,
        d=0.03,
        Tₗ=17.659815647954556,
        Rn=21.266578615169767,
        Ra_LW_f=7.519578615169768,
        H=-121.49772892068047,
        λE=142.76430753585024,
        Cₛ=356.3299120547146,
        Cᵢ=337.03262829972823,
        A=29.353021159302116,
        Gₛ=1.506555141119157,
        Gbₕ=0.021346817915286732,
        Dₗ=0.5021641028493964,
        Gbc=0.6721539282466927,
        iter=2,
        aPPFD=1500.0
    )

    meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65)
    leaf = ModelList(
        energy_balance=Monteith(),
        photosynthesis=Fvcb(),
        stomatal_conductance=Medlyn(0.03, 12.0),
        status=(Ra_SW_f=13.747, sky_fraction=1.0, aPPFD=1500.0, d=0.03)
    )

    run!(leaf, meteo)

    for i in keys(ref)
        @test leaf.status[i][1] ≈ ref[i]
    end
end;



# meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
# leaf = ModelList(
#     energy_balance = Monteith(),
#     photosynthesis = Fvcb(),
#     stomatal_conductance = Medlyn(0.03, 12.0),
#     status = (Ra_SW_f = 13.747, sky_fraction = 1.0, aPPFD = 1500.0, d = 0.03)
# )

# res = DataFrame(:aPPFD => Float64[], :A => Float64[])
# for i in 1:10:1500
#     leaf.status.aPPFD = i
#     run!(leaf, meteo)
#     push!(res, (aPPFD = leaf.status.aPPFD, A = leaf.status.A))
# end


# plot(res.aPPFD,res.A)
# ylabel!("A")
# xlabel!("aPPFD")


# Add tests for several components and/or several meteo time-steps (Weather)
