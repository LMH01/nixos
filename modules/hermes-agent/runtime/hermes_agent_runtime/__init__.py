"""Hermes runtime routing policy for the managed container.

The container wrapper imports :func:`install` after Hermes' own bootstrap and
before importing ``hermes_cli.main``.  Keeping this adapter outside the Hermes
checkout avoids changing files owned by Hermes' updater.
"""

from .routing import configure_defaults, install

__all__ = ["configure_defaults", "install"]
