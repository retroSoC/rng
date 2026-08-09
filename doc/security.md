# RNG V2 Security Guide

RNG V2 must not be advertised as a TRNG without a validated physical source.
The `qualified` status is an integration trust input, not a conclusion computed
by this RTL. Software requiring cryptographic entropy must reject data whenever
that status is clear.

The controller fails closed on source faults, repeated consecutive words, and
qualification changes. It flushes buffered words before reporting the error.
Software must record the error, disable the controller, correct or reset the
source, issue recover, and repeat startup before consuming new data.

The duplicate-word detector does not estimate min-entropy and does not replace
startup or continuous health tests required by SP 800-90B. Raw-noise access,
test overrides, software-injected entropy, and a bypass around qualification
are intentionally absent from this version.

Access control belongs to the SoC fabric. Security-oriented integrations should
restrict configuration and data to a trusted management domain or mediate data
through a privileged service.
