
@testset "Atmosphere structure" begin
    forced_date = Dates.DateTime("2021-09-15T16:24:00.929")

    # Testing Atmosphere with some random values:
    @test Atmosphere(date = forced_date, T = 25, Wind = 5, Rh = 0.3) == Atmosphere{Float64,Dates.DateTime,Float64}(Dates.DateTime("2021-09-15T16:24:00.929"), 1.0, 25.0,
5.0, 101.325, 0.3, 400.0, 0.9540587244435038, 3.180195748145013, 2.2261370237015092, 1.1838896840018194, 2.441875e6, 0.06757907523556121, 0.5455578187331258, 0.19009500927530176, 9999.9, 9999.9, 9999.9, 9999.9, 9999.9, 9999.9)

    # Testing Rh with values given in %:
    @test_logs (:warn, "Rh should be 0 < Rh < 1, assuming it is given in % and dividing by 100") Atmosphere(T = 25, Wind = 5, Rh = 30)
    # Testing Rh with values given with wrong value:
    @test_logs (:error, "Rh should be 0 < Rh < 1, and its value is 300") Atmosphere(T = 25, Wind = 5, Rh = 300)

    test_met = Atmosphere(T = 25, Wind = 5, Rh = 30)
    @test test_met.Rh == 0.3
end;
