# Landing-page results

## Fitting curve

`generate_home_fitting.jl` regenerates `docs/src/assets/home-fitting.svg`
at each documentation build. It uses the same bundled WALZ measurements,
selection, and fitting procedure as the parameter-fitting tutorial:

- Source: `test/inputs/data/P1F20129.csv`.
- Exclude the `Rh Curve` and `ligth Curve` records, preserving the spelling
  in the source file; fit `Fvcb` with `Tᵣ=25.0` °C.
- Plot the CO₂-curve observations and predictions from `FvcbRaw` with the
  fitted parameters. Each prediction uses that row's measured leaf
  temperature, absorbed photon flux, and intercellular CO₂ concentration.
- The line joins predictions at the observed CO₂ concentrations. It does
  not interpolate the observations or introduce a synthetic response curve.
  Agreement with these fitting data is not an independent validation.

The helper checks row alignment and finite inputs, parameters, and results.
Run the normal documentation build through Kaimon to regenerate the figure.

## Archived oil-palm animation

`docs/src/assets/home-oil-palm-assimilation.mp4` reuses the animation supplied
by Rémi Vezy from the FSPM 2023 presentation. It is an archived scientific
result, not a simulation rerun with the current package version.

Original file, relative to the presentation's `code` directory:

```text
03-outputs/plantbiophysics_output/videos/Plant_5_2021_03_15_A.mp4
```

Original SHA-256:

```text
83de0bb34d47fb8c009f87afe1a25ddca615d69e322afc0460f24acb8b06ed41
```

The source is H.264, 1800 × 1000 pixels, 144 frames at 15 fps (9.6 seconds).
The bundled copy preserves the video stream and timing. Only the MP4
container is rearranged for playback before the download completes:

```sh
ffmpeg -i "$source_video" -map 0:v:0 -c:v copy -an -movflags +faststart home-oil-palm-assimilation.mp4
ffmpeg -ss 5.0 -i home-oil-palm-assimilation.mp4 -frames:v 1 -vf 'scale=1200:-2' home-oil-palm-assimilation.png
```

The PNG is the landing-page poster, extracted at 5 seconds. Both media files
are committed; building the documentation does not require the external
presentation folder or FFmpeg.

The presentation's `fspm_db.csv` associates this plant geometry with three
chamber experiments:

| Panel | Experiment date |
| --- | --- |
| 400 ppm | 2021-03-12 |
| Cloudy | 2021-03-13 |
| 600 ppm | 2021-03-14 |

The date in the geometry/video filename is not the experimental date.
The legacy driver, `simulations/01-evaluate_simulation.jl`, combines
`Monteith`, `Fvcb`, and `Medlyn` using fitted parameters and prescribed
light inputs. It aligns the three scenarios by rounded 10-minute clock
labels and holds the previous frame when a matching time is absent.

Leaf colours represent net CO₂ assimilation in µmol CO₂ m⁻² of leaf s⁻¹.
The lower traces show whole-plant CO₂ uptake in µmol CO₂ plant⁻¹ s⁻¹:
lines are simulations and points are chamber measurements. The title's
leaf-area units apply to the colour scale, not the whole-plant traces.
This animation shows assimilation, not carbon allocation or plant growth.
