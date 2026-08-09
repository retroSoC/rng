# RNG V2 Integration Guide

Instantiate `apb4_rng` in the APB clock domain and connect all entropy ports to
one source. A qualified production source must provide conditioned 32-bit words
and a stable qualification indication derived from the product lifecycle and
validation policy.

The source uses ready/valid flow control. It must keep `entropy_valid_i`,
`entropy_data_i`, `entropy_qualified_i`, and `entropy_fault_i` stable while
valid is asserted and ready is low. A source that cannot accept backpressure
needs an external FIFO or drop/error adapter.

`rng_deterministic_source` is a synthesizable integration aid. It uses Common's
Galois LFSR, drives `qualified_o=0`, and is suitable only for deterministic
regression and non-security bring-up. Replacing it with a physical source must
not change the APB controller or software ABI.

The controller does not cross clock or power domains. Use Common CDC components
outside the IP and define reset, isolation, and power-up ordering in the SoC
clock/reset inventory.
