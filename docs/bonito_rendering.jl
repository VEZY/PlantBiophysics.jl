module BonitoRendering

using Bonito, Documenter

const Writer = Base.get_extension(Bonito, :BonitoDocumenterExt)
isnothing(Writer) && error("Load Documenter and Bonito before the documentation helpers")
hasmethod(Writer.build_search_index, Tuple{Any,Any}) || error(
    "Bonito's search API changed; review the documentation search adaptation",
)

const SearchEntry = NamedTuple{(:title, :text, :url),Tuple{String,String,String}}
const API_ENTRIES = Ref(SearchEntry[])

# Bonito 5.2 indexes page introductions and headings, but not individual
# docstrings. Keep its index and add every rendered API entry with its real
# Documenter anchor. A more-specific method leaves the upstream method intact.
function api_entries!(entries, node, source)
    if node.element isa Documenter.DocsNode
        docs = node.element
        text = join(Documenter.MDFlatten.mdflatten(ast) for ast in docs.mdasts)
        push!(entries, (
            title=string(docs.object.binding),
            text=first(text, 1500),
            url=Writer.html_from_source(source, Documenter.anchor_label(docs.anchor)),
        ))
    end
    for child in node.children
        api_entries!(entries, child, source)
    end
    return entries
end

function Writer.build_search_index(doc::Documenter.Document, flat::Vector{Writer.NavLink})
    entries = invoke(Writer.build_search_index, Tuple{Any,Any}, doc, flat)
    api = SearchEntry[]
    for (source, page) in sort!(collect(doc.blueprint.pages); by=first)
        api_entries!(api, page.mdast, source)
    end
    API_ENTRIES[] = api
    append!(entries, api)
    return entries
end

end
