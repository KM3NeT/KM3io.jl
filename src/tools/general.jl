"""
Return `true` if the n-th bit of `a` is set, `false` otherwise.
"""
nthbitset(n, a) = Bool((a >> n) & 1)


"""
Return the most frequent value of a given iterable.
"""
function most_frequent(iterable)
    d = Dict{eltype(iterable), Int}()
    for element ∈ iterable
        if haskey(d, element)
            d[element] += 1
        else
            d[element] = 1
        end
    end
    candidate = 0
    key = 0
    for (k, v) in d
        if v > candidate
            key = k
            candidate = v
        end
    end
    return key
end

"""
Return the most frequent value of a given iterable based on the return value
of a function `f` which returns (hashable) values of `rettype`.
"""
function most_frequent(f::Function, iterable; rettype=Int)
    d = Dict{rettype, Int}()
    for element ∈ iterable
        v = f(element)
        if haskey(d, v)
            d[v] += 1
        else
            d[v] = 1
        end
    end
    candidate = 0
    key = 0
    for (k, v) in d
        if v > candidate
            key = k
            candidate = v
        end
    end
    return key
end


"""
Categorise the struct elements of a vector by a given field into a dictionary of
`T.field => Vector{T}`.

# Examples

```
julia> using KM3io

julia> struct PMT  # just an ad-hoc PMT struct for demonstration purposes
         dom_id
         time
       end

julia> pmts = [PMT(2, 10.4), PMT(4, 23.5), PMT(2, 42.0)];

julia> categorize(:dom_id, pmts)
Dict{Any, Vector{PMT}} with 2 entries:
  4 => [PMT(4, 23.5)]
  2 => [PMT(2, 10.4), PMT(2, 42.0)]
```
"""
function categorize(field::Symbol, elements::Vector)
    _categorize(Val{field}(), elements)
end

"""
$(TYPEDSIGNATURES)
"""
function _categorize(field::Val{F}, elements::Vector{T}) where {T,F}
    out = Dict{fieldtype(T, F), Vector{T}}()
    for el ∈ elements
        key = getfield(el, F)
        if !haskey(out, key)
            out[key] = T[]
        end
        push!(out[key], el)
    end
    out
end


"""
Convert a string to a number-type if possible, otherwise return it back.
"""
function tonumifpossible(v::AbstractString)
    try
        return parse(Int, v)
    catch ArgumentError
    end
    try
        return parse(Float64, v)
    catch ArgumentError
    end
    v
end


"""
Convert UTCTime to DateTime
"""
Dates.DateTime(t::UTCTime) = unix2datetime(t.s + t.ns/1e9)
Dates.DateTime(e::Evt) = DateTime(e.t)
