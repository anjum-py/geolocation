import asyncio
from pathlib import Path
from typing import Any, Optional

from geoip2.database import Reader
from pydantic import BaseModel, IPvAnyAddress

BASE_DIR = Path(__file__).resolve().parent.parent
CITY_DB_PATH = BASE_DIR.joinpath("db/GeoLite2-City.mmdb")
ASN_DB_PATH = BASE_DIR.joinpath("db/GeoLite2-ASN.mmdb")

city_db = Reader(CITY_DB_PATH, mode=1)
asn_db = Reader(ASN_DB_PATH, mode=1)


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


async def asn_info(asn):
    return ASN(
        autonomous_system_number=asn.autonomous_system_number,
        autonomous_system_organization=asn.autonomous_system_organization,
        ip_address=asn.ip_address,
        network=asn.network,
    )


async def continent_info(continent):
    return Continent(
        code=continent.code,
        name=continent.name,
    )


async def country_info(country):
    return Country(
        is_in_european_union=country.is_in_european_union,
        iso_code=country.iso_code,
        name=country.name,
    )


async def location_info(location):
    return Location(
        accuracy_radius=location.accuracy_radius,
        latitude=location.latitude,
        longitude=location.longitude,
        metro_code=location.metro_code,
        time_zone=location.time_zone,
    )


async def city_info(city):
    return City(
        name=city.name,
    )


async def postal_info(postal):
    return Postal(
        code=postal.code,
    )


async def lookup_ip(ip):
    city = city_db.city(ip)
    asn = asn_db.asn(ip)

    return GeoLocation(
        continent=await continent_info(city.continent),
        country=await country_info(city.country),
        city=await city_info(city.city),
        location=await location_info(city.location),
        postal=await postal_info(city.postal),
        asn=await asn_info(asn),
    )

