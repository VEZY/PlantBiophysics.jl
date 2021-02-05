constants = Constants()


# Monteith, John L., et Mike H. Unsworth. 2013. « Chapter 13 - Steady-State Heat Balance: (i)
# Water Surfaces, Soil, and Vegetation ». In Principles of Environmental Physics (Fourth Edition),
# edited by John L. Monteith et Mike H. Unsworth, 217‑47. Boston: Academic Press.

# p 230:

# In Monteith and Unsworth (2013) p.230, they say at a standard pressure of 101.3 kPa,
# λ has a value of about 66 Pa K−1 at 0 ◦C increasing to 67 Pa K−1 at 20 ◦C:
@testset "Psychrometer constant" begin
    @test psychrometer_constant(0.0, 101.3) * 1000 ≈ 65.9651894869062 # in Pa K-1
    @test psychrometer_constant(20.0, 101.3) * 1000 ≈ 67.23680111943287 # in Pa K-1
end;


@testset "Psychrometer constant" begin
    @test psychrometer_constant(0.0, 101.3) * 1000 ≈ 65.9651894869062 # in Pa K-1
    @test psychrometer_constant(20.0, 101.3) * 1000 ≈ 67.23680111943287 # in Pa K-1
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
    @test net_longwave_radiation(526.85,226.85000000000002,0.2,0.7,1.0,constants.K₀,constants.σ) ≈ 3625.6066521315793
end;
