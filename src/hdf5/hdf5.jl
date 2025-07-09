struct H5CompoundDatasetCache{T}
    buffer::Vector{T}
    size::Int
end

"""

A flat HDF5 compound dataset which is essentially a vector of structs. It has a
cache which is filled when elements are pushed to it. The cache is automatically
written to the target HDF5 path when full.

"""
struct H5CompoundDataset{T}
    dset::HDF5.Dataset
    cache::H5CompoundDatasetCache{T}
    _lock::ReentrantLock
end
Base.length(c::H5CompoundDatasetCache) = length(c.buffer)
isfull(c::H5CompoundDatasetCache) = length(c) >= c.size
HDF5.read_attribute(cdset::H5CompoundDataset, name::AbstractString) = HDF5.read_attribute(cdset.dset, name)

"""

Forces the cache to be written to the HDF5 file.

"""
function Base.flush(d::H5CompoundDataset; nolock=false)
    !nolock && lock(d._lock)
    current_dims, _ = HDF5.get_extent_dims(d.dset)
    idx = first(current_dims)
    n = length(d.cache)
    HDF5.set_extent_dims(d.dset, (idx + n,))
    d.dset[idx+1:idx+n] = d.cache.buffer
    empty!(d.cache.buffer)
    !nolock && unlock(d._lock)
    d
end

"""

A wrapper for an HDF5 file used in KM3NeT.

"""
struct H5File
    _h5f::HDF5.File
    _datasets::Dict{String, H5CompoundDataset}
    _lock::ReentrantLock

    function H5File(fname::AbstractString, mode::AbstractString="r")
        h5f = h5open(fname, mode)
        if mode != "r"
            if "KM3io.jl" ∈ keys(attrs(h5f))
                v = VersionNumber(attrs(h5f)["KM3io.jl"])
                v != version && @warn "The file '$fname' was created by a different version of KM3io.jl ($v). Modifying it might cause problems."
            else
                attrs(h5f)["KM3io.jl"] = string(version)
            end
        end
        new(h5f, Dict{String, H5CompoundDataset}(), ReentrantLock())
    end
end
function Base.flush(f::H5File)
    for dset in values(f._datasets)
        flush(dset)
    end
end
function Base.close(f::H5File)
    flush(f)
    close(f._h5f)
end
function Base.write(f::H5File, path::AbstractString, data)
    lock(f._lock)
    write_dataset(f._h5f, path, data)
    unlock(f._lock)
end
Base.getindex(f::H5File, args...) = getindex(f._h5f, args...)
HDF5.read_attribute(f::H5File, name::AbstractString) = HDF5.read_attribute(f._h5f, name)

"""

Creates a one-dimensional compound dataset [`H5CompoundDataset`](@ref) of a
given type which can be extended one-by-one. The cache is used to accumulate
data and reduce the number of dataset extensions. Each time the cache is full,
the HDF5 dataset will be extended, the buffer written and cleared.

To force the writing, use [`flush`](@ref)
"""
function HDF5.create_dataset(f::H5File, path::AbstractString, ::Type{T}; cache_size=10000, chunk=(10000,), filters=[Filters.Deflate(5)], kwargs...) where T
    lock(f._lock)
    dset = HDF5.create_dataset(f._h5f, path, T, ((0,), (-1,)); chunk=chunk, filters=filters, kwargs...)
    attrs(dset)["struct_name"] = string(nameof(T))
    cache = H5CompoundDatasetCache(T[], cache_size)
    d = H5CompoundDataset(dset, cache, f._lock)
    f._datasets[path] = d
    unlock(f._lock)
    d
end
function Base.push!(d::H5CompoundDataset{T}, element::T) where T
    lock(d._lock)
    push!(d.cache.buffer, element)
    isfull(d.cache) && flush(d; nolock=true)
    unlock(d._lock)
    d
end

"""

Attaches key-value-pair meta entries to an HDF5 instance for each field of the
given object.

"""
function addmeta(dset::Union{HDF5.Dataset, HDF5.File, HDF5.Group, HDF5.Datatype}, object::T) where T
    for fieldname in fieldnames(T)
        attributes(dset)[string(fieldname)] = getfield(object, fieldname)
    end
end
addmeta(cdset::H5CompoundDataset, object) = addmeta(cdset.dset, object)
addmeta(f::H5File, object) = addmeta(f._h5f, object)


struct H5uDST
    _h5f::H5File

    function H5uDST(filename::AbstractString; mode::AbstractString="r")
        return new(H5File(filename; mode=mode))
    end
end
