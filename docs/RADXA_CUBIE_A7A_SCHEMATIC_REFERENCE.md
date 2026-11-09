# Radxa Cubie A7A Hardware Schematic Reference

**Board**: Radxa Cubie A7A  
**Schematic Version**: V1.10 (Project Code: `RS501`, Radxa Ltd.)  
**Document Source**: [radxa_cubie_a7a_v1.10_schematic.pdf](https://dl.radxa.com/cubie/a7a/docs/hw/radxa_cubie_a7a_v1.10_schematic.pdf)  
**Main SoC**: Allwinner A733 (`sun60iw2p1`) — Octa-core ARM (4× Cortex-A76 @ up to 2.0 GHz + 4× Cortex-A55 @ up to 1.8 GHz, ARM Mali-G57 MC2 GPU, 3 TOPs NPU)  

---

## 1. Document Architecture & Sheet Index

The schematic consists of 19 operational pages:

| Sheet # | Sheet Title / Section | Description & Key Components |
|:---:|:---|:---|
| **01** | Cover Sheet | Project Title (`RS501`), Hardware Revision (`V1.10`), Date |
| **02** | Index | Official page directory and sheet index |
| **03** | System Block Diagram | High-level interconnection between A733 SoC, PMIC, DRAM, Storage, and Peripherals |
| **04** | Power Tree & PMIC (AXP318) | Allwinner AXP318 PMIC, DC-DC buck converters, LDO linear regulators, SY8089A1AAC 5V-to-3.3V converter |
| **05** | DRAM (LPDDR5 / LPDDR4x) | 32-bit discrete DRAM interface, high-speed matching networks, VDD2L / VDDQ / VDD18 decoupling |
| **06** | A733 Analog & High-Speed I/O | Combo PHYs (PCIe / USB 3.0 / DP), ADC inputs, Board ID detection, reference resistors |
| **07** | A733 Digital GPIO & Multiplexing | Port B, C, D, E, G, H, J, K, L, M pinmux configurations, JTAG, MIPI DSI / CSI interfaces |
| **08** | A733 System Core & Clocks | 26 MHz DCXO main crystal, 32.768 kHz RTC clock, core power balls (VDD-CPUB, VDD-CPUL, VDD-GPU, VDD-SYS, VDD-VE) |
| **09** | eMMC / UFS / SPI NOR Flash | UFS 2.2 / 3.1 socket / footprint, eMMC 5.1 interface, Winbond W25Q64FWZPIG 64Mb SPI NOR Flash |
| **10** | MIPI DSI Display & Touch (CTP) | 4-lane MIPI DSI FPC connector (`J10`), backlight boost driver Silergy SY7203DBC, I2C touch (CTP) |
| **11** | Camera Interface (MIPI CSI) | 4-lane MIPI CSI camera FPC connector (`J7`), camera MCLKs, I2C control bus (TWI3) |
| **12** | Audio Codec (AC101 / AC101B) | X-Powers AC101 audio codec, 3.5mm TRRS headphone/mic jack (`J8`), HP detect (`PL11`), I2S0 bus |
| **13** | Wireless Connectivity (Wi-Fi / BT) | FCU760K / FCU760KAAMD Wi-Fi 6 + Bluetooth 5.4 module (USB / SDIO), IPEX MHF antenna connector (`J1`) |
| **14** | USB Subsystem (USB 3.0 / USB 2.0 / Hub) | USB 3.0 Type-A host, Terminus FE1.1S 4-port USB 2.0 Hub (`U6`), SGMICRO SGM2576 power switches |
| **15** | USB Type-C (USBC0) & MicroSD Card | Type-C 16-pin power/OTG port (`J16`), MicroSD slot (`J14` / `SDC0`), VBUS detect, ESD protection |
| **16** | Expansion Interfaces (PCIe & 40-Pin Header)| PCIe 2.1 x1 FPC interface (`J3`), 40-pin Raspberry Pi compatible GPIO header (`J11`), level shifters (UM3304 / UM3204H) |
| **17** | HDMI Output | HDMI 2.0a Type-A receptacle (`J5`), TMDS level shifters/ESD, DDC I2C channel, CEC line |
| **18** | Gigabit Ethernet (10/100/1000M) | Motorcomm MAE0621A-Q3C RGMII Gigabit PHY (`U10`), RJ45 MagJack with PoE header support (`J9`) |
| **19** | User I/O, RTC, LEDs & Fan Header | Hym8563TS I2C RTC (`U12`), PWM fan connector (`J15`), Power/User LEDs, MaskROM / FEL & Recovery buttons |

---

## 2. Power Subsystem Architecture

The board is powered via a 5.0V USB Type-C connector (`J16`). Core power management is performed by the **X-Powers AXP318** PMIC paired with discrete DC-DC buck regulators.

### 2.1 Power Rail Mapping

| Rail Name | Regulator Source | Output Voltage | Targeted Block / Peripheral |
|:---|:---|:---|:---|
| `VDD-CPUB` | AXP318 DCDC1 | 0.8V – 1.15V | A733 Cortex-A76 Big Cluster Core |
| `VDD-CPUL` | AXP318 DCDC2 | 0.8V – 1.05V | A733 Cortex-A55 Little Cluster Core |
| `VDD-GPU` | AXP318 DCDC3 | 0.8V – 0.96V | Mali-G57 MC2 Graphics Core |
| `VDD-SYS` | AXP318 DCDC4 | 0.8V – 0.95V | A733 System Logic & Interconnect |
| `VDD-DRAM` | AXP318 DCDC5 | 0.5V / 0.6V / 1.1V | LPDDR5 VDD Core / LPDDR4x VDD |
| `VCC-DRAML` | AXP318 DCDC6 | 0.8V / 1.1V | DRAM Low-Voltage Controller & I/O |
| `VCC-VDDQ` | AXP318 DCDC7 | 0.5V / 0.6V | LPDDR5 VDDQ I/O Supply |
| `VCC09-VDD2L`| AXP318 DCDC8 | 0.8V – 0.9V | LPDDR5 VDD2L Rail |
| `VCC-IO` | AXP318 ALDO1 | 3.3V | General 3.3V I/O domain (GPIOs, PM, PC) |
| `VCC-PLL` | AXP318 ALDO2 | 1.8V | Analog PLLs and clock generators |
| `VCC33-CODEC`| AXP318 ALDO5 | 3.3V | AC101 Audio Codec Analog VDD |
| `VCC18-CODEC`| AXP318 BLDO1 | 1.8V | AC101 Digital / I2S core supply |
| `VCC18-HDMI` | AXP318 BLDO4 | 1.8V | HDMI Controller & SNPS PHY 1.8V rail |
| `VCC-PJ` | AXP318 BLDO4 | 1.8V / 3.3V | Port J I/O voltage domain |
| `VCC18-LCD` | AXP318 BLDO5 | 1.8V | MIPI DSI Display logic I/O |
| `VDD08-HDMI` | AXP318 CLDO1 | 0.8V | HDMI SNPS PHY core rail |
| `VCC-DCXO` | AXP318 CLDO2 | 1.8V | 26 MHz DCXO Reference Crystal Supply |
| `VCC-UFS-IO` | AXP318 CLDO3 | 1.2V / 1.8V | UFS Flash interface I/O |
| `AVDD-H-COMB0`| AXP318 CLDO5 | 1.8V | SerDes Combo-PHY 0 (PCIe / USB3 / DP) |
| `VCC18-UFS` | AXP318 DLDO1 | 1.8V | UFS 2.2 / 3.1 Flash Core |
| `VCC-CARD` | AXP318 SW2 | 3.3V (switched) | MicroSD Card VCC supply |
| `VCC-RTC` | AXP318 RTCLDO | 1.8V / 3.0V | A733 Internal RTC & Hym8563 Real-Time Clock |
| `VCC5V0_SYS` | Direct from Type-C | 5.0V | Main 5V system rail, USB VBUS, SY7203 backlight |
| `VCC-3V3` | SY8089A1AAC (Buck) | 3.3V @ 2A | Board-wide 3.3V rail (40-pin header, Hub, Peripherals) |

---

## 3. Storage Subsystem

1. **MicroSD Card Interface (`SDC0`)**:
   - Driven directly by A733 Port F (`PF0`–`PF5`).
   - Signals: `SDC0-D0` (PF0), `SDC0-D1` (PF1), `SDC0-D2` (PF2), `SDC0-D3` (PF3), `SDC0-CLK` (PF4), `SDC0-CMD` (PF5).
   - Card Detect: `SDC0-DET` mapped to `PF6`.
   - Power switched by PMIC `SW2` (`VCC-CARD`).
2. **eMMC / UFS Socket**:
   - Universal high-speed storage interface supporting either eMMC 5.1 (Port C) or UFS 2.2/3.1 (SerDes lanes).
   - UFS Differential Pairs: `UFS-TX0-P/N`, `UFS-TX1-P/N`, `UFS-RX0-P/N`, `UFS-RX1-P/N`, `UFS-CLK-AP`, `UFS-RST-N`.
3. **SPI NOR Flash (`U7`)**:
   - Model: **Winbond W25Q64FWZPIG** (64 Mbit / 8 MB, 1.8V, DFN8/WSON package).
   - Connected via `SPI0`: `SPI0-CS0` (PC0), `SPI0-CLK` (PC1), `SPI0-MOSI` (PC2), `SPI0-MISO` (PC3).

---

## 4. Connectivity & Networking

### 4.1 Gigabit Ethernet (10/100/1000M)
- **PHY Transceiver**: **Motorcomm MAE0621A-Q3C** (`U10`), RGMII interface.
- **MAC Interface**: Connected to Allwinner A733 `GMAC0` controller.
- **Management Bus (MDIO)**: `MDC` (PA0), `MDIO` (PA1).
- **RGMII Lines**:
  - TX: `TXCLK` (PA2), `TXEN` (PA3), `TXD0` (PA4), `TXD1` (PA5), `TXD2` (PA6), `TXD3` (PA7).
  - RX: `RXCLK` (PA8), `RXDV` (PA9), `RXD0` (PA10), `RXD1` (PA11), `RXD2` (PA12), `RXD3` (PA13).
- **Control Pins**:
  - Hardware Reset: `PHY_RSTn` tied to `PH16` (Active-LOW).
  - Clock Source: 25.000 MHz Crystal (`Y2`) + internal PLL.
- **Connector**: RJ45 MagJack (`J9`) with integrated magnetics and PoE header pins.

### 4.2 Wi-Fi 6 & Bluetooth 5.4
- **Module Footprint (`U3`)**: **FCU760K / FCU760KAAMD** integrated wireless module.
- **Interface**: USB 2.0 channel 4 (`USB4_DP` / `USB4_DM`) for Wi-Fi; High-Speed UART + PCM audio for Bluetooth.
- **Power & Control GPIOs**:
  - Wi-Fi Power Regulator Enable (`WL-REG-EN`): `PM0` (via `Q8` WPM2015 P-channel MOSFET switch).
  - Wi-Fi Chip Enable (`WL-REG-ON`): `PM1`.
  - Bluetooth Reset (`BT-RST-N`): `PM2`.
  - Bluetooth Host Wakeup (`BT-HOST-WAKE`): `PM4`.
- **RF**: 50Ω impedance matched trace to IPEX / MHF-I U.FL antenna jack (`J1`).

---

## 5. USB & PCIe Interfaces

### 5.1 USB Ports
- **USB Type-C (`J16`)**:
  - Primary 5V DC power input + USB 2.0 OTG channel (`USB0_DP` / `USB0_DM`).
  - VBUS power switch control: `USB0-DRVVBUS` mapped to `PL2`.
- **USB 3.0 Type-A (Bottom Port of `U2`)**:
  - SuperSpeed transceiver connected to Combo PHY 0 (`USB_SSRX0P/N`, `USB_SSTX0P/N`).
  - High-Speed USB 2.0 lines routed to `USB1_DP` / `USB1_DM`.
  - VBUS power distribution switched by SGMICRO `SGM2576YN5G/TR` (`U5`) controlled via `PM5`.
- **USB 2.0 Type-A Hub (Top Port of `U2`)**:
  - Downstream port from **Terminus FE1.1S** USB 2.0 4-Port Hub (`U6`).
  - Upstream port connected to A733 `USB2_DP` / `USB2_DM`.

### 5.2 PCIe Expansion
- **Interface**: PCIe Gen 2.1 x1 lane on 16-pin FPC connector (`J3`).
- **Signals**:
  - Reference Clock: `PCIE1-CLKP` / `PCIE1-CLKN` (100 MHz differential).
  - Data Lanes: `PCIE1-TX0P/N` and `PCIE1-RX0P/N`.
  - Control Signals (level shifted to 3.3V via UM3304 `U20`):
    - `PCIE-PERSTn`: Reset signal (Active LOW) mapped to `PD22`.
    - `PCIE-WAKEn`: Wakeup input mapped to `PD21`.
    - `PCIE-CLKREQn`: Clock request mapped to `PD20`.

---

## 6. Display & Camera Interfaces

### 6.1 HDMI 2.0a Output
- **Connector**: Standard 19-pin HDMI Type-A receptacle (`J5`).
- **Data Lanes**: 4 TMDS differential pairs (`HTX0P/N`, `HTX1P/N`, `HTX2P/N`, `HTXCP/N`) routed with MCZ1210AH900L2 common-mode chokes and ESD5311N protection arrays.
- **Auxiliary Lines**:
  - DDC I2C: `HDMI-SCL` (`PE7` / I2C11), `HDMI-SDA` (`PE8` / I2C11).
  - Consumer Electronics Control (CEC): `HDMI-CEC` mapped to `PE6`.
  - Hot-Plug Detect (HPD): Level-shifted to 1.8V domain.

### 6.2 MIPI DSI Display
- **Connector**: 30-pin 0.5mm FPC connector (`J10`).
- **Lanes**: 4-lane MIPI DSI differential pairs (`MIPI-DSI0-DP0..3`, `MIPI-DSI0-DN0..3`, `MIPI-DSI0-CKP/N`).
- **Backlight Boost Converter**: Silergy **SY7203DBC** (`U18`) providing constant current LED backlight drive, enabled/modulated by `LCD-PWM` (`PE4`).
- **Capacitive Touch (CTP)**: I2C bus `TWI2` (`PE1`/`PE2`) with `CTP-RST` and `CTP-INT`.

### 6.3 MIPI CSI Camera
- **Connector**: 24-pin 0.5mm FPC connector (`J7`).
- **Lanes**: 4-lane MIPI CSI input (`MCSIB-D0..3P/N`, `MCSIB-CKP/N`).
- **Control Bus**: `TWI3` I2C bus (`PE3`/`PE4`), Camera Master Clocks (`CAM0-CLK`, `CAM1-CLK`), reset and powerdown GPIOs.

---

## 7. Audio Subsystem (AC101)

- **Codec IC**: X-Powers **AC101 / AC101B** (`U8`), low-power audio codec with integrated headphone amplifier.
- **Audio Interface**: Digital audio over Allwinner `I2S0`:
  - `I2S0-MCLK` (PH0), `I2S0-BCLK` (PH1), `I2S0-LRCK` (PH2), `I2S0-DOUT0` (PH3), `I2S0-DIN0` (PH4).
- **Control Interface**: I2C control bus (`AUDIO-SCL` / `AUDIO-SDA`).
- **Headphone Jack (`J8`)**: 3.5mm 4-pole TRRS audio connector with mic support and mechanical plug insertion detect (`HP-DET-PL11` on `PL11`).

---

## 8. 40-Pin Expansion Header (`J11`)

The 40-pin 2.54mm dual-row header (`J11`) follows standard SBC conventions:

```
                  +3.3V  ( 1) ( 2)  +5.0V
      (I2C7_SDA)    PB1  ( 3) ( 4)  +5.0V
      (I2C7_SCL)    PB0  ( 5) ( 6)  GND
     (UART6_TX)    PE0  ( 7) ( 8)  PK22  (UART1_TX)
                    GND  ( 9) (10)  PK23  (UART1_RX)
                    PL6  (11) (12)  PE5   (PWM0-2)
                    PL7  (13) (14)  GND
     (PWM0-1)      PE4  (15) (16)  PK8
                  +3.3V  (17) (18)  PK7
    (SPI1_MOSI)    PB2  (19) (20)  GND
    (SPI1_MISO)    PB3  (21) (22)  PK6
     (SPI1_CLK)    PB4  (23) (24)  PB5   (SPI1_CS0)
                    GND  (25) (26)  PK5
      (I2C2_SDA)    PE2  (27) (28)  PE1   (I2C2_SCL)
                    PJ2  (29) (30)  GND
                    PJ3  (31) (32)  PJ16  (PWM1-8)
     (PWM1-9)      PJ27  (33) (34)  GND
    (I2S4_BCLK)    PK0  (35) (36)  PK1   (I2S4_MCLK)
    (I2S4_DIN0)    PK2  (37) (38)  PK3   (I2S4_DOUT0)
                    GND  (39) (40)  PK4   (I2S4_LRCK)
```

---

## 9. RTC, Buttons, LEDs & Fan Header

1. **Real-Time Clock (RTC)**:
   - IC: **Haoyu HYM8563TS** (`U12`) connected to PMIC I2C bus `r_i2c1` at 7-bit slave address `0x51`.
   - Crystal: 32.768 kHz precision quartz (`Y1`).
   - Interrupt Line: `RTC_INT_L` routed to `PL3`.
   - Backup battery: Dedicated 2-pin coin-cell / capacitor connector.
2. **Status LEDs**:
   - **Green Power LED** (`LED2`): Connected to `PJ26` (Active-LOW, illuminated on power).
   - **Blue User LED** (`LED1`): Connected to `PJ27` (Active-HIGH, software heartbeat).
3. **Buttons**:
   - **Power Button** (`PWR_ON`): Connected to AXP318 `PMU-PWRON` pin.
   - **FEL / U-Boot Recovery Key**: Tied to `LRADC0` input for Allwinner USB FEL mode entry during boot.
   - **Reset Key**: Hardware reset asserting system reset to PMIC and SoC.
4. **Cooling Fan Header (`J15`)**:
   - 2-pin / 3-pin connector driven by `S_PWM0_7_FAN` PWM line via MOSFET switch for dynamic thermal control.
