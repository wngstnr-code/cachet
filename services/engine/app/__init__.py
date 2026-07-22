"""Cachet Originality Engine (Person A / Workstream A1).

Layanan off-chain murni-konten: hashing perceptual (ensemble ×4), embedding
(open_clip, advisory), index (SQLite + vector index), dan logika verdict
first-seen. TIDAK menyentuh chain — itu tugas gateway (A3).

Spec mengikat: docs/technical_implementation_plan.md §1.3 (parameter) & §4-A1.
"""

__all__ = ["__version__"]
__version__ = "0.1.0"
