# Steady water supply coupled to leaf gas exchange

`SteadyPlantHydraulics` finds the basal water potential at which water supplied
by the plant matches the summed transpiration of its leaves. Each trial calls
the existing leaf energy balance, photosynthesis and stomatal models. The
same objects and compiled model connections are reused throughout the solve.

The model makes two explicit assumptions:

```math
E_{plant} = K_{plant}(\Psi_{soil}-\Psi_{base}),
\qquad
\Psi_{leaf,i}=\Psi_{base}-\rho_w g h_i/10^6.
```

`K_plant` is a **whole-plant** conductance in mol H₂O s⁻¹ MPa⁻¹. A leaf's
transpiration is calculated from its latent heat flux and multiplied by its
reference area before summation. Gravity lowers water potential by
0.0980665 MPa at 10 m height. There is one basal potential and no separate
resistance for each branch or leaf.

This is an instantaneous water balance, with no water storage, capacitance,
embolism or soil-water dynamics. Soil water potential is an input: another
soil model or observations can supply it later. The minimum potential is a
root-finding bracket; the solver reports failure if it cannot balance supply
and demand within that bracket. It does not clip the potential to a limit.
Condensation is outside this daytime formulation and raises an error.

## A plant with two leaves

The numerical parameters below illustrate the coupling; they are not a
calibrated hydraulic parameterization. Start with a tight leaf energy solve,
because the outer water balance repeatedly evaluates its transpiration.

```@example steady_hydraulics
using PlantBiophysics, PlantMeteo, PlantSimEngine, Dates

weather = Atmosphere(T=28.0, Wind=0.4, P=101.3, Rh=0.65,
    Cₐ=410.0, ε=1.0, duration=Minute(5))
stomata = CuticularConductance(
    Tuzet(g0=0.012, g1=6.0, Ψᵥ=-1.5, sf=2.0, Γ=40.0);
    gcw=0.005,
)
photosynthesis = JohnsonBerryThermal(
    base=Fvcb(VcMaxRef=70.0, JMaxRef=120.0, RdRef=0.6, α=0.32),
    Cb6fMaxRef=90.0,
)

scene = CompositeModel(
    Object(:palm; scale=:Plant, kind=:plant, status=Status(Ψ_soil=-0.05)),
    Object(:sun; scale=:Leaf, kind=:leaf, parent=:palm,
        status=Status(leaf_area=0.4, leaf_height=0.8,
            Ra_SW_f=175.0, aPPFD=800.0, sky_fraction=2.0, d=0.04)),
    Object(:shade; scale=:Leaf, kind=:leaf, parent=:palm,
        status=Status(leaf_area=0.2, leaf_height=0.4,
            Ra_SW_f=65.0, aPPFD=300.0, sky_fraction=2.0, d=0.03));
    applications=(
        ModelSpec(SteadyPlantHydraulics(K_plant=0.003);
            name=:plant_hydraulics, on=One(scale=:Plant),
            outputs_to=(OutputTo(Many(scale=:Leaf, within=Subtree())),)),
        ModelSpec(HydraulicLeafEnergy(); name=:leaf_hydraulics, on=Many(scale=:Leaf)),
        ModelSpec(Monteith(maxiter=100, ΔT=1e-6);
            name=:energy_balance, on=Many(scale=:Leaf)),
        ModelSpec(photosynthesis; name=:photosynthesis, on=Many(scale=:Leaf)),
        ModelSpec(stomata; name=:stomatal_conductance, on=Many(scale=:Leaf)),
    ),
    environment=weather,
)

simulation = run!(scene; outputs=:all)
plant = only(model_objects(scene; scale=:Plant)).status
(Ψ_base=plant.Ψ_base, transpiration=plant.E_plant,
    supply=plant.hydraulic_supply, residual=plant.hydraulic_residual)
```

`Ψ_base_leaf` is a declared distributed output of the plant model. The
`OutputTo` destinations must be exactly the leaves selected by its hydraulic
hard call. Each `HydraulicLeafEnergy` computes and owns that leaf's `Ψₗ`,
which the Tuzet stomatal model consumes. Several plants can use the same
application definitions: `Subtree()` keeps each supply balance inside its own
plant.

All leaf areas refer to the same surface basis as the energy model's `λE`.
Do not multiply area by two merely because a leaf has two faces: Monteith's
`aₛᵥ` already controls vapour-exchanging surfaces. `leaf_height` is measured
above the root base, in metres.

## Meteorology and accepted outputs

Put leaf-specific microclimate bindings on `HydraulicLeafEnergy`. The bridge
forwards its sampled atmosphere to the energy model, so the latent heat flux
and its conversion to molar water flux use the same local conditions. A
custom energy model must accept this Monteith-compatible weather interface
and be responsible for its own convergence guarantee. Monteith trials are
checked for iteration exhaustion, finite fluxes and energy closure.

The plant calls its leaves with publication disabled during bisection. After
convergence, it runs the leaves once at the accepted potential and enables
publication. PlantSimEngine propagates the ancestor's publication permission
through nested calls: even though the leaf bridge requests publication from
the energy model, no intermediate energy or photosynthesis trial is exported.
The energy model remains the accepted writer of its usual full output set;
the bridge adds `Ψₗ`, `E_leaf` and `E_leaf_total`.

`hydraulic_residual` is the accepted supply minus transpiration, in mol H₂O
s⁻¹. It must satisfy the stated absolute flux tolerance. If the final energy
reevaluation changes demand beyond that tolerance, the run fails; tighten the
energy convergence settings before interpreting results. Float32 potential
tolerances account for machine precision, while the absolute water-balance
tolerance is preserved. A poorly represented tiny hydraulic head can require
Float64 rather than a relaxed water balance.

The supplied tests check closed-form one- and two-leaf balances, area and
gravity, separate plants, errors, numeric precision, accepted-output
publication, and actual Tuzet–photosynthesis–Monteith coupling. These are
implementation checks; hydraulic parameters and physiological predictions
still require experimental evaluation.
