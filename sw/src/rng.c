/* Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn> */
/* SPDX-License-Identifier: MulanPSL-2.0 */

#include "rng.h"

#include <stddef.h>

#include "rng_regs.h"

static volatile uint32_t *rng_register(uintptr_t base, uint32_t offset) {
    return (volatile uint32_t *)(base + (uintptr_t)offset);
}

static uint32_t rng_read_register(uintptr_t base, uint32_t offset) {
    return *rng_register(base, offset);
}

static void rng_write_register(uintptr_t base, uint32_t offset, uint32_t value) {
    *rng_register(base, offset) = value;
}

static bool rng_interrupt_mask_valid(uint32_t mask) {
    return (mask & ~RNG_INTR_ALL_MASK) == 0U;
}

static rng_status_t rng_read_common(uintptr_t base, uint32_t *word, uint32_t timeout,
                                    bool require_qualified) {
    uint32_t status;

    if ((base == (uintptr_t)0U) || (word == NULL)) {
        return RNG_STATUS_INVALID_ARGUMENT;
    }

    while (timeout != 0U) {
        status = rng_read_register(base, RNG_STATUS_OFFSET);
        if ((status & RNG_STATUS_FATAL_MASK) != 0U) {
            return RNG_STATUS_HEALTH_FAILURE;
        }
        if ((status & RNG_STATUS_DATA_READY_MASK) != 0U) {
            if (require_qualified && ((status & RNG_STATUS_QUALIFIED_MASK) == 0U)) {
                return RNG_STATUS_UNQUALIFIED;
            }
            *word = rng_read_register(base, RNG_DATA_OFFSET);
            return RNG_STATUS_OK;
        }
        --timeout;
    }
    return RNG_STATUS_TIMEOUT;
}

rng_status_t rng_init(uintptr_t base, const rng_config_t *config) {
    uint32_t capability;
    uint32_t fifo_depth;

    if ((base == (uintptr_t)0U) || (config == NULL) ||
        !rng_interrupt_mask_valid(config->interrupt_enable)) {
        return RNG_STATUS_INVALID_ARGUMENT;
    }
    if ((rng_read_register(base, RNG_IP_ID_OFFSET) != RNG_IP_ID_VALUE) ||
        (rng_read_register(base, RNG_IP_VERSION_OFFSET) != RNG_IP_VERSION_VALUE)) {
        return RNG_STATUS_INCOMPATIBLE;
    }

    capability = rng_read_register(base, RNG_CAPABILITY_OFFSET);
    if (((capability & RNG_CAPABILITY_ABI_MASK) >> RNG_CAPABILITY_ABI_SHIFT) != RNG_ABI_VERSION) {
        return RNG_STATUS_INCOMPATIBLE;
    }
    fifo_depth = (capability & RNG_CAPABILITY_FIFO_MASK) >> RNG_CAPABILITY_FIFO_SHIFT;
    if ((config->fifo_watermark == 0U) || ((uint32_t)config->fifo_watermark > fifo_depth)) {
        return RNG_STATUS_INVALID_ARGUMENT;
    }

    rng_write_register(base, RNG_CTRL_OFFSET, 0U);
    rng_write_register(base, RNG_CTRL_OFFSET, RNG_CTRL_RECOVER_MASK);
    rng_write_register(base, RNG_CONFIG_OFFSET, (uint32_t)config->fifo_watermark);
    rng_write_register(base, RNG_INTR_STATE_OFFSET, RNG_INTR_ALL_MASK);
    rng_write_register(base, RNG_INTR_ENABLE_OFFSET, config->interrupt_enable);
    if (config->lock_config) {
        rng_write_register(base, RNG_CONFIG_LOCK_OFFSET, RNG_CONFIG_LOCK_MASK);
    }
    rng_write_register(base, RNG_CTRL_OFFSET, RNG_CTRL_ENABLE_MASK);
    return RNG_STATUS_OK;
}

rng_status_t rng_get_status(uintptr_t base, rng_snapshot_t *snapshot) {
    uint32_t status;

    if ((base == (uintptr_t)0U) || (snapshot == NULL)) {
        return RNG_STATUS_INVALID_ARGUMENT;
    }

    status = rng_read_register(base, RNG_STATUS_OFFSET);
    snapshot->raw_status = status;
    snapshot->error_status = rng_read_register(base, RNG_ERROR_STATUS_OFFSET);
    snapshot->interrupt_state = rng_read_register(base, RNG_INTR_STATE_OFFSET);
    snapshot->accepted_count = rng_read_register(base, RNG_ACCEPTED_COUNT_OFFSET);
    snapshot->discard_count = rng_read_register(base, RNG_DISCARD_COUNT_OFFSET);
    snapshot->health_fail_count = rng_read_register(base, RNG_HEALTH_FAIL_COUNT_OFFSET);
    snapshot->fifo_level =
        (uint8_t)((status & RNG_STATUS_FIFO_LEVEL_MASK) >> RNG_STATUS_FIFO_LEVEL_SHIFT);
    snapshot->enabled = (status & RNG_STATUS_ENABLED_MASK) != 0U;
    snapshot->active = (status & RNG_STATUS_ACTIVE_MASK) != 0U;
    snapshot->startup_done = (status & RNG_STATUS_STARTUP_DONE_MASK) != 0U;
    snapshot->data_ready = (status & RNG_STATUS_DATA_READY_MASK) != 0U;
    snapshot->source_qualified = (status & RNG_STATUS_QUALIFIED_MASK) != 0U;
    snapshot->fatal_error = (status & RNG_STATUS_FATAL_MASK) != 0U;
    snapshot->config_locked = (status & RNG_STATUS_LOCKED_MASK) != 0U;
    return RNG_STATUS_OK;
}

rng_status_t rng_read_entropy(uintptr_t base, uint32_t *word, uint32_t timeout) {
    return rng_read_common(base, word, timeout, true);
}

rng_status_t rng_read_diagnostic(uintptr_t base, uint32_t *word, uint32_t timeout) {
    return rng_read_common(base, word, timeout, false);
}

rng_status_t rng_recover(uintptr_t base) {
    if (base == (uintptr_t)0U) {
        return RNG_STATUS_INVALID_ARGUMENT;
    }
    rng_write_register(base, RNG_CTRL_OFFSET, 0U);
    rng_write_register(base, RNG_CTRL_OFFSET, RNG_CTRL_RECOVER_MASK);
    rng_write_register(base, RNG_CTRL_OFFSET, RNG_CTRL_ENABLE_MASK);
    return RNG_STATUS_OK;
}

rng_status_t rng_interrupt_enable(uintptr_t base, uint32_t mask) {
    if ((base == (uintptr_t)0U) || !rng_interrupt_mask_valid(mask)) {
        return RNG_STATUS_INVALID_ARGUMENT;
    }
    rng_write_register(base, RNG_INTR_ENABLE_OFFSET, mask);
    return RNG_STATUS_OK;
}

rng_status_t rng_interrupt_clear(uintptr_t base, uint32_t mask) {
    if ((base == (uintptr_t)0U) || !rng_interrupt_mask_valid(mask)) {
        return RNG_STATUS_INVALID_ARGUMENT;
    }
    rng_write_register(base, RNG_INTR_STATE_OFFSET, mask);
    return RNG_STATUS_OK;
}

rng_status_t rng_interrupt_test(uintptr_t base, uint32_t mask) {
    if ((base == (uintptr_t)0U) || !rng_interrupt_mask_valid(mask)) {
        return RNG_STATUS_INVALID_ARGUMENT;
    }
    rng_write_register(base, RNG_INTR_TEST_OFFSET, mask);
    return RNG_STATUS_OK;
}
