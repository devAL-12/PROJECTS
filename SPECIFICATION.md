# Pipeline Register Specification

## Overview

This document provides a complete specification for a single-stage pipeline register implementing the valid/ready handshake protocol.

---

## 1. Functional Requirements

### 1.1 Primary Function
The pipeline register shall act as a single-entry buffer between upstream and downstream interfaces, implementing proper flow control using valid/ready handshake signals.

### 1.2 Handshake Protocol

#### Input Interface (Upstream)
- **in_valid**: Asserted HIGH by upstream when data is available
- **in_ready**: Asserted HIGH by pipeline register when it can accept data
- **in_data**: Valid only when both in_valid and in_ready are HIGH
- **Transaction**: Occurs on rising edge of clk when in_valid AND in_ready are both HIGH

#### Output Interface (Downstream)
- **out_valid**: Asserted HIGH by pipeline register when data is available
- **out_ready**: Asserted HIGH by downstream when it can accept data
- **out_data**: Valid when out_valid is HIGH, stable until consumed
- **Transaction**: Occurs on rising edge of clk when out_valid AND out_ready are both HIGH

---

## 2. Behavioral Specification

### 2.1 State Machine

The pipeline register operates in one of two states:

**EMPTY State (valid_reg = 0):**
- in_ready = 1 (can accept input)
- out_valid = 0 (no data to output)
- Transition: Input transaction → FULL state

**FULL State (valid_reg = 1):**
- in_ready = out_ready (can accept input only if output consumed simultaneously)
- out_valid = 1 (data available)
- Transitions:
  - Output consumed only → EMPTY state
  - Output consumed + input arrived → FULL state (new data)
  - No output consumed → FULL state (hold current data)

### 2.2 Transaction Truth Table

| Input Fire | Output Fire | Next State | Action |
|------------|-------------|------------|--------|
| 0 | 0 | Hold | No change |
| 0 | 1 | EMPTY | Clear valid, ready for input |
| 1 | 0 | FULL | Store input, assert output valid |
| 1 | 1 | FULL | Replace data (pass-through) |

*Note: Input Fire = in_valid && in_ready; Output Fire = out_valid && out_ready*

### 2.3 Data Flow

**Case 1: Normal Write (Empty → Full)**
```
T0: Register empty (valid_reg = 0)
T1: in_valid = 1, in_data = D0, in_ready = 1
T2: Register stores D0, valid_reg = 1, out_valid = 1
```

**Case 2: Normal Read (Full → Empty)**
```
T0: Register full with D0 (valid_reg = 1, out_data = D0)
T1: out_ready = 1, out_valid = 1
T2: Register empty (valid_reg = 0), in_ready = 1
```

**Case 3: Pass-Through (Full → Full)**
```
T0: Register full with D0, out_ready = 1, in_valid = 1, in_data = D1
T1: Both transactions occur
T2: Register full with D1, out_data = D1
```

**Case 4: Backpressure (Full, no consumer)**
```
T0: Register full with D0, out_ready = 0
T1: in_ready = 0 (backpressure), out_valid = 1 (data held)
T2: No change, data preserved
```

---

## 3. Timing Requirements

### 3.1 Setup and Hold Times
- Input data (in_data) must meet setup/hold time relative to clock edge
- in_valid and out_ready are synchronous inputs
- All outputs are registered (no combinational paths from inputs to outputs except in_ready)

### 3.2 Propagation Delays
- in_ready: Combinational from valid_reg and out_ready
- out_valid: Registered output (1 clock cycle delay)
- out_data: Registered output (1 clock cycle delay)

### 3.3 Clock and Reset
- **Clock**: Positive edge triggered
- **Reset**: Asynchronous, active-low (rst_n)
- **Reset Behavior**: Clears valid_reg to 0, safe reset of data_reg

---

## 4. Constraints and Guarantees

### 4.1 No Data Loss
**Guarantee**: If in_valid is asserted and in_ready is LOW, the upstream source must hold in_data stable until in_ready becomes HIGH.

**Implementation**: The design only accepts data when in_ready = 1.

### 4.2 No Data Duplication
**Guarantee**: Each data word is transferred exactly once from input to output.

**Implementation**: 
- Data stored on input transaction (in_valid && in_ready)
- Data consumed on output transaction (out_valid && out_ready)
- Valid flag cleared after consumption

### 4.3 Backpressure Handling
**Guarantee**: When downstream is not ready (out_ready = 0), the pipeline register shall:
1. Hold current output data stable
2. Assert backpressure (in_ready = 0) if register is full
3. Not accept new input data

### 4.4 Data Integrity
**Guarantee**: out_data shall remain stable while out_valid is HIGH and out_ready is LOW.

---

## 5. Reset Behavior

### 5.1 Asynchronous Reset
When rst_n is asserted LOW:
- valid_reg ← 0 (immediately, asynchronously)
- data_reg ← 0 (for clean simulation, synthesis may optimize)
- out_valid ← 0 (via valid_reg)
- in_ready ← 1 (via valid_reg = 0)

### 5.2 Reset Recovery
After rst_n de-assertion:
- Module is in EMPTY state
- Ready to accept first input on next clock cycle
- No spurious output valid assertions

---

## 6. Interface Timing Diagrams

### 6.1 Basic Transfer
```
Cycle:     0    1    2    3    4
         _____|‾‾‾‾|____|____|____
CLK     

in_valid _____|‾‾‾‾|____|____|____
in_ready ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
in_data  =====<D0>=================

out_valid_____|____|‾‾‾‾|‾‾‾‾|____
out_ready‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|‾‾‾‾
out_data =====|====<D0>=<D0>=====
```
- Cycle 1: Input accepted (in_valid & in_ready)
- Cycle 2: Output valid asserted
- Cycle 3: Output held (out_ready = 0)
- Cycle 4: Output consumed (out_valid & out_ready)

### 6.2 Backpressure
```
Cycle:     0    1    2    3    4    5
         _____|‾‾‾‾|____|____|____|____
CLK     

in_valid _____|‾‾‾‾|‾‾‾‾|____|____|____
in_ready ‾‾‾‾‾‾‾‾‾‾|____|____|‾‾‾‾‾‾‾‾
in_data  =====<D0>=<D1>===============

out_valid_____|____|‾‾‾‾|‾‾‾‾|‾‾‾‾|____
out_ready_____|____|____|____|‾‾‾‾|____
out_data =====|====<D0>=<D0>=<D0>=====
```
- Cycle 1: D0 accepted
- Cycle 2: in_ready = 0 (backpressure), D1 not accepted
- Cycle 3-4: Output held
- Cycle 5: Output consumed, in_ready = 1

### 6.3 Continuous Stream
```
Cycle:     0    1    2    3    4    5
         _____|‾‾‾‾|____|____|____|____
CLK     

in_valid _____|‾‾‾‾|‾‾‾‾|‾‾‾‾|____|____
in_ready ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
in_data  =====<D0>=<D1>=<D2>==========

out_valid_____|____|‾‾‾‾|‾‾‾‾|‾‾‾‾|____
out_ready‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
out_data =====|====<D0>=<D1>=<D2>=====
```
- Continuous flow: Data passes through with 1 cycle latency

---

## 7. Parameterization

### 7.1 Compile-Time Parameters

| Parameter | Type | Default | Valid Range | Description |
|-----------|------|---------|-------------|-------------|
| DATA_WIDTH | int | 32 | 1 to 1024 | Width of data bus |

### 7.2 Scalability
The design scales linearly with DATA_WIDTH:
- Register area: O(DATA_WIDTH)
- Critical path: Independent of DATA_WIDTH (mux only)
- Max frequency: >400 MHz typical for DATA_WIDTH ≤ 512

---

## 8. Verification Requirements

### 8.1 Functional Coverage
- [ ] All state transitions exercised
- [ ] All transaction combinations tested
- [ ] Backpressure scenarios verified
- [ ] Reset during all states tested
- [ ] Continuous streaming verified
- [ ] Random valid/ready patterns tested

### 8.2 Assertions
The design includes SVA assertions for:
1. No data loss (in_valid && !in_ready → data stable)
2. No duplication (out_data stable when out_valid && !out_ready)
3. Reset clears valid (reset → !out_valid)

### 8.3 Code Coverage
Target: 100% statement, branch, and toggle coverage

---

## 9. Synthesis Considerations

### 9.1 Area
- Minimal: 1 register per data bit + 1 valid bit + control logic
- Estimated: ~35 LUTs + DATA_WIDTH FFs

### 9.2 Timing
- Critical path: out_ready → in_ready (combinational)
- Typically <1ns in modern FPGAs (450+ MHz)

### 9.3 Power
- Clock gating opportunity: Register only when transaction occurs
- Minimal switching activity

---

## 10. Compliance

This design complies with:
- ✅ AMBA AXI-Stream handshake protocol
- ✅ Industry-standard valid/ready semantics
- ✅ IEEE 1800-2017 SystemVerilog standard
- ✅ Synthesizable subset of SystemVerilog

---

## 11. Known Limitations

1. **Single Entry Only**: This is a 1-deep FIFO. For deeper buffering, use FIFO.
2. **Single Clock Domain**: No clock domain crossing support built-in.
3. **No Error Detection**: No parity, ECC, or CRC checking.
4. **No Sideband Signals**: No user/last/keep signals (easily extended).

---

## 12. Extension Points

The design can be extended with:
- Multiple pipeline stages (increase latency, maintain throughput)
- FIFO mode (circular buffer, configurable depth)
- Bypass mode (zero latency when possible)
- Error injection for testing
- Performance counters
- Clock domain crossing logic

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-06 | Initial | First release |

---

**Document Status**: Final  
**Confidentiality**: Public  
**Distribution**: Unlimited
