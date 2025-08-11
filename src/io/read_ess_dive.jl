"""
    read_ess_dive(file)

Import data from the ESS-DIVE database with the units and names corresponding to the ones used in PlantBiophysics.jl.

ESS-DIVE files are expected to have the following columns:

- `SampleID`: identifier for the sample
- `Record`: identifier for the record
- `A`: net photosynthesis rate (µmol m⁻² s⁻¹)
- `Ci`: intercellular CO2 concentration (ppm == µmol mol⁻¹)
- `CO2s`: CO2 concentration inside the leaf chamber (ppm)
- `gsw`: stomatal conductance to water vapor per leaf area (mmol m⁻² s⁻¹)
- `Patm`: atmospheric pressure (kPa)
- `Qin`: In-chamber photosynthetic flux density (PPFD) incident on the leaf (µmol m⁻² s⁻¹)
- `RHs`: relative humidity in the leaf chamber (%)
- `Tleaf`: leaf surface temperature (Celsius)

See here for more information: https://ess-dive.gitbook.io/leaf-level-gas-exchange/1a_definedvariables

# Arguments

- `file`: a string or a vector of strings containing the path to the file(s) to read.
- `abs=0.85`: the absorptance of the leaf. Default is 0.85 (von Caemmerer et al., 2009).

# Returns

A DataFrame containing the data read and transformed from the file(s). The units are the same than in the ESS-DIVE output file, 
except for:
- Dₗ: kPa
- Rh: fraction (0-1)
- VPD: kPa
- Gₛ: mol[CO₂] m⁻² s⁻¹

# Notes

Read the ESS dive paper here: https://www.sciencedirect.com/science/article/pii/S1574954121000236?via%3Dihub
Access the ESS-DIVE documentation here: https://ess-dive.gitbook.io/leaf-level-gas-exchange
Access the ESS-DIVE database here: https://data.ess-dive.lbl.gov/view/doi:10.15485/1659484

# References 

Ely K.S., Rogers A, Crystal-Ornelas R (2020). ESS-DIVE reporting format for leaf-level gas exchange data and metadata. Environmental Systems Science Data Infrastructure for a Virtual Ecosystem (ESS-DIVE), ESS-DIVE repository. Dataset. https://data.ess-dive.lbl.gov/datasets/doi:10.15485/1659484
Ely K.S. et al (2021). A reporting format for leaf-level gas exchange data and metadata. Ecological Informatics. Volume 61. https://doi.org/10.1016/j.ecoinf.2021.101232
"""
function read_ess_dive(file; abs=0.85)
    if typeof(file) <: Vector{T} where {T<:AbstractString}
        df = CSV.read(file, DataFrame, source=:source)
    else
        df = CSV.read(file, DataFrame)
    end

    # Renaming variables to fit the standard in the package:
    transform!(
        df,
        :gsw => :Gₛ, :CO2s => :Cₐ, :Tair => :T, :Patm => :P, :RHs => :Rh,
        :Qin => (x -> x .* abs) => :aPPFD, :Ci => :Cᵢ, :Tleaf => :Tₗ,
        :VPDleaf => :Dₗ
        # :A is already in the right format
    )

    # Recomputing the variables to match the units used in the package:
    df[!, :Rh] = df[!, :Rh] ./ 100.0 # Th is expected in % in ess-dive, we need 0-1 values
    transform!(
        df,
        [:T, :Rh] => ((T, Rh) -> PlantMeteo.vpd.(Rh, T)) => :VPD,
        :Gₛ => (x -> gsw_to_gsc.(x)) => :Gₛ,
    )
    return df
end