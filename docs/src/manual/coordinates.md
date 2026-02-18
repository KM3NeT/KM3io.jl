# Coordinates

## UTM

The positions of KM3NeT detectors are given in the [UTM coordinate
system](https://en.wikipedia.org/wiki/Universal_Transverse_Mercator_coordinate_system)
and use the [World Geodetic System
WGS84](https://en.wikipedia.org/wiki/World_Geodetic_System#WGS84) standard. This
data is available in the DETX format starting from version 2 and in the DATX
format, which was officially introduced in parallel to DETX v5.

The position information is stored in the `.pos` field of the [`Detector`](@ref)
and has the type [`KM3Base.UTMPosition`](@extref). Below is the position of an ARCA
detector with the detector ID 133.

```@example 1
using KM3io, KM3NeTTestData

det = Detector(datapath("detx", "KM3NeT_00000133_20221025.detx"))
det.pos
```

Positions and orientations of everything else inside and around the detector
(hits, detector modules, PMTs, reconstructed tracks and showers etc.) are given
in local coordinates using the x, y, z components. The x-axis is hereby pointing
to the east (UTM Easting), corresponding to `phi = 0 deg`, the y-axis to the
north (UTM Northing), corresponding to `phi = 90 deg`, hence the angle phi is
increasing counter clockwise and the z-axis upwards towards the zenith with its
zero value at the sea surface. More details can be found in the
`KM3NeT_SOFT_WD_2016_002 - Coordinate System Proposal` internal note. The origin
of the local coordinate system is at the detector's UTM position.

## Earth Coordinates

A commonly used coordinate system to describe positions directly on Earth as
latitude and longitude is the
[Geographic Coordinate System (GCS)](https://en.wikipedia.org/wiki/Geographic_coordinate_system).
`KM3Base.jl` provides a function called [`KM3Base.lonlat`](@extref) to transform
UTM coordinates represented as [`KM3Base.UTMPosition`](@extref) to GCS.

```@example 1
lonlat(det.pos)
```

`KM3io.jl` extends this with a method that accepts a [`Detector`](@ref) directly.

```@example 1
lonlat(det)
```

The output value is not a simple longitude and latitude pair but contains
additional information. The current implementation includes the meridian
convergence angle, which is the angle of difference between true north and
coordinate north, and the point scale factor. These quantities are important for
astronomic coordinate transformations and are required due to the fact that the
Earth's shape is not a perfect sphere.

!!! note

    Although `KM3io.jl` defines a simple [`KM3Base.LonLat`](@extref) type, it's currently not being used and acts as a placeholder.

## Azimuth

KM3NeT uses the ANTARES azimuth definition which is different to what is used in e.g. SLALIB
or AstroPy. The [`KM3Base.azimuth`](@extref) function can be used to determine the azimuth according
to the KM3NeT definition from a given [`KM3Base.Direction`](@extref) in a detector coordinate system
where `x` points to East and `y` to North. This is a convention often used in geographic
coordinate systems like [Geographic Coordinate System (GCS)](https://en.wikipedia.org/wiki/Geographic_coordinate_system). 

### KM3NeT/ANTARES Azimuth

```@example 1
azimuth(Direction(1.0, 0.0, 0.0))
```

```@example 1
azimuth(Direction(0.0, 1.0, 0.0))
```

```@example 1
azimuth(Direction(0.0, -1.0, 0.0))
```

### "True" Azimuth

The "true" azimuth (as typically used in astronomy libraries like SLALIB and AstroPy)
can be obtained using [`KM3Base.true_azimuth`](@extref).
Azimuth is returned in the range 0−2π; north is zero, and east is +π/2.

```@example 1
true_azimuth(Direction(1.0, 0.0, 0.0))
```

```@example 1
true_azimuth(Direction(0.0, 1.0, 0.0))
```

```@example 1
true_azimuth(Direction(0.0, -1.0, 0.0))
```
