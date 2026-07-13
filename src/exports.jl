# HDF5 (the methods live in the KM3ioHDF5Ext extension, loaded with `using HDF5`)
export

H5CompoundDataset,
H5File,
addmeta,

# Basic types
Direction,     # reexport from KM3Base
Location,
Position,      # reexport from KM3Base
Quaternion,
Track,         # reexport from KM3Base
UTMPosition,   # reexport from KM3Base

# Hardware
Detector,
DetectorModule,
detoid2detid,
detid2detoid,
Hydrophone,
PMT,
StringMechanics,
StringMechanicsParameters,
Tripod,
PMTFile,
PMTData,
PMTPhysicalAddress,
center,
getmodule,
getpmt,
getpmts,
getaddress,
gettripods,
getwaveforms,
gethydrophones,
getpmtfile,
haslocation,
hasstring,
isbasemodule,
isopticalmodule,
modules,


# Acoustics
AcousticSignal,
AcousticsTriggerParameter,
Waveform,
hydrophoneenabled,
piezoenabled,

# ROOT
ROOTFile,
AcousticsEventFile,
MetaData,
printmeta,

# Online dataformat
DAQEvent,
EventHeader,
SnapshotHit,
SummaryFrame,
Summaryslice,
SummarysliceHeader,
Timeslice,
TimesliceHeader,
Timeslices,
TimesliceContainer,
TimesliceHit,
SuperFrame,
AbstractUTCTime,
AbstractDAQFrame,
DAQFrameError,
PMT_ERROR,
TDC_ERROR,
TIME_ERROR,
UDP_ERROR,
UTCExtended,
UTCTime,
checksum,
count_active_channels,
count_fifostatus,
count_hrvstatus,
fifostatus,
hasudptrailer,
hrvstatus,
maximal_udp_sequence_number,
number_of_udp_packets_received,
pmtrate,
pmtrates,
status,
tdcstatus,
testdaqstatus,
wrstatus,

# DST dataformat
DSTTree,
DSTEvent,
DSTBranchView,
DSTRunHeaders,
DSTHistory,
DST_BRANCHES,
describe_dst_branch,

# Offline dataformat
OfflineEventTape,
eachevent,
CalibratedHit,
CalibratedMCHit,
CalibratedSnapshotHit,
CalibratedTriggeredHit,
Evt,
MCTrk,
TriggeredHit,
Trk,
XCalibratedHit,
FitInformation,
WeightList,
hasofflineevents,
hasonlineevents,
hassummaryslices,
hastimeslices,
hasL0timeslices,
hasL1timeslices,
hasL2timeslices,
hasSNtimeslices,
hasTStimeslices,
eachsummaryslice,
eachtimeslice,
eachL0timeslice,
eachL1timeslice,
eachL2timeslice,
eachSNtimeslice,
eachTStimeslice,

# Oscillations open data
OscillationsData,
OSCFile,
ResponseMatrixBin,
ResponseMatrixBinNeutrinos,
ResponseMatrixBinMuons,
ResponseMatrixBinData,
OscOpenDataTree,

# Misc I/O
tojson,

# Calibration
AbstractCalibratedHit,
K40Rates,
calibrate,
calibratetime,
combine,
floordist,
slew,
Orientations,
Compass,

# Reconstruction
RecStageRange,
bestaashower,
bestjppmuon,
bestjppshower,
besttrack,
hasaashowerfit,
hashistory,
hasjppmuonenergy,
hasjppmuonfit,
hasjppmuongandalf,
hasjppmuonprefit,
hasjppmuonsimplex,
hasjppmuonstart,
hasreconstructedaashower,
hasreconstructedjppmuon,
hasreconstructedjppshower,
hasshowercompletefit,
hasshowerfit,
hasshowerpositionfit,
hasshowerprefit,

# Tools
MCEventMatcher,
SummarysliceIntervalIterator,
getevent,
LonLat,            # reexport from KM3Base
LonLatExtended,    # reexport from KM3Base
lonlat,            # reexport from KM3Base
isnorthern,        # reexport from KM3Base
haversine,         # reexport from KM3Base
rotmatrix,         # reexport from KM3Base

# Diff
compare,
Diff,
FieldChange,
isidentical,
ndiffs,
difftrait,
diffkey,
DiffLeaf,
DiffStruct,
DiffContainer,

# Utils
categorize,
is3dmuon,
is3dshower,
ismxshower,
isnb,
most_frequent,
nthbitset,
triggered,

# Physics and math helpers
CherenkovPhoton,
Water,
WaterORCA,
WaterARCA,
azimuth,          # reexport from KM3Base
true_azimuth,     # reexport from KM3Base
cherenkov,
distance,         # reexport from KM3Base
phi,              # reexport from KM3Base
theta,            # reexport from KM3Base
zenith,           # reexport from KM3Base
slerp,

# MC <-> DAQ time conversion
TimeConverter,
mc2daq,
daq2mc,

# Real-time
@ip_str,
CHClient,
CHTag,
subscribe
