# JPEG 2000 for Digital Cinema: Wavelet-Based Image Encoder

A simplified JPEG 2000 image encoder implemented in MATLAB, built as a course project
at the Technical University of Denmark (DTU), *34240 Data Science, Compression and
Image Communication* (spring 2026).

The encoder follows the **T-Q-E** structure (Transform, Quantization, Entropy coding)
and is evaluated with bit-rate, entropy and image-quality metrics on the 512 × 512
Lenna test image.

## Overview

Digital cinema distribution uses JPEG 2000 as its compression format. This project
implements the core of that pipeline and studies the trade-off between bit-rate and
image quality as a single parameter, the quantization step size δ, is varied.

| Block | Implementation |
|-------|----------------|
| **T** Transform | 2D Discrete Wavelet Transform, CDF 9/7 filter (`bior4.4`), 3 levels (10 subbands), periodic extension |
| **Q** Quantization | Deadzone scalar quantizer with per-subband step sizes and midpoint reconstruction |
| **E** Entropy coding | 32-bit adaptive arithmetic coder (order-0 model) with E1/E2/E3 rescaling |

In parallel, an **order-1 context model (H1)** estimates the code length of a better
entropy coder. This is an estimate based on cross-entropy, not an actual bitstream.

## Simplifications compared with full JPEG 2000

| Component | Full JPEG 2000 | This project |
|-----------|----------------|--------------|
| Entropy coder | EBCOT (bit-plane coding, MQ-coder) | Adaptive arithmetic coder |
| Bit-rate measure | Actual compressed bitstream | Arithmetic code length + H1 cross-entropy estimate |
| DWT levels | 5-6 (DCI profile) | 3 |
| Test image | 4K cinema frames | 512 × 512 Lenna |
| Step sizes | Derived from filter gains | Heuristic per-subband scaling |

## Results

Results for Lenna (512 × 512, 8 bpp uncompressed):

| δ | bpp (arith) | bpp (H1) | CF (arith) | Redundancy | PSNR (dB) |
|---|-------------|----------|------------|------------|-----------|
| 1 | 3.5751 | 3.2534 | 2.24 | 9% | 50.51 |
| 4 | 1.3198 | 1.0882 | 6.06 | 17.55% | 39.81 |
| 8 | 0.7244 | 0.5353 | 11.04 | 26.10% | 35.73 |
| 16 | 0.4184 | 0.2676 | 19.12 | 36.03% | 31.90 |
| 32 | 0.2578 | 0.1345 | 31.03 | 47.85% | 28.63 |
| 64 | 0.1949 | 0.0826 | 41.05 | 57.64% | 26.56 |
| 128 | 0.1746 | 0.0650 | 45.82 | 62.79% | 26.23 |

Main findings:

- The arithmetic code length exceeds the H1 estimate by 9% to 63%, and the gap grows
  with δ. The order-0 model cannot exploit the first-order correlations between
  coefficients that the H1 model captures.
- At the DCI reference rate of 1.5 bpp, the arithmetic coder reaches about 39.8 dB
  (δ = 4), roughly 5 dB below the 45 dB target. This is attributed to the simplified
  entropy coder, the 3-level DWT and the heuristic step sizes.
- The rate-distortion curve shows the expected shape: steep improvement at low rates
  and diminishing returns at high rates.

The full analysis, including the rate-distortion curve and the reconstructed images
for every δ, is in the report: [link to the PDF, or `report/JPEG2000_report.pdf`].

## Requirements

- MATLAB R2021b or later
- Wavelet Toolbox (`wfilters`, `dwt`, `idwt2`, `dwtmode`)
- Image Processing Toolbox (`imread`, `im2gray`)
- Test image: `lenna.tif` (512 × 512, 8-bit grayscale). It is not included in this
  repository, so place your own copy in the same folder as the script.

## How to run

1. Put `final_code.m` and `lenna.tif` in the same folder.
2. In the MATLAB Command Window, run:

```matlab
   >> run('final_code.m')
```

The script prints a per-δ table (code length, entropy estimate, redundancy, PSNR),
shows the reconstructed images for all step sizes, plots the rate-distortion curve and
prints the summary table.

## Key parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `num_levels` | 3 | Number of DWT decomposition levels |
| `delta_values` | [1, 4, 8, 16, 32, 64, 128] | Quantization step sizes to evaluate |
| `filter` | `'bior4.4'` | CDF 9/7 wavelet filter |
| `alpha` (H1) | 1 | Laplace smoothing parameter for the entropy estimate |

## Repository structure

```
final_code.m      Main script: runs the full pipeline and produces the results
[other files]     [e.g. separate function files, if you split the code]
report/           Project report (PDF)
```

## Output interpretation

- **bpp (arith):** actual arithmetic code length in bits per pixel
- **bpp (H1):** lower-bound estimate from an adaptive first-order context model
- **Redundancy (%):** share of the arithmetic bitstream that a better context model
  would remove
- **PSNR:** objective quality. Values above 45 dB are the usual digital-cinema target.

## Use of AI tools

GitHub Copilot was used for parts of the MATLAB code, mainly the adaptive entropy
coding, and Claude was used to improve the structure and clarity of the report. All
suggestions were reviewed, tested and modified, and all numerical results come from
running the code on the test image.

## Author

Leonor Castelo, MSc Statistics (Machine Learning), University of Copenhagen
leonornunescastelo@gmail.com
