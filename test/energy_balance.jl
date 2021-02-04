
# Monteith, John L., et Mike H. Unsworth. 2013. « Chapter 13 - Steady-State Heat Balance: (i)
# Water Surfaces, Soil, and Vegetation ». In Principles of Environmental Physics (Fourth Edition),
# edited by John L. Monteith et Mike H. Unsworth, 217‑47. Boston: Academic Press.

# p 230:

# In Monteith and Unsworth (2013) p.230, they say at a standard pressure of 101.3 kPa,
# λ has a value of about 66 Pa K−1 at 0 ◦C increasing to 67 Pa K−1 at 20 ◦C:
@testset "Psychrometer constant" begin
    @test PlantBiophysics.psychrometer_constant(0.0, 101.3) * 1000 ≈ 65.9651894869062 # in Pa K-1
    @test PlantBiophysics.psychrometer_constant(20.0, 101.3) * 1000 ≈ 67.23680111943287 # in Pa K-1
end;
