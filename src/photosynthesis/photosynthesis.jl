"""
Generic photosynthesis model for leaves. Computes the assimilation and stomatal conductance.
The models used are defined by the types of the `assimilation` and `conductance` fields of the `leaf`.
For exemple to use the implementation of the Farquhar–von Caemmerer–Berry (FvCB) model (see
[`assimiliation`](@ref)), the `leaf.assimilation` field should be of type [`Fvcb`](@ref).
"""
function photosynthesis(leaf::Leaf)
    assimiliation(leaf.assimilation, leaf.conductance)
end
