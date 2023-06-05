from pydantic import BaseModel, IPvAnyAddress
from typing import Any, Optional

class IPAddress(BaseModel):
    ip_address: Optional[IPvAnyAddress]

class ASN(BaseModel):
    autonomous_system_number: Optional[int]
    autonomous_system_organization: Optional[str]
    ip_address: Optional[str]
    network: Optional[Any]

class City(BaseModel):
    geoname_id: Optional[int]
    confidence: Optional[int]
    name: Optional[str]
    names: Optional[dict]

class Continent(BaseModel):
    geoname_id: Optional[int]
    code: Optional[str]
    name: Optional[str]
    names: Optional[dict]

class Country(BaseModel):
    geoname_id: Optional[int]
    confidence: Optional[str]
    is_in_european_union: Optional[bool]
    iso_code: Optional[str]
    name: Optional[str]
    names: Optional[dict]

class Location(BaseModel):
    accuracy_radius: Optional[int]
    latitude: Optional[float]
    longitude: Optional[float]
    metro_code: Optional[int]
    time_zone: Optional[str]

class Traits(BaseModel):
    ip_address: Optional[str]
    network: Optional[Any]

class Postal(BaseModel):
    confidence: Optional[int]
    code: Optional[str]

class GeoLocation(BaseModel):
    continent: Optional[Continent]
    country: Optional[Country]
    city: Optional[City]
    location: Optional[Location]
    asn: Optional[ASN]
    postal: Optional[Postal]
