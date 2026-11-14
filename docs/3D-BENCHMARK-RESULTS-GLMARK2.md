# Radxa Cubie A7A - 3D Graphics Benchmark Report (glmark2-es2)

**Board:** Radxa Cubie A7A  
**SoC:** Allwinner A733 (sun60iw2p1)  
**CPU:** 8x Cortex-A55 / Cortex-A76 cores  
**Memory:** 8GB LPDDR5  
**Display Server:** X.Org X Server 1.21.1.16 on LightDM 1.32.0  
**Display Output:** HDMI-A-1 (Native 2560x1440 @ 60 Hz)  
**Date:** November 9, 2026  

---

## 1. Executive Summary

This report documents the baseline OpenGL ES 2.0 / 3D rendering benchmark executed on the live Radxa Cubie A7A system running Debian Trixie with Linux kernel 6.18.62-sun60iw2.

The benchmark was executed under two display configurations:
1. **Windowed Mode (800x600)** - Standard comparative test resolution.
2. **Native Fullscreen Mode (2560x1440 QHD)** - Full resolution stress test on the connected HDMI monitor.

Both test suites ran to completion with zero crashes, rendering artifacts, or kernel DRM stalls.

---

## 2. Driver & Graphics Stack Architecture

```
+-------------------------------------------------------+
|                    glmark2-es2                        |
+-------------------------------------------------------+
|          Mesa 25.0.7-2+deb13u1 (libGLESv2)            |
+-------------------------------------------------------+
|          llvmpipe (LLVM 19.1.7, 128-bit SIMD)         |
+-------------------------------------------------------+
|             Xorg Display Server (:0 VT 7)             |
+-------------------------------------------------------+
|       modesetting driver (/dev/dri/card0 kmsdev)      |
+-------------------------------------------------------+
|          sunxi-drm (Allwinner Display Engine 3.3)     |
+-------------------------------------------------------+
|                    HDMI Display                       |
+-------------------------------------------------------+
```

* **DRM Display Controller:** `/dev/dri/card0` (`sunxi-drm`)
* **DRM 3D Accelerator:** `/dev/dri/card2` (`powervr`, Rogue firmware `rogue_36.56.104.183_v1.fw` active)
* **OpenGL Renderer String:** `llvmpipe (LLVM 19.1.7, 128 bits)`
* **OpenGL Version String:** `OpenGL ES 3.2 Mesa 25.0.7-2+deb13u1`
* **Xorg Configuration:** `/etc/X11/xorg.conf.d/20-modesetting.conf`

---

## 3. Benchmark Results Comparison

| Scene / Benchmark Test | Windowed (800x600) | Fullscreen (2560x1440) | Fullscreen FrameTime | Description |
| :--- | :--- | :--- | :--- | :--- |
| **build:use-vbo=false** | **86 FPS** | **28 FPS** | 36.80 ms | Mesh vertex processing without VBO |
| **build:use-vbo=true** | **88 FPS** | **28 FPS** | 35.98 ms | Mesh vertex processing with VBO |
| **texture:filter=nearest** | **171 FPS** | **30 FPS** | 34.24 ms | Point-sampled texture mapping |
| **texture:filter=linear** | **156 FPS** | **29 FPS** | 35.33 ms | Bilinear texture filtering |
| **texture:filter=mipmap** | **130 FPS** | **26 FPS** | 38.63 ms | Trilinear mipmapped texture |
| **shading:shading=gouraud** | **59 FPS** | **25 FPS** | 40.89 ms | Per-vertex lighting interpolation |
| **shading:shading=blinn-phong-inf** | **55 FPS** | **23 FPS** | 45.33 ms | Infinite light Blinn-Phong specular |
| **shading:shading=phong** | **48 FPS** | **21 FPS** | 47.96 ms | Per-pixel Phong specular evaluation |
| **shading:shading=cel** | **49 FPS** | **22 FPS** | 46.05 ms | Quantized cel-shading step |
| **bump:bump-render=normals** | **147 FPS** | **29 FPS** | 35.21 ms | Normal map evaluation |
| **bump:bump-render=height** | **138 FPS** | **28 FPS** | 36.06 ms | Parallax / height perturbation |
| **bump:bump-render=high-poly** | **31 FPS** | **17 FPS** | 59.12 ms | High triangle count geometric load |
| **effect2d (edge detection)** | **90 FPS** | **15 FPS** | 71.31 ms | 3x3 convolution kernel |
| **effect2d (wide kernel)** | **48 FPS** | **7 FPS** | 143.04 ms | 5x5 multi-tap convolution |
| **pulsar** | **142 FPS** | **25 FPS** | 40.32 ms | Transparent quad blending |
| **desktop:blur** | **22 FPS** | **5 FPS** | 217.40 ms | Multi-pass separable Gaussian blur |
| **desktop:shadow** | **43 FPS** | **9 FPS** | 118.21 ms | Multi-window drop shadow simulation |
| **buffer:interleave=false (map)** | **49 FPS** | **19 FPS** | 55.41 ms | Buffer mapping memory updates |
| **buffer:interleave=false (subdata)** | **50 FPS** | **19 FPS** | 53.44 ms | Buffer subdata stream transfer |
| **buffer:interleave=true (map)** | **49 FPS** | **19 FPS** | 53.37 ms | Interleaved vertex attribute streaming |
| **ideas** | **59 FPS** | **22 FPS** | 46.33 ms | Complex flat-shaded model rotation |
| **jellyfish** | **40 FPS** | **12 FPS** | 84.79 ms | Procedural skinned vertex animation |
| **terrain** | **4 FPS** | **1 FPS** | 1247.13 ms | Ray-marched volumetric procedural terrain |
| **shadow** | **47 FPS** | **16 FPS** | 65.96 ms | Projected shadow map pass |
| **refract** | **8 FPS** | **4 FPS** | 307.79 ms | Multi-pass environment refraction |
| **conditionals (0/0)** | **94 FPS** | **26 FPS** | 39.00 ms | Baseline shader control-flow |
| **conditionals (5/0)** | **86 FPS** | **25 FPS** | 40.06 ms | Fragment dynamic branching |
| **conditionals (0/5)** | **92 FPS** | **27 FPS** | 38.37 ms | Vertex dynamic branching |
| **function:low** | **88 FPS** | **26 FPS** | 39.20 ms | Low arithmetic shader calls |
| **function:medium** | **83 FPS** | **25 FPS** | 40.97 ms | Nested trigonometric evaluations |
| **loop:non-uniform** | **84 FPS** | **25 FPS** | 40.28 ms | Static loop execution |
| **loop:uniform=false** | **92 FPS** | **26 FPS** | 39.88 ms | Divergent fragment loop evaluation |
| **loop:uniform=true** | **81 FPS** | **24 FPS** | 42.11 ms | Uniform-bounded loop iteration |
| **OVERALL GLMARK2 SCORE** | **75** | **19** | - | - |

---

## 4. Key Observations & Hardware Performance Analysis

1. **A733 CPU Multithreading & LLVM SIMD:**
   The A733 octa-core CPU achieves **~88 FPS in standard 3D mesh rendering** and **up to 171 FPS in texture mapping** purely using software rasterization (`llvmpipe` utilizing ARM NEON SIMD vector instructions).
2. **Resolution Scaling:**
   At 2560x1440 (3.68 million pixels per frame, 7.7x larger fillrate workload than 800x600), basic geometric and texturing workloads sustained **25-30 FPS**, proving the system has sufficient CPU and memory bandwidth for smooth GUI rendering at 1440p even before native GPU hardware shaders take over.
3. **PowerVR Rogue Hardware Driver Path:**
   The kernel driver `powervr.ko` initialized minor 2 with firmware `rogue_36.56.104.183_v1.fw`. Once the userland `pvr` Mesa driver or Imagination DDK binaries (`libVK_IMG.so` / `libGLESv2_IMG.so`) are linked with Mesa's Zink/KMSRO wrapper, fillrate-heavy scenes (terrain, refract, blur) will switch from CPU rasterization directly to the PowerVR Rogue core.
