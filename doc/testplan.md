# RNG V2 Test Plan

Directed and randomized APB tests cover reset values, access permissions,
partial writes, invalid offsets, unaligned accesses, empty DATA reads, legal and
illegal configuration changes, and lock behavior.

Entropy-path tests cover qualified and unqualified sources, first-word discard,
startup completion, FIFO ordering and boundaries, simultaneous push/pop,
watermark interrupts, flush, disable/re-enable, duplicate detection, source
fault, qualification change, fail-closed behavior, and recovery.

Software tests cover ABI discovery, invalid arguments, timeout, unqualified
data rejection, diagnostic reads, fatal errors, interrupt masks, and recovery.

Formal properties cover FIFO bounds, DATA pop legality, fatal-state source
backpressure, lock monotonicity, IRQ derivation, APB error phase, and source
ready/enable consistency. Statistical output tests are not treated as evidence
of physical entropy quality.
