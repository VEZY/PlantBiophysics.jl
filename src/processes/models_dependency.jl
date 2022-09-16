mutable struct DependencyNode{T}
    value::T
    inputs::NamedTuple
    outputs::NamedTuple
    parent::Union{Nothing,DependencyNode}
    children::Vector{DependencyNode}
end

function DependencyNode(value)
    return DependencyNode(value, nothing, DependencyNode[])
end

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

dep(::T) where {T<:AbstractModel} = DataType[]

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
            inputs_(i),
            outputs_(i),
            nothing,
            DependencyNode[]
        ) for (p, i) in pairs(models)
    )
    dep_not_found = Dict{Symbol,DataType}()
    for (process, i) in pairs(models) # for each model in the model list
        level_1_dep = dep(i) # we get the dependencies of the model
        length(level_1_dep) == 0 && continue # if there is no dependency we skip the iteration
        for j in level_1_dep # for each dependency of the model i
            n_dep_found = 0
            dep_found = Dict{Symbol,DataType}()
            for (p, k) in pairs(models) # for each model in the model list again
                if typeof(k) <: j # we check if the dependency is in the model list
                    parent_dep = dep_tree[process]
                    push!(parent_dep.children, dep_tree[p])
                    for child in parent_dep.children
                        child.parent = parent_dep
                    end
                    n_dep_found += 1
                    push!(dep_found, p => j)
                end
            end
            if length(dep_found) == 0
                if verbose
                    @info string(
                        "Model ", typeof(i).name.name, " from process ", process,
                        " needs dependency ", j, ", but it is not found in the model list.")
                end
                push!(dep_not_found, process => j)
            end

            if length(dep_found) > 1 && verbose
                @info string(
                    "Cannot build dependency tree properly because models from ",
                    "different processes match dependency criteria ", j, " found in process",
                    process, "(model:", typeof(i).name.name, "): ", join(dep_found, ", "), "."
                )
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

# AbstractTrees.printnode(io::IO, node::DependencyTree) = print(io, "#", node.value)
function Base.show(io::IO, t::DependencyTree)
    print(io, "Dependency tree:\n")
    for (p, it) in t.roots
        print(io, string("Process ", p, ": \n"))
        AbstractTrees.print_tree(io, it)
    end

    if length(t.not_found) > 0
        print(io, "Dependency not found for:\n")
        for (p, dep) in t.not_found
            print(io, string("Process ", p, ": ", dep))
        end
    end
end
