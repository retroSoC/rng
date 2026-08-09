# RNG

RNG V2 is an APB4 entropy controller. It accepts qualified 32-bit entropy
words from a technology-specific source, performs startup and continuous
duplicate-word checks, and makes accepted words available through a protected
FIFO and interrupt interface.

The included deterministic source exists only for simulation, integration
testing, and non-security bring-up. It always reports `qualified=0`; it is not a
TRNG and must not be used for keys, nonces, challenges, or other security
material.

See [the datasheet](doc/datasheet.md), [integration guide](doc/integration.md),
and [security guide](doc/security.md) before integrating the controller.

## Build And Test

The default layout expects the Common repository at `../common`.

```bash
make doctor
make format-check register-check lint
make test synth formal
```

The IP register map is hand-written. `make register-check` compares the RTL and
C definitions; no register generator is used.
