struct H5CompoundDatasetCache{T}
    buffer::Vector{T}
    size::Int
end
Base.length(c::H5CompoundDatasetCache) = length(c.buffer)
Base.size(c::H5CompoundDatasetCache) = (length(c),)
isfull(c::H5CompoundDatasetCache) = length(c) >= c.size

"""

A flat HDF5 compound dataset which is essentially a vector of structs. It has a
cache which is filled when elements are pushed to it. The cache is automatically
written to the target HDF5 path when full.

The actual reading and writing methods live in the `KM3ioHDF5Ext` package
extension and are only available once `HDF5` is loaded.

"""
struct H5CompoundDataset{T}
    dset
    cache::H5CompoundDatasetCache{T}
    _lock::ReentrantLock
end

"""

A wrapper for an HDF5 file used in KM3NeT.

The constructor and the I/O methods live in the `KM3ioHDF5Ext` package extension
and are only available once `HDF5` is loaded (`using HDF5`).

"""
struct H5File
    _h5f
    _datasets::Dict{String, H5CompoundDataset}
    _lock::ReentrantLock
end

"""

Attaches key-value-pair meta entries to an HDF5 instance for each field of the
given object.

This function is implemented in the `KM3ioHDF5Ext` package extension and only
available once `HDF5` is loaded (`using HDF5`).

"""
function addmeta end
