/* Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn> */
/* SPDX-License-Identifier: MulanPSL-2.0 */

#ifndef RNG_H
#define RNG_H

#include <stdbool.h>
#include <stdint.h>

typedef enum {
    RNG_STATUS_OK = 0,
    RNG_STATUS_INVALID_ARGUMENT = -1,
    RNG_STATUS_TIMEOUT = -2,
    RNG_STATUS_UNAVAILABLE = -3,
    RNG_STATUS_UNQUALIFIED = -4,
    RNG_STATUS_HEALTH_FAILURE = -5,
    RNG_STATUS_INCOMPATIBLE = -6
} rng_status_t;

typedef struct {
    uint8_t fifo_watermark;
    uint32_t interrupt_enable;
    bool lock_config;
} rng_config_t;

typedef struct {
    uint32_t raw_status;
    uint32_t error_status;
    uint32_t interrupt_state;
    uint32_t accepted_count;
    uint32_t discard_count;
    uint32_t health_fail_count;
    uint8_t fifo_level;
    bool enabled;
    bool active;
    bool startup_done;
    bool data_ready;
    bool source_qualified;
    bool fatal_error;
    bool config_locked;
} rng_snapshot_t;

rng_status_t rng_init(uintptr_t base, const rng_config_t *config);
rng_status_t rng_get_status(uintptr_t base, rng_snapshot_t *snapshot);
rng_status_t rng_read_entropy(uintptr_t base, uint32_t *word, uint32_t timeout);
rng_status_t rng_read_diagnostic(uintptr_t base, uint32_t *word, uint32_t timeout);
rng_status_t rng_recover(uintptr_t base);
rng_status_t rng_interrupt_enable(uintptr_t base, uint32_t mask);
rng_status_t rng_interrupt_clear(uintptr_t base, uint32_t mask);
rng_status_t rng_interrupt_test(uintptr_t base, uint32_t mask);

#endif
