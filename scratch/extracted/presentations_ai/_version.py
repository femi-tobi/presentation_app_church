from importlib.metadata import PackageNotFoundError, version

try:
    __version__ = version("presentations-ai")
except PackageNotFoundError:
    __version__ = "0.0.0-dev"
