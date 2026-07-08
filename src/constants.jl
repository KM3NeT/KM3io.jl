module Constants

const NUMBER_OF_PMTS = 31

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

# Jpp light dispersion model (JDispersion, Bailey 2002): the index of refraction
# n(lambda, P) is a polynomial in x = 1/lambda, with the wavelength lambda in [nm]
# and the ambient pressure P in [atm].
const DISPERSION_A0 = 1.3201    # offset
const DISPERSION_A1 = 1.4e-5    # dn/dP
const DISPERSION_A2 = 16.2566   # coefficients of the polynomial in 1/lambda
const DISPERSION_A3 = -4383.0
const DISPERSION_A4 = 1.1455e6
# Reference wavelength [nm] at which the effective water index is evaluated. It is
# chosen such that the dispersion model reproduces the aanet/Jpp average indices
# (n_phase ~ 1.3499, n_group ~ 1.3797) at the nominal ambient pressure.
const REFERENCE_WAVELENGTH = 460.0

# DAQ related values, which are not yet present in the km3net-dataformat repository.
const MINIMAL_RATE_HZ = 2.0e3
const MAXIMAL_RATE_HZ = 2.0e6
const RATE_FACTOR = log(MAXIMAL_RATE_HZ / MINIMAL_RATE_HZ) / 255.0

const FRAME_TIME = 1e8  # [ns] duration of a DAQ timeslice / frame (100 ms)

end
