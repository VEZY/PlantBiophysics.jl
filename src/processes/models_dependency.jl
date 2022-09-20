mutable struct DependencyNode{T}
    value::T
    process::Symbol
    inputs::NamedTuple
    outputs::NamedTuple
    dependency::NamedTuple
    missing_dependency::Vector{Int}
    parent::Union{Nothing,DependencyNode}
    children::Vector{DependencyNode}
end

# function DependencyNode(value)
#     return DependencyNode(value, nothing, DependencyNode[])
# end

struct DependencyTree{T<:Union{DependencyNode,Dict{Symbol,<:DependencyNode}}}
    roots::T
    not_found::Dict{Symbol,DataType}
end

AbstractTrees.children(t::DependencyNode) = t.children
AbstractTrees.nodevalue(t::DependencyNode) = t.value # needs recent AbstractTrees
AbstractTrees.ParentLinks(::Type{<:DependencyNode}) = AbstractTrees.StoredParents()
AbstractTrees.parent(t::DependencyNode) = t.parent
AbstractTrees.printnode(io::IO, node::DependencyNode) = print(io, node.value)
Base.show(io::IO, t::DependencyNode) = AbstractTrees.print_tree(io, t)
Base.length(t::DependencyNode) = length(collect(AbstractTrees.PreOrderDFS(t)))

dep(::T) where {T<:AbstractModel} = NamedTuple()

"""
    dep(models::ModelList; verbose::Bool=true)

Get the model dependency tree given a ModelList. If one tree is returned, then all models are
coupled. If several trees are returned, then only the models inside each tree are coupled, and
the models in different trees are not coupled.
"""
function dep(; verbose::Bool=true, vars...)
    models = (; vars...)
    dep_tree = Dict(
        p => DependencyNode(
            typeof(i),
            p,
            inputs_(i),
            outputs_(i),
            NamedTuple(),
            Int[],
            nothing,
            DependencyNode[]
        ) for (p, i) in pairs(models)
    )
    dep_not_found = Dict{Symbol,DataType}()
    for (process, i) in pairs(models) # for each model in the model list
        level_1_dep = dep(i) # we get the dependencies of the model
        length(level_1_dep) == 0 && continue # if there is no dependency we skip the iteration
        dep_tree[process].dependency = level_1_dep
        for (p, depend) in pairs(level_1_dep) # for each dependency of the model i
            if hasproperty(models, p)
                if typeof(getfield(models, p)) <: depend
                    parent_dep = dep_tree[process]
                    push!(parent_dep.children, dep_tree[p])
                    for child in parent_dep.children
                        child.parent = parent_dep
                    end
                else
                    if verbose
                        @info string(
                            "Model ", typeof(i).name.name, " from process ", process,
                            " needs a model that is a subtype of ", depend, " in process ",
                            p
                        )
                    end

                    push!(dep_not_found, p => depend)

                    push!(
                        dep_tree[process].missing_dependency,
                        findfirst(x -> x == p, keys(level_1_dep))
                    ) # index of the missing dep
                    # NB: we can retreive missing deps using dep_tree[process].dependency[dep_tree[process].missing_dependency]
                end
            else
                if verbose
                    @info string(
                        "Model ", typeof(i).name.name, " from process ", process,
                        " needs a model that is a subtype of ", depend, " in process ",
                        p, ", but the process is not parameterized in the ModelList."
                    )
                end
                push!(dep_not_found, p => depend)

                push!(
                    dep_tree[process].missing_dependency,
                    findfirst(x -> x == p, keys(level_1_dep))
                ) # index of the missing dep
                # NB: we can retreive missing deps using dep_tree[process].dependency[dep_tree[process].missing_dependency]
            end
        end
    end

    roots = [AbstractTrees.getroot(i) for i in values(dep_tree)]
    # Keeping only the trees with no common root nodes, i.e. remove trees that are part of a
    # bigger dependency tree:
    unique_roots = Dict{Symbol,DependencyNode}()
    for (p, m) in dep_tree
        if m in roots
            push!(unique_roots, p => m)
        end
    end

    return DependencyTree(unique_roots, dep_not_found)
end

function dep(m::ModelList; verbose::Bool=true)
    dep(; verbose=verbose, m.models...)
end

function Base.show(io::IO, t::DependencyTree)
    draw_dependency_trees(io, t)
end

function draw_dependency_trees(
    io,
    trees::DependencyTree;
    title="Dependency tree",
    title_style::String=Term.TERM_THEME[].tree_title_style,
    guides_style::String=Term.TERM_THEME[].tree_guide_style,
    dep_tree_guides=(space=" ", vline="│", branch="├", leaf="└", hline="─")
)

    dep_tree_guides = map((g) -> Term.apply_style("{$guides_style}$g{/$guides_style}"), dep_tree_guides)

    tree_panel = []
    for (p, tree) in trees.roots
        node = []
        draw_dependency_tree(tree, node, dep_tree_guides=dep_tree_guides)
        push!(tree_panel, Term.Panel(node; fit=true, title=string(p), style="green dim"))
    end

    print(
        io,
        Term.Panel(
            tree_panel;
            fit=true,
            title="{$(title_style)}$(title){/$(title_style)}",
            style="$(title_style) dim"
        )
    )
end

"""
    draw_dependency_tree(
        tree, node;
        guides_style::String=TERM_THEME[].tree_guide_style,
        dep_tree_guides=(space=" ", vline="│", branch="├", leaf="└", hline="─")
    )

Draw the dependency tree.
"""
function draw_dependency_tree(
    tree, node;
    dep_tree_guides=(space=" ", vline="│", branch="├", leaf="└", hline="─")
)

    prefix = ""
    panel1 = Term.Panel(
        title="Root model",
        string(
            "Process: $(tree.process)\n",
            "Model: $(tree.value)",
            length(tree.missing_dependency) == 0 ? "" : string(
                "\n{red underline}Missing dependencies: ",
                join([tree.dependency[j] for j in tree.missing_dependency], ", "),
                "{/red underline}"
            )
        );
        fit=true,
        style="blue dim"
    )

    push!(node, prefix * panel1)

    draw_panel(node, tree, prefix, dep_tree_guides)
    return node
end

"""
    draw_panel(node, tree, prefix, dep_tree_guides)

Draw the panels for all dependencies
"""
function draw_panel(node, tree, prefix, dep_tree_guides)
    ch = AbstractTrees.children(tree)
    length(ch) == 0 && return # If no children, return
    is_leaf = [repeat([false], length(ch) - 1)..., true]

    for i in AbstractTrees.children(tree)
        prefix_c_length = 8 + length(prefix)
        panel_hright = repeat(" ", prefix_c_length)

        panel = Term.Panel(
            title="Coupled model",
            string(
                "Process: $(i.process)\n",
                "Model: $(i.value)",
                length(i.missing_dependency) == 0 ? "" : string(
                    "\n{red underline}Missing dependencies: ",
                    join([i.dependency[j] for j in i.missing_dependency], ", "),
                    "{/red underline}"
                )
            );
            fit=true,
            style="blue dim"
        )

        push!(
            node,
            draw_guide(
                panel.measure.h ÷ 2,
                3,
                panel_hright,
                popfirst!(is_leaf),
                dep_tree_guides
            ) * panel
        )
        draw_panel(node, i, panel_hright, dep_tree_guides)
    end
end

"""
    draw_guide(h, w, prefix, isleaf, guides)

Draw the line guide for one node of the dependency tree.
"""
function draw_guide(h, w, prefix, isleaf, guides)

    header_width = string(prefix, guides.vline, repeat(guides.space, w - 1), "\n")
    header = h > 1 ? repeat(header_width, h) : ""
    if isleaf
        return header * prefix * guides.leaf * repeat(guides.hline, w - 1)
    else
        footer = h > 1 ? header_width[1:end-1] : "" # NB: we remove the last \n
        return header * prefix * guides.branch * repeat(guides.hline, w - 1) * "\n" * footer
    end
end
