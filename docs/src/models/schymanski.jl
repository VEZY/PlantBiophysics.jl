# Regenerate only the Schymanski et al. (2017) evaluation figure.
#
# Run from the repository root with:
#   julia --project=docs docs/src/models/schymanski.jl
#
# The simulation scenario remains shared with the regression tests, and the
# plotting logic remains shared with the complete documentation figure
# generator, so this entry point cannot drift from the evaluation page.

generator = normpath(
    joinpath(@__DIR__, "..", "..", "figures", "generate_evaluation_figures.jl"),
)
include(generator)

output = EvaluationFigures.generate_schymanski_figure()
@info "Generated the Schymanski evaluation figure" output
