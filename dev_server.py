from gunicorn.app.base import BaseApplication
from src.main import app
import asyncio
import uvloop
from uvicorn.workers import UvicornWorker


class UvicornWithUvloop(UvicornWorker):
    CONFIG_KWARGS = {"loop": "uvloop", "http": "httptools"}


class DebugAppRun(BaseApplication):
    def __init__(self, app, options=None):
        self.options = options or {}
        self.application = app
        super().__init__()

    def load_config(self):
        config = {
            key: value
            for key, value in self.options.items()
            if key in self.cfg.settings and value is not None
        }
        for key, value in config.items():
            self.cfg.set(key.lower(), value)

    def load(self):
        return self.application


if __name__ == "__main__":
    options = {
        "bind": "0.0.0.0:8443",
        "workers": 2,
        "loglevel": "debug",
        "worker_class": "dev_server.UvicornWithUvloop",
        "certfile": "/letsencrypt/certs/fullchain_sahl.solutions.pem",
        "keyfile": "/letsencrypt/keys/sahl.solutions.privatekey.pem",
    }
    asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())
    DebugAppRun(app, options).run()
