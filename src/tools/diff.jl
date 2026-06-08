"""

Recursive structural comparison of two objects.

`compare(a, b)` walks the two objects in parallel and returns a [`Diff`](@ref)
tree describing every difference. Containers are descended into using the
iteration protocol (so `compare` follows `for mod in detector` and
`for pmt in mod`), and elements are matched by identity (module id, PMT channel
id) rather than by position, which makes the result independent of storage
order. Anything that is not a registered container falls back to a generic
field-by-field comparison via `fieldnames`, so `compare` also works on `Evt`,
`Trk`, hits and any other struct.

The leaf/container boundary is controlled by [`difftrait`](@ref) and element
matching by [`diffkey`](@ref); both dispatch on type and can be extended for
user-defined types.

"""

# --- traits -----------------------------------------------------------------

"""
Marker returned by [`difftrait`](@ref) for values compared atomically.
"""
struct DiffLeaf end
"""
Marker returned by [`difftrait`](@ref) for structs compared field by field.
"""
struct DiffStruct end
"""
Marker returned by [`difftrait`](@ref) for iterable containers whose elements
are compared recursively and matched by [`diffkey`](@ref).
"""
struct DiffContainer end

"""
    difftrait(::Type) -> DiffLeaf() | DiffStruct() | DiffContainer()

Classify a type for [`compare`](@ref). The default treats any type with fields
as a `DiffStruct` (recursed via `fieldnames`) and any field-less type as a
`DiffLeaf` (compared atomically). Override to make a custom type behave as a
leaf or a container.
"""
difftrait(::Type{T}) where {T} = fieldcount(T) > 0 ? DiffStruct() : DiffLeaf()
difftrait(::Type{<:Number}) = DiffLeaf()
difftrait(::Type{<:AbstractChar}) = DiffLeaf()
difftrait(::Type{<:AbstractString}) = DiffLeaf()
difftrait(::Type{Symbol}) = DiffLeaf()
difftrait(::Type{<:Dates.AbstractTime}) = DiffLeaf()
difftrait(::Type{<:FieldVector}) = DiffLeaf()  # Position, Direction, Quaternion
difftrait(::Type{<:AbstractArray}) = DiffContainer()
difftrait(::Type{<:AbstractDict}) = DiffContainer()
difftrait(::Type{<:ZeroBasedAbstractArray}) = DiffContainer()
difftrait(::Type{Detector}) = DiffContainer()
difftrait(::Type{DetectorModule}) = DiffContainer()

"""
    diffkey(x) -> Any

Identity key used to match container elements across the two sides of a
[`compare`](@ref). Defaults to the `id` field when present (so `DetectorModule`s
match by module id and `PMT`s by DAQ channel id), otherwise `nothing`, which
falls back to positional matching.
"""
diffkey(x) = hasfield(typeof(x), :id) ? getfield(x, :id) : nothing

# The scalar metadata fields compared for container structs (the iterated
# collection and any purely derived bookkeeping are deliberately excluded).
_containerfields(::Type) = ()
_containerfields(::Type{Detector}) =
    (:version, :id, :validity, :pos, :lonlat, :utm_ref_grid, :n_modules, :strings, :comments)
_containerfields(::Type{DetectorModule}) =
    (:id, :pos, :location, :n_pmts, :q, :status, :t₀)

# --- result types -----------------------------------------------------------

"""
A single changed leaf field recorded at one node of a [`Diff`](@ref).

`kind` is `:value` for an exact (`==`) mismatch, `:float` for an `isapprox`
mismatch and `:type` when the two values have different types. `delta` holds the
magnitude of a numeric change (`abs(left - right)` for scalars, `norm(left .-
right)` for vectors such as `Position`) or `nothing` when not applicable.
"""
struct FieldChange
    field::Symbol
    left::Any
    right::Any
    kind::Symbol
    delta::Union{Nothing,Float64}
end

"""
The result of a [`compare`](@ref): a tree node holding the leaf differences at
this level (`changes`), the recursive sub-diffs of differing children
(`children`) and the element keys present on only one side (`onlyleft` /
`onlyright`). Only differing branches are kept; `same` is `true` when the whole
subtree is identical.

Use [`isidentical`](@ref) (or `isempty`) to test for equality and
[`ndiffs`](@ref) for the total number of differences.
"""
struct Diff
    label::String
    typename::String
    same::Bool
    changes::Vector{FieldChange}
    children::Vector{Diff}
    onlyleft::Vector{String}
    onlyright::Vector{String}
end

_emptydiff(label, typename, same) = Diff(label, typename, same, FieldChange[], Diff[], String[], String[])

"""
    isidentical(d::Diff) -> Bool

Return `true` if the diff tree carries no differences.
"""
isidentical(d::Diff) = d.same
Base.isempty(d::Diff) = d.same

"""
    ndiffs(d::Diff) -> Int

Total number of leaf differences in the tree (field changes plus elements
present on only one side), counted recursively.
"""
ndiffs(d::Diff) =
    length(d.changes) + length(d.onlyleft) + length(d.onlyright) +
    sum(ndiffs, d.children; init=0)

# --- labels -----------------------------------------------------------------

difflabel(d::Detector) = "Detector $(d.id)"
difflabel(m::DetectorModule) = sprint(show, m)  # e.g. "DOM(806451572, S001 F02)"
difflabel(p::PMT) = "PMT $(p.id)"
difflabel(x) = string(nameof(typeof(x)))

# --- leaf comparison --------------------------------------------------------

function _leafequal(l, r, opts)
    if l isa Number && r isa Number
        if l isa AbstractFloat || r isa AbstractFloat
            return (opts.nanequal && isnan(l) && isnan(r)) ||
                   isapprox(l, r; atol=opts.atol, rtol=opts.rtol)
        end
        return l == r
    elseif l isa AbstractArray && r isa AbstractArray
        return _approxarray(l, r, opts)
    end
    isequal(l, r)
end

function _approxarray(l, r, opts)
    length(l) == length(r) || return false
    for (x, y) in zip(l, r)
        ok = (opts.nanequal && isnan(x) && isnan(y)) ||
             isapprox(x, y; atol=opts.atol, rtol=opts.rtol)
        ok || return false
    end
    true
end

_leafkind(v) = (v isa AbstractFloat || v isa AbstractArray) ? :float : :value

function _leafdelta(l, r)
    if l isa AbstractFloat && r isa AbstractFloat
        return abs(l - r)
    elseif l isa AbstractArray && r isa AbstractArray && length(l) == length(r)
        return norm(float.(l) .- float.(r))
    end
    nothing
end

# --- engine -----------------------------------------------------------------

"""
    compare(a, b; atol=0.0, rtol=..., nanequal=true, maxdepth=64) -> Diff

Recursively compare `a` and `b` and return a [`Diff`](@ref) describing their
differences. `atol`/`rtol` are forwarded to `isapprox` for all floating point
and geometry fields (the default `rtol` matches Julia's `isapprox`). With
`nanequal=true`, two `NaN`s at the same position are treated as equal. Type and
shape mismatches never throw; they become nodes in the returned tree.

# Examples
```julia
d1 = Detector("KM3NeT_00000133_a.detx")
d2 = Detector("KM3NeT_00000133_b.detx")
diff = compare(d1, d2)
isidentical(diff) || show(diff)
```
"""
function compare(a, b; atol::Real=0.0, rtol::Real=(atol > 0 ? 0.0 : sqrt(eps())),
                 nanequal::Bool=true, maxdepth::Integer=64)
    opts = (atol=Float64(atol), rtol=Float64(rtol), nanequal=nanequal, maxdepth=Int(maxdepth))
    _diff(difflabel(a), a, b, opts, 0)
end

function _diff(label::AbstractString, a, b, opts, depth::Int)::Diff
    if typeof(a) !== typeof(b) && !(a isa Number && b isa Number)
        return Diff(label, "$(typeof(a)) / $(typeof(b))", false,
                    [FieldChange(:_value, a, b, :type, nothing)], Diff[], String[], String[])
    end
    if depth >= opts.maxdepth
        same = _leafequal(a, b, opts)
        changes = same ? FieldChange[] : [FieldChange(:_value, a, b, _leafkind(a), _leafdelta(a, b))]
        return Diff(label, string(typeof(a)), same, changes, Diff[], String[], String[])
    end
    _diff(difftrait(typeof(a)), label, a, b, opts, depth)
end

function _diff(::DiffLeaf, label, a, b, opts, depth)
    _leafequal(a, b, opts) && return _emptydiff(label, string(typeof(a)), true)
    Diff(label, string(typeof(a)), false,
         [FieldChange(:_value, a, b, _leafkind(a), _leafdelta(a, b))], Diff[], String[], String[])
end

function _diff(::DiffStruct, label, a, b, opts, depth)
    changes, children = _fieldpass(fieldnames(typeof(a)), a, b, opts, depth)
    same = isempty(changes) && isempty(children)
    Diff(label, string(typeof(a)), same, changes, children, String[], String[])
end

function _diff(::DiffContainer, label, a, b, opts, depth)
    changes, children = _fieldpass(_containerfields(typeof(a)), a, b, opts, depth)
    matched, onlyleft, onlyright = _pairup(a, b)
    for (clabel, ea, eb) in matched
        child = _diff(clabel, ea, eb, opts, depth + 1)
        child.same || push!(children, child)
    end
    same = isempty(changes) && isempty(children) && isempty(onlyleft) && isempty(onlyright)
    Diff(label, string(typeof(a)), same, changes, children, onlyleft, onlyright)
end

function _fieldpass(fields, a, b, opts, depth)
    changes = FieldChange[]
    children = Diff[]
    for f in fields
        av = getfield(a, f)
        bv = getfield(b, f)
        if typeof(av) !== typeof(bv) && !(av isa Number && bv isa Number)
            push!(changes, FieldChange(f, av, bv, :type, nothing))
        elseif difftrait(typeof(av)) isa DiffLeaf
            _leafequal(av, bv, opts) ||
                push!(changes, FieldChange(f, av, bv, _leafkind(av), _leafdelta(av, bv)))
        else
            child = _diff(string(f), av, bv, opts, depth + 1)
            child.same || push!(children, child)
        end
    end
    changes, children
end

# Match the elements of two containers, returning matched triples
# (label, left, right) and the labels present on only one side.
function _pairup(a, b)
    matched = Tuple{String,Any,Any}[]
    onlyleft = String[]
    onlyright = String[]
    if a isa AbstractDict
        for k in keys(a)
            haskey(b, k) ? push!(matched, ("[$k]", a[k], b[k])) : push!(onlyleft, "[$k]")
        end
        for k in keys(b)
            haskey(a, k) || push!(onlyright, "[$k]")
        end
        return matched, onlyleft, onlyright
    end
    av = collect(a)
    bv = collect(b)
    key = isempty(av) ? nothing : diffkey(first(av))
    if key !== nothing
        da = Dict(diffkey(x) => x for x in av)
        db = Dict(diffkey(x) => x for x in bv)
        for x in av
            k = diffkey(x)
            haskey(db, k) ? push!(matched, (difflabel(x), x, db[k])) : push!(onlyleft, difflabel(x))
        end
        for x in bv
            haskey(da, diffkey(x)) || push!(onlyright, difflabel(x))
        end
    else
        n = min(length(av), length(bv))
        for i in 1:n
            push!(matched, ("[$i]", av[i], bv[i]))
        end
        for i in n+1:length(av)
            push!(onlyleft, "[$i]")
        end
        for i in n+1:length(bv)
            push!(onlyright, "[$i]")
        end
    end
    matched, onlyleft, onlyright
end

# --- display ----------------------------------------------------------------

Base.show(io::IO, d::Diff) =
    print(io, "Diff(", d.label, ", ", ndiffs(d), ndiffs(d) == 1 ? " difference)" : " differences)")

function Base.show(io::IO, ::MIME"text/plain", d::Diff)
    if d.same
        print(io, "Diff: ", d.label, " (no differences)")
        return
    end
    n = ndiffs(d)
    println(io, "Diff: ", d.label, n == 1 ? " (1 difference)" : " ($n differences)")
    _shownode(io, d, 1)
end

function _shownode(io, d::Diff, depth)
    pad = "  "^depth
    for c in d.changes
        _showchange(io, c, pad)
    end
    for k in d.onlyleft
        println(io, pad, "- ", k, "   (only in left)")
    end
    for k in d.onlyright
        println(io, pad, "+ ", k, "   (only in right)")
    end
    for child in d.children
        println(io, pad, child.label)
        _shownode(io, child, depth + 1)
    end
end

function _showchange(io, c::FieldChange, pad)
    name = string(c.field)
    if c.kind == :type
        println(io, pad, name, ": ", _short(c.left), " ::", typeof(c.left),
                "  ->  ", _short(c.right), " ::", typeof(c.right))
    elseif c.left isa AbstractArray
        println(io, pad, name, ":")
        println(io, pad, "    < ", _short(c.left))
        print(io, pad, "    > ", _short(c.right))
        c.delta === nothing || print(io, "   (Delta ", _fmtdelta(c.delta), ")")
        println(io)
    else
        print(io, pad, name, ": ", _short(c.left), " -> ", _short(c.right))
        c.delta === nothing || print(io, "   (Delta ", _fmtdelta(c.delta), ")")
        println(io)
    end
end

_short(x) = sprint(show, x)
_fmtdelta(x) = @sprintf("%.3g", x)
