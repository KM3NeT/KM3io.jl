# API


```@index
```

## Basic Data Structures

```@docs
Position
Direction
Location
```

## Offline Format
```@docs
Evt
CalibratedHit
CalibratedMCHit
XCalibratedHit
Trk
MCTrk
FitInformation
```

## Online Format
```@docs
DAQEvent
EventHeader
SnapshotHit
TriggeredHit
CalibratedSnapshotHit
CalibratedTriggeredHit
UTCTime
UTCExtended
Summaryslice
SummarysliceHeader
SummaryFrame
```

## HDF5
```@docs
H5File
H5CompoundDataset
addmeta
create_dataset
flush
```

## Hardware

```@docs
PMT
DetectorModule
Detector
modules
getmodule
getpmt
haslocation
isbasemodule
isopticalmodule
write(::AbstractString, ::Detector)
write(::IO, ::Detector)
Hydrophone
read(::AbstractString, ::Type{Hydrophone})
Tripod
read(::AbstractString, ::Type{Tripod})
write(::AbstractString, ::Vector{Tripod})
piezoenabled
hydrophoneenabled
center
StringMechanics
StringMechanicsParameters
read(::AbstractString, ::Type{StringMechanics})
```

## Optical Data
```@docs

```

## Acoustics

```@docs
Waveform
read(filename::AbstractString, T::Type{Waveform})
AcousticSignal
AcousticsTriggerParameter
read(filename::AbstractString, T::Type{AcousticsTriggerParameter})
```

## Calibration
```@docs
calibrate
calibratetime
combine
Orientations
Compass
Quaternion
floordist
slew
slerp
```

## Physics
```@docs
azimuth
zenith
phi
theta
cherenkov
CherenkovPhoton
K40Rates
```

## Trigger
```@docs
triggered
is3dmuon
is3dshower
ismxshower
isnb
```

## ControlHost
```@docs
CHClient
```

## Tools

### General tools
```@docs
SummarysliceIntervalIterator
getevent
categorize
nthbitset
most_frequent
```

### DAQ
```@docs
pmtrate
pmtrates
hrvstatus
fifostatus
tdcstatus
wrstatus
hasudptrailer
count_active_channels
count_fifostatus
count_hrvstatus
status
number_of_udp_packets_received
maximal_udp_sequence_number
```

### Reconstruction
```@docs
besttrack
bestjppmuon
bestjppshower
bestaashower
RecStageRange
hashistory
```

### Math
```@docs
angle
distance
```
