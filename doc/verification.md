# RNG V2 Verification

The verification flow contains:

- Icarus simulation of the scalar controller and injected source faults.
- Verilator simulation of the complete APB4 wrapper and deterministic source.
- A freestanding-compatible host test for the portable C driver.
- RTL/C register parity checking.
- Verilator lint and Yosys synthesis checks.
- SBY/Bitwuzla proof using a constrained ready/valid source.

Run `make format-check register-check lint test synth formal`. A release is not
ready if any command fails. Physical-source entropy collection, PVT coverage,
min-entropy estimation, and certification remain product-level activities
outside this digital controller repository.
