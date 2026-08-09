# Changelog

## RNG V2

- Replaced the software-seeded LFSR register block with an external entropy
  controller, FIFO, interrupts, strict APB errors, counters, and fail-closed
  source monitoring.
- Added a clearly unqualified deterministic integration source.
- Added portable software, register parity, Icarus/Verilator tests, synthesis,
  formal verification, and integration/security documentation.
- Removed the legacy CTRL/SEED/VAL driver and VCS class testbench.
