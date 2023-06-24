from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from geoip2.errors import AddressNotFoundError

from parse_env import getenv

from . import models

app = FastAPI(
    title="Geolocation API",
    description="This API provides geolocation information based on IP address.",
    version="0.1.0",
)

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


@app.get("/healthz/", summary="Health Check", tags=["Health Check"])
async def health_check():
    """
    Health Check

    Performs a health check on the Geolocation API.
    """
    try:
        models.city_db.city("8.8.8.8")
        models.asn_db.asn("8.8.8.8")
        return JSONResponse(content={"status": "ok"})
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"status": "error", "message": str(e)},
        )

@app.post(
    "/",
    response_model=models.GeoLocation,
    response_model_exclude_none=True,
    summary="Lookup IP Geolocation",
    tags=["Geolocation"]
)
async def ip_lookup(ip: models.IPAddress, request: Request):
    """
    Lookup IP Geolocation

    Send an empty `POST` body to lookup your IP address or look up any IP address available in MaxMind Geolite2 databases

    - **ip_address**: The IP address to lookup (string).
    """
    ip_address = (
        str(ip.ip_address)
        if ip.ip_address
        else (request.headers.get("X-Forwarded-For") or request.client.host)
    )
    return await models.lookup_ip(ip_address)
