module Constants

const c = 2.99792458e8  # m/s

# Constants from Jpp
const INDEX_OF_REFRACTION_WATER = 1.3800851282  # Average index of refraction of water corresponding to the group velocity (used in Jpp e.g. in PDFs)
const C                  = 0.299792458    # Speed of light in vacuum [m/ns]
const C_INVERSE          = 1.0/C          # Inverse speed of light in vacuum [ns/m]

const R_EARTH_KM         = 6371           # Radius of the Earth [m]
const DENSITY_EARTH      = 5.51           # Average density of the Earth [gr/cm³]

const DENSITY_SEA_WATER  = 1.038          # Density  of sea water [g/cm^3]
const DENSITY_ROCK       = 2.65           # Density  of rock      [g/cm^3]
const SALINITY_SEA_WATER = 0.035          # Salinity of sea water
const X0_WATER_M         = 0.36           # Radiation length pure water [m]

const TAN_THETA_C_WATER  = √((INDEX_OF_REFRACTION_WATER - 1.0) * (INDEX_OF_REFRACTION_WATER + 1.0))  # Average tangent corresponding to the group velocity
const COS_THETA_C_WATER  = 1.0 / INDEX_OF_REFRACTION_WATER  # Average cosine  corresponding to the group velocity
const SIN_THETA_C_WATER  = TAN_THETA_C_WATER * COS_THETA_C_WATER  # Average sine    corresponding to the group velocity
const KAPPA_WATER        = 0.96;


const KM3NET_AMBIENT_PRESSURE = 240.0  # [Atm]
const ANTARES_AMBIENT_PRESSURE = 240.0  # [Atm]
const KM3NET_PHOTOCATHODE_AREA = 45.4e-4  # [m^2]
const ANTARES_PHOTOCATHODE_AREA = 440e-4  # [m^2]

# Constants from aanet
const WATER_INDEX = 1.3499  # Used in aanet
const DN_DL = 0.0298
const COS_CHERENKOV = 1 / WATER_INDEX
const CHERENKOV_ANGLE_RAD = acos(COS_CHERENKOV)
const SIN_CHERENKOV = sin(CHERENKOV_ANGLE_RAD)
const TAN_CHERENKOV = tan(CHERENKOV_ANGLE_RAD)
const C_LIGHT = 299792458e-9  # m/ns
const V_LIGHT_WATER = C_LIGHT / (WATER_INDEX + DN_DL)
const C_WATER = C_LIGHT / INDEX_OF_REFRACTION_WATER

# DAQ related values, which are not yet present in the km3net-dataformat repository.
const MINIMAL_RATE_HZ = 2.0e3
const MAXIMAL_RATE_HZ = 2.0e6
const RATE_FACTOR = log(MAXIMAL_RATE_HZ / MINIMAL_RATE_HZ) / 255.0

end
