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
end
Base.length(c::H5CompoundDatasetCache) = length(c.buffer)
isfull(c::H5CompoundDatasetCache) = length(c) >= c.size

"""

Forces the cache to be written to the HDF5 file.

"""
function Base.flush(d::H5CompoundDataset)
    current_dims, _ = HDF5.get_extent_dims(d.dset)
    idx = first(current_dims)
    n = length(d.cache)
    HDF5.set_extent_dims(d.dset, (idx + n,))
    d.dset[idx+1:idx+n] = d.cache.buffer
    empty!(d.cache.buffer)
end

"""

A wrapper for an HDF5 file used in KM3NeT.

"""
struct H5File
    _h5f
    _datasets::Dict{String, H5CompoundDataset}

    function H5File(fname::AbstractString)
        h5f = h5open(fname, "cw")
        new(h5f, Dict{String, H5CompoundDataset}())
    end
end
function Base.close(f::H5File)
    for dset in values(f._datasets)
        flush(dset)
    end
    close(f._h5f)
end
function Base.write(f::H5File, path::AbstractString, data)
    write_dataset(f._h5f, path, data)
end

"""

Creates a one-dimensional compound dataset [`H5CompoundDataset`](@ref) of a
given type which can be extended one-by-one. The cache is used to accumulate
data and reduce the number of dataset extensions. Each time the cache is full,
the HDF5 dataset will be extended, the buffer written and cleared.

To force the writing, use [`flush`](@ref)
"""
function HDF5.create_dataset(f::H5File, path::AbstractString, ::Type{T}; cache_size=1000) where T
    dset = HDF5.create_dataset(f._h5f, path, T, ((0,), (-1,)); chunk=(100,))
    cache = H5CompoundDatasetCache(T[], cache_size)
    d = H5CompoundDataset(dset, cache)
    f._datasets[path] = d
    d
end
function Base.push!(d::H5CompoundDataset{T}, element::T) where T
    push!(d.cache.buffer, element)
    isfull(d.cache) && flush(d)
end
