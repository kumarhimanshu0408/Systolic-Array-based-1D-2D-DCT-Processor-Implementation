# 🔢 Systolic Array-Based 1D/2D DCT Processor Implementation

This project implements a **systolic array architecture** for computing the **1D and 2D Discrete Cosine Transform (DCT)** using **Verilog HDL**. Designed for efficient real-time signal processing, the processor supports high-speed matrix multiplication with deep pipelining and modular design principles.

---

## 📌 Key Features

- ✅ **1D and 2D DCT computation**
- ✅ Systolic array architecture for **parallelism**
- ✅ Designed using **Verilog HDL**
- ✅ Verified against Python/Matlab reference results
- ✅ Handles **8x8 input blocks** for image compression
- ✅ Includes **bit growth analysis**, **latency**, and **throughput** evaluation

---

## 💡 Project Overview

- **Goal:** Efficient hardware implementation of DCT using systolic arrays
- **Use Case:** Image compression (JPEG), signal processing
- **Platform:** Verilog HDL (simulated with Xilinx/ModelSim)
- **Input:** 8x8 grayscale image blocks
- **Output:** 8x8 matrix of DCT coefficients

---

## ⚙️ Architecture Summary

- Each stage in the systolic array performs **Multiply and Accumulate (MAC)**.
- The structure is fully pipelined to improve clock performance.
- **1D DCT** is computed by matrix multiplication: `Y = A * X`
- **2D DCT** is computed as: `Y = A * X * A'`

> `A` is the DCT basis matrix, and `X` is the image input matrix.

---

## 🧪 Modules Implemented

- `matrix_multiplier_8x8.v`: Performs 8x8 matrix multiplication
- `dct_1d.v`: Implements 1D DCT using systolic matrix multiplication
- `dct_2d.v`: Cascades two 1D DCTs for 2D transform
- `testbench.v`: Verilog testbenches for functional simulation
- `python_verify.py`: Verifies Verilog output using NumPy DCT implementation

---

## 📈 Performance Metrics

| Metric             | Value            |
|--------------------|------------------|
| Latency (1D DCT)   | 16 cycles (worst-case) |
| Throughput         | 1 output block every 8 cycles |
| Clock Frequency    | 50–100 MHz (simulated) |
| Bit Growth         | 8-bit input → 16-bit output |

> Bit growth analysis was done to avoid overflow while preserving accuracy.

---

## 🧪 Validation

- Verified 1D and 2D DCT outputs with Python’s NumPy DCT function
- Bit-exact matches were achieved with small rounding errors acceptable in fixed-point arithmetic
- Inputs tested with patterns like ramp, edge, and flat values

---

## 🧰 Tools Used

- Verilog HDL (Xilinx Vivado / ModelSim)
- Python + NumPy (for reference & validation)
- Vivado (waveform visualization)

---

## 🖼️ Sample Input & Output

**Input Matrix:**
```

\[\[52, 55, 61, 66, 70, 61, 64, 73],
\[63, 59, 55, 90, 109, 85, 69, 72],
...]

```

**2D DCT Output:**
```

\[\[507, -30, -61, ..., -5],
\[12, -15, -9, ..., 1],
...]

```

---

## 📂 Repository Structure

```

.
├── dct\_1d.v              # 1D DCT module
├── dct\_2d.v              # 2D DCT module using 1D DCTs
├── matrix\_multiplier.v   # Generic matrix multiplier
├── testbench.v           # Simulation testbench
├── python\_verify.py      # Python code for validation
├── input\_vectors.txt     # Input for simulation
├── output\_results.txt    # Output from Verilog
└── README.md             # Project documentation

```

---
