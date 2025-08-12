"""
    read_ess_dive(file; abs=0.85, column_names_start=1, data_start=column_names_start + 1, kwargs...)

Import data from the ESS-DIVE database with the units and names corresponding to the ones used in PlantBiophysics.jl.

# Arguments

- `file`: a string or a vector of strings containing the path to the file(s) to read.
- `abs=0.85`: the absorptance of the leaf. Default is 0.85 (von Caemmerer et al., 2009).
- `column_names_start=1`: the row number to start reading column names from. Default is 1.
- `data_start=column_names_start+1`: the row number to start reading data from. Default is 2 (`column_names_start+1`).
- `kwargs...`: additional keyword arguments to pass to the CSV reader (*e.g.*, `decimal=','`).

# Details

ESS-DIVE files are expected to have the following columns:

- `SampleID`: identifier for the sample
- `Record`: identifier for the record
- `A`: net photosynthesis rate (µmol m⁻² s⁻¹)
- `Ci`: intercellular CO2 concentration (ppm == µmol mol⁻¹)
- `CO2s`: CO2 concentration inside the leaf chamber (ppm)
- `gsw`: stomatal conductance to water vapor per leaf area (mmol m⁻² s⁻¹)
- `Patm`: atmospheric pressure (kPa)
- `Qin`: In-chamber photosynthetic flux density (PPFD, µmol m⁻² s⁻¹) incident on the leaf, **not absorbed**
- `RHs`: relative humidity in the leaf chamber (%)
- `Tleaf`: leaf surface temperature (Celsius)

See here for more information: https://ess-dive.gitbook.io/leaf-level-gas-exchange/1a_definedvariables

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
function read_ess_dive(file; abs=0.85, column_names_start=1, data_start=column_names_start + 1, kwargs...)
    df = read_file(file; column_names_start=column_names_start, data_start=data_start, kwargs...)
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