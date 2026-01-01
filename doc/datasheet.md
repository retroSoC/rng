## Datasheet

### Overview
The `rng(random number generator)` IP is a fully parameterised soft IP to generate the pseudo random number. The IP features an APB4 slave interface, fully compliant with the AMBA APB Protocol Specification v2.0.
 This IP use the 32-bit Galois LSFR with maximum length(feedback polynomial: `32'hE000_0200`). After writing the non-zero value to the seed register, `rng` can generate one valid 32-bit random number in every rising edge of apb clock.

### Feature
* Internal 32-bit LSFR implemented with max sequence
* 32-bit programmable seed register
* Generate one random number per cycle
* Static synchronous design
* Full synthesizable

### Interface
| port name | type        | description          |
|:--------- |:------------|:---------------------|
| apb4      | interface   | apb4 slave interface |

### Register

| name | offset  | length | description |
|:----:|:-------:|:-----: | :---------: |
| [CTRL](#control-register) | 0x0 | 4 | control register |
| [SEED](#seed-reigster) | 0x4 | 4 | seed register |
| [VAL](#val-reigster) | 0x8 | 4 | value register |

#### Control Register
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:1]` | none | reserved |
| `[0:0]` | RW | EN |

reset value: `0x0000_0000`

* EN: the enable signal for seed register writing operation.
    * `EN = 1'b0`: writing seed register disabled
    * `EN = 1'b1`: writing seed register enabled

#### Seed Reigster
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:0]` | RW | SEED |

reset value: `0x0000_0000`

* SEED: the 32-bit initial random seed value.

#### Value Reigster
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:0]` | R | VAL |

reset value: `0x0000_0000`

* VAL: the 32-bit generated random number.

### Program Guide
The software operation of `rng` is simple. These registers can be accessed by 4-byte aligned read and write. All operation can be split into **initialization and read operation**. C-like pseudocode for the initialization operation:
```c
rng.CTRL.EN = 1        // enable the seed register writing
rng.SEED = SEED_32_bit // write seed value
```
read operation:
```c
uint32_t val = rng.VAL // get the random number
```

If wanting to stop generating valid random numbers, software need to set the value of seed register to zero:
```c
rng.SEED = 0x0
```
complete driver and test codes in [driver](../driver/) dir. 

### Resoureces
### References
### Revision History