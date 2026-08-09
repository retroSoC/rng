/* Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn> */
/* SPDX-License-Identifier: MulanPSL-2.0 */

#include "rng.h"

#include <assert.h>
#include <stdint.h>

#include "rng_regs.h"

int main(void) {
    uint32_t registers[65] = {0U};
    const uintptr_t base = (uintptr_t)&registers[0];
    const rng_config_t config = {
        .fifo_watermark = 2U,
        .interrupt_enable = RNG_INTR_DATA_READY_MASK,
        .lock_config = true,
    };
    rng_snapshot_t snapshot;
    uint32_t word = 0U;

    registers[RNG_IP_ID_OFFSET / 4U] = RNG_IP_ID_VALUE;
    registers[RNG_IP_VERSION_OFFSET / 4U] = RNG_IP_VERSION_VALUE;
    registers[RNG_CAPABILITY_OFFSET / 4U] =
        (RNG_ABI_VERSION << RNG_CAPABILITY_ABI_SHIFT) | UINT32_C(0x0000087F);

    assert(rng_init(base, &config) == RNG_STATUS_OK);
    assert(registers[RNG_CONFIG_OFFSET / 4U] == 2U);
    assert(registers[RNG_CONFIG_LOCK_OFFSET / 4U] == RNG_CONFIG_LOCK_MASK);
    assert(registers[RNG_CTRL_OFFSET / 4U] == RNG_CTRL_ENABLE_MASK);

    registers[RNG_STATUS_OFFSET / 4U] = RNG_STATUS_ENABLED_MASK | RNG_STATUS_ACTIVE_MASK |
                                        RNG_STATUS_STARTUP_DONE_MASK | RNG_STATUS_DATA_READY_MASK |
                                        UINT32_C(0x00000300);
    registers[RNG_DATA_OFFSET / 4U] = UINT32_C(0x12345678);
    assert(rng_read_entropy(base, &word, 1U) == RNG_STATUS_UNQUALIFIED);
    assert(rng_read_diagnostic(base, &word, 1U) == RNG_STATUS_OK);
    assert(word == UINT32_C(0x12345678));

    registers[RNG_STATUS_OFFSET / 4U] |= RNG_STATUS_QUALIFIED_MASK;
    assert(rng_read_entropy(base, &word, 1U) == RNG_STATUS_OK);
    assert(rng_get_status(base, &snapshot) == RNG_STATUS_OK);
    assert(snapshot.source_qualified);
    assert(snapshot.fifo_level == 3U);

    registers[RNG_STATUS_OFFSET / 4U] = RNG_STATUS_FATAL_MASK;
    assert(rng_read_diagnostic(base, &word, 1U) == RNG_STATUS_HEALTH_FAILURE);
    registers[RNG_STATUS_OFFSET / 4U] = 0U;
    assert(rng_read_diagnostic(base, &word, 1U) == RNG_STATUS_TIMEOUT);
    assert(rng_interrupt_enable(base, UINT32_C(0x80)) == RNG_STATUS_INVALID_ARGUMENT);
    assert(rng_recover((uintptr_t)0U) == RNG_STATUS_INVALID_ARGUMENT);

    return 0;
}
