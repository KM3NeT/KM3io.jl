# API


```@index
```

## Basic Data Structures

```@docs
Location
```

## ROOT
```@docs
ROOTFile
MetaData
printmeta
```

## Offline Format
```@docs
Evt
OfflineEventTape
eachevent
CalibratedHit
CalibratedMCHit
XCalibratedHit
Trk
MCTrk
FitInformation
WeightList
hasofflineevents
```

## DST Format
```@docs
DSTTree
DSTEvent
DSTBranchView
DSTRunHeaders
DSTHistory
DST_BRANCHES
describe_dst_branch
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
Timeslice
TimesliceHeader
Timeslices
TimesliceContainer
TimesliceHit
SuperFrame
AbstractDAQFrame
DAQFrameError
checksum
testdaqstatus
hasonlineevents
hassummaryslices
hastimeslices
hasL0timeslices
hasL1timeslices
hasL2timeslices
hasSNtimeslices
hasTStimeslices
eachsummaryslice
eachtimeslice
eachL0timeslice
eachL1timeslice
eachL2timeslice
eachSNtimeslice
eachTStimeslice
```

## Oscillations Open Data
```@docs
OscillationsData
OSCFile
ResponseMatrixBin
ResponseMatrixBinNeutrinos
ResponseMatrixBinMuons
ResponseMatrixBinData
OscOpenDataTree
```

## HDF5
```@docs
H5File
H5CompoundDataset
addmeta
create_dataset
flush
```

## JSON
```@docs
tojson
```

## Hardware

```@docs
PMT
DetectorModule
Detector
detoid2detid
detid2detoid
PMTFile
getpmtfile
PMTData
PMTPhysicalAddress
modules
getmodule
getpmt
getaddress
haslocation
hasstring
isbasemodule
isopticalmodule
write(::AbstractString, ::Detector)
write(::IO, ::Detector)
Hydrophone
read(::AbstractString, ::Type{Hydrophone})
gethydrophones
Tripod
read(::AbstractString, ::Type{Tripod})
write(::AbstractString, ::Vector{Tripod})
gettripods
piezoenabled
hydrophoneenabled
center
StringMechanics
StringMechanicsParameters
read(::AbstractString, ::Type{StringMechanics})
```

## Comparing Objects
```@docs
compare
Diff
FieldChange
isidentical
ndiffs
difftrait
diffkey
DiffLeaf
DiffStruct
DiffContainer
```

## Optical Data
```@docs

```

## Acoustics

```@docs
Waveform
read(filename::AbstractString, T::Type{Waveform})
getwaveforms
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
cherenkov
CherenkovPhoton
Water
WaterORCA
WaterARCA
TimeConverter
mc2daq
daq2mc
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
