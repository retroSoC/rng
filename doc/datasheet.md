# RNG V2 Datasheet

## Purpose

RNG V2 is the digital controller between an APB4 software interface and a
synchronous 32-bit entropy source. It provides source enable/ready flow
control, an output FIFO, startup qualification, continuous duplicate-word
detection, fail-closed error handling, interrupts, counters, and strict APB4
access checking.

RNG V2 is not by itself a complete physical entropy source. The integrator is
responsible for the noise source, conditioning, min-entropy assessment, PVT
characterization, and any NIST SP 800-90B or AIS 31 validation.

## Interfaces

| Port | Direction | Description |
| --- | --- | --- |
| `entropy_enable_o` | output | Request that the source run |
| `entropy_ready_o` | output | Controller can accept one word this cycle |
| `entropy_valid_i` | input | Source presents a valid word |
| `entropy_data_i[31:0]` | input | Source word, stable while valid and not ready |
| `entropy_qualified_i` | input | Integration assurance says the source is qualified |
| `entropy_fault_i` | input | Source reports a fatal fault |
| `irq_o` | output | Enabled interrupt state is pending |
| `apb4` | APB4 slave | Common 32-bit APB4 interface |

All entropy signals are synchronous to `apb4.pclk`. An asynchronous source
must use a qualified CDC bridge outside this IP. `entropy_qualified_i` must be
stable while enabled; changing it is a fatal integration error.

## Operation

After `CTRL.ENABLE` is set, the first accepted source word is retained only as a
comparison reference and discarded. A different second word completes startup
and enters the FIFO. Every later word is compared with the previous accepted
word. A duplicate, `entropy_fault_i`, or qualification change flushes the FIFO,
stops source handshakes, latches an error, and raises the corresponding
interrupt. Recovery requires disabling the controller and issuing
`CTRL.RECOVER`.

The duplicate check is an additional catastrophic-failure detector, not a
replacement for SP 800-90B RCT/APT tests on the physical noise source.

## APB Behavior

`PREADY` is always high. Unaligned or unmapped accesses, incorrect access
direction, illegal state transitions, invalid watermark writes, and reads from
an empty `DATA` register assert `PSLVERR` in the APB access phase. Writable
registers honor `PSTRB`; unstrobed bytes retain their prior value.

## Register Map

| Offset | Name | Access | Description |
| ---: | --- | --- | --- |
| `0x000` | `CTRL` | RW/WO | Enable and command pulses |
| `0x004` | `STATUS` | RO | Controller, FIFO, source and lock state |
| `0x008` | `DATA` | RO-pop | Oldest FIFO word; empty reads error |
| `0x00C` | `FIFO_STATUS` | RO | Level, empty/full, and watermark |
| `0x010` | `ERROR_STATUS` | RW1C | Fatal error causes; writable only while disabled |
| `0x014` | `INTR_STATE` | RW1C | Sticky interrupt state |
| `0x018` | `INTR_ENABLE` | RW | Interrupt enable mask |
| `0x01C` | `INTR_TEST` | WO | Interrupt test injection |
| `0x020` | `CONFIG` | RW | FIFO watermark; writable disabled and unlocked |
| `0x024` | `CONFIG_LOCK` | RW1S | Locks `CONFIG` until hardware reset |
| `0x028` | `ACCEPTED_COUNT` | RO | Saturating accepted-source-word count |
| `0x02C` | `DISCARD_COUNT` | RO | Saturating startup/failure discard count |
| `0x030` | `HEALTH_FAIL_COUNT` | RO | Saturating fatal-event count |
| `0x034` | `SOURCE_STATUS` | RO | Live and latched source state |
| `0x0F4` | `IP_ID` | RO | ASCII `RNG2`, `0x524E4732` |
| `0x0F8` | `IP_VERSION` | RO | ABI version, `0x00020000` |
| `0x0FC` | `CAPABILITY` | RO | ABI, FIFO depth and feature bitmap |

`CTRL[0]` is enable, bit 1 is a FIFO flush pulse, and bit 2 is recover. Recover
is legal only while disabled. Enabling with a pending fatal error is rejected.

`STATUS[0]` through bit 7 are enabled, active, startup done, data ready, FIFO
full, source qualified, fatal error, and configuration locked. Bits 15:8 are
the FIFO level.

`ERROR_STATUS[2:0]` are source fault, duplicate word, and qualification change.
`INTR_STATE[2:0]` are data ready, health failure, and source fault.

`CONFIG[7:0]` is the FIFO watermark. Legal values are 1 through `FIFO_DEPTH`;
the reset value is one. `CAPABILITY[31:24]` is ABI 2, bits 15:8 are FIFO depth,
and bits 7:0 identify external source, deterministic test source, FIFO,
duplicate check, interrupt, strict APB, and qualification-tag support.
