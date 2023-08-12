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
Trk
MCTrk
```

## Online Format
```@docs
DAQEvent
EventHeader
SnapshotHit
TriggeredHit
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
create_dataset
```

## Hardware

```@docs
PMT
DetectorModule
Detector
Hydrophone
Tripod
piezoenabled
hydrophoneenabled
center
```

## Optical Data
```@docs

```

## Acoustics

```@docs
Waveform
AcousticSignal
AcousticsTriggerParameter
```

## Calibration
```@docs
calibrate
floordist
slew
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
