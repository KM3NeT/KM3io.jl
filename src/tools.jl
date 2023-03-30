"""
Return `true` if the n-th bit of `a` is set, `false` otherwise.
"""
nthbitset(n, a) = Bool((a >> n) & 1)


"""
$(METHODLIST)

Return `true` the 3D Muon trigger bit is set.
"""
is3dmuon(e::DAQEvent) = nthbitset(TRIGGER.JTRIGGER3DMUON, e.header.trigger_mask)
is3dmuon(x) = nthbitset(TRIGGER.JTRIGGER3DMUON, x)

"""
$(METHODLIST)

Return `true` if the 3D Shower trigger bit is set.
"""
is3dshower(e::DAQEvent) = nthbitset(TRIGGER.JTRIGGER3DSHOWER, e.header.trigger_mask)
is3dshower(x) = nthbitset(TRIGGER.JTRIGGER3DSHOWER, x)

"""
$(METHODLIST)

Return `true` if the MX Shower trigger bit is set.
"""
ismxshower(x) = nthbitset(TRIGGER.JTRIGGERMXSHOWER, x)
ismxshower(e::DAQEvent) = nthbitset(TRIGGER.JTRIGGERMXSHOWER, e.header.trigger_mask)

"""
$(METHODLIST)

Return `true` if the NanoBeacon trigger bit is set.
"""
isnb(x) = nthbitset(TRIGGER.JTRIGGERNB, x)
isnb(e::DAQEvent) = nthbitset(TRIGGER.JTRIGGERNB, e.header.trigger_mask)

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
julia> using NeRCA

julia> struct PMT
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
