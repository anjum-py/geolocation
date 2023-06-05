from pathlib import Path
from parse_env import getenv
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from geoip2.database import Reader
from geoip2.errors import AddressNotFoundError
from . import models

BASE_DIR = Path(__file__).resolve().parent.parent
CITY_DB_PATH = BASE_DIR.joinpath("db/GeoLite2-City.mmdb")
ASN_DB_PATH = BASE_DIR.joinpath("db/GeoLite2-ASN.mmdb")

city_db = Reader(CITY_DB_PATH, mode=1)
asn_db = Reader(ASN_DB_PATH, mode=1)


async def asn_info(asn):
    return models.ASN(
        autonomous_system_number=asn.autonomous_system_number,
        autonomous_system_organization=asn.autonomous_system_organization,
        ip_address=asn.ip_address,
        network=asn.network,
    )


async def continent_info(continent):
    return models.Continent(
        code=continent.code,
        name=continent.name,
    )


async def country_info(country):
    return models.Country(
        is_in_european_union=country.is_in_european_union,
        iso_code=country.iso_code,
        name=country.name,
    )


async def location_info(location):
    return models.Location(
        accuracy_radius=location.accuracy_radius,
        latitude=location.latitude,
        longitude=location.longitude,
        metro_code=location.metro_code,
        time_zone=location.time_zone,
    )


async def city_info(city):
    return models.City(
        name=city.name,
    )


async def postal_info(postal):
    return models.Postal(
        code=postal.code,
    )


async def lookup_ip(ip):
    city = city_db.city(ip)
    asn = asn_db.asn(ip)

    return models.GeoLocation(
        continent=await continent_info(city.continent),
        country=await country_info(city.country),
        city=await city_info(city.city),
        location=await location_info(city.location),
        postal=await postal_info(city.postal),
        asn=await asn_info(asn),
    )


app = FastAPI()

app.add_middleware(
    TrustedHostMiddleware, allowed_hosts=getenv("FASTAPI_ALLOWED_HOSTS", "*").split(" ")
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=getenv("FASTAPI_CORS_ORIGINS").split(" "),
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


@app.exception_handler(AddressNotFoundError)
async def address_not_found_error(request: Request, exc: AddressNotFoundError):
    return JSONResponse(
        status_code=404,
        content={
            "message": f"IP address {exc.ip_address} is not present in the database"
        },
    )


@app.post(
    "/",
    response_model=models.GeoLocation,
    response_model_exclude_none=True,
)
async def ip_lookup(ip: models.IPAddress, request: Request):
    ip_address = (
        str(ip.ip_address)
        if ip.ip_address
        else (request.headers.get("X-Forwarded-For") or request.client.host)
    )
    return await lookup_ip(ip_address)


@app.get("/healthz/")
async def health_check():
    try:
        city_db.city("8.8.8.8")
        asn_db.asn("8.8.8.8")
        return JSONResponse(content={"status": "ok"})
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"status": "error", "message": str(e)},
        )
