# SERENE

Can't hear your friend talking on the highway? Do you need to blast your music just to hear it well? Well, you're in luck, because **Serene** is a portable noise-cancelling device that can remove all of that noise!

Just stick it to the roof of your car, and Serene will capture the road noise and output sounds waves that cancel them out, so that you can enjoy a peaceful car ride. 

Serene is a small, portable device that connects directly to your phone and car speaker. It sticks seamlessly to the walls of your car, and using ANC algorithms, it minimizes the external noise that it picks up inside the car.  

---

## Inspiration 

During family road trips, I sat in the backseat as a child, and if I didn't yell, my parents in the front couldn't hear me. This was so annoying, as a long highway drive almost always came with losing my voice. 

With my dad's hearing getting worse, I figured that we needed a way to drown out the road noise. I was desparate for a solution, so taking inspiration from noise-cancelling technology in headphones, I thought: "What if we did the same thing in cars?". 

While a few very luxury cars offer ANC, I wanted to make ANC more accessible to all people, because everyone deserves sereneness!

---

## How to use Serene

1. Click the power ON button at the top of the casing. 
2. Download the Serene app and pair your mobile device through Bluetooth / AUX / USB. 
3. Proceed with the calibration process.
4. Stick the Serene device anywhere in your car.
5. Turn the car on and start your peaceful drive.

---

## 3D Model

### PCB:
<img src="https://github.com/user-attachments/assets/7ac86c27-29ce-4630-ba3a-70ae58f0bd60" width="65%">
<img src="https://github.com/user-attachments/assets/e35c6efb-e188-4985-9bd6-9fb9750783b0" width="65%">

### Casing:
<img src="https://github.com/user-attachments/assets/a1ef4850-2492-4c4f-aa21-fb156484d491" width="60%">
<img src="https://github.com/user-attachments/assets/13c21e6f-37f3-41f0-8109-21be4e4fdf20" width="60%">

---

## PCB
<img src="https://github.com/user-attachments/assets/b163734b-e3cd-4c76-bce3-792532eaf435" width="35%">

---

## Wiring Diagram
<img src="https://github.com/user-attachments/assets/f642dc4a-51fe-4a3d-9341-d7e705c53a9a" width="75%">

---

## BOM
| Quantity | Part Name                               | Compoenent                                                    | Price(1 Quantity) | Total Price for all quantiy | Link                                                                              | Status    |
|----------|-----------------------------------------|---------------------------------------------------------------|-------------------|-----------------------------|-----------------------------------------------------------------------------------|-----------|
| 1        | WQFN-HR18__RYK_TEX                      | Power Chip                                                    | $2.48             | $2.48                       | https://jlcpcb.com/partdetail/TexasInstruments-BQ25620RYKR/C6164243               | In Stock  |
| 2        | CONN_X.FL-R-SMT-180_HIR                 | Coaxial Connector for bluetooth and UWB antennas              | $0.27             | $0.53                       | https://jlcpcb.com/partdetail/HRS_Hirose-X_FL_R_SMT_1_80/C434819                  | In Stock  |
| 17       | C_0402_1005Metric                       | Capacitor, 0.1uF                                              | $0.00             | $0.03                       | https://jlcpcb.com/partdetail/MurataElectronics-GRM155R71C104KA88D/C71629         | In Stock  |
| 1        | C_0402_1005Metric                       | Capacitor, 47nF                                               | $0.00             | $0.00                       | https://jlcpcb.com/partdetail/MurataElectronics-GRM155R71E473KA88D/C77017         | In Stock  |
| 1        | Spark_SR1120_QFN32                      | UWB Chip, used for audio transmission                         | $16.54            | $16.54                      | https://jlcpcb.com/partdetail/SPARKMicrosystems-SR1120AA_4Q32TR/C47090725         | Pre-Order |
| 1        | SOT-23-5                                | 1.8V Power Regulator                                          | $0.11             | $0.11                       | https://jlcpcb.com/partdetail/DiodesIncorporated-AP2112K_18TRG1/C176944           | In Stock  |
| 2        | Infineon_PG-LLGA-5-2                    | Mics                                                          | $10.28            | $20.56                      | https://www.aliexpress.com/i/1005008454918413.html                                | In Stock  |
| 1        | USB_C_Receptacle_GCT_USB4085            | USB C Port (USB 2.0)                                          | $1.19             | $1.19                       | https://jlcpcb.com/partdetail/8061907-USB4085_GFA/C7095263                        | In Stock  |
| 1        | Jack_3.5mm_CUI_SJ2-3593D-SMT_Horizontal | Headphone Jack                                                | $11.30            | $11.30                      | https://jlcpcb.com/partdetail/CUI-SJ2_3593D_SMTTR/C4991621                        | In Stock  |
| 4        | R_0402_1005Metric                       | Resistor, 100kΩ                                               | $0.01             | $0.04                       | https://jlcpcb.com/partdetail/YAGEO-RC0402FR07100KL/C60491                        | In Stock  |
| 1        | STM32H743ZIT6                           | Microcontroller, STM32H743ZIT6                                | $8.19             | $8.19                       | https://jlcpcb.com/partdetail/STMicroelectronics-STM32H743ZIT6/C114408            | In Stock  |
| 7        | C_0402_1005Metric                       | Capacitor, 10uF                                               | $0.01             | $0.07                       | https://jlcpcb.com/partdetail/MurataElectronics-GRM155R60J106ME44D/C76991         | In Stock  |
| 1        | C_0402_1005Metric                       | Capacitor, 4.7µF                                              | $0.01             | $0.01                       | https://jlcpcb.com/partdetail/313626-GRM155R61A475MEAAD/C335105                   | In Stock  |
| 1        | ADXL382_Ultralib                        | Vibration Sensor, used for predicting sound                   | $28.05            | $28.05                      | https://jlcpcb.com/partdetail/AnalogDevices-ADXL382_1BCCZRL7/C41718413            | In Stock  |
| 1        | L_0603_1608Metric                       | Inductor, 180nH                                               | $0.09             | $0.09                       | https://jlcpcb.com/partdetail/MurataElectronics-LQW18ANR18G80D/C162650            | In Stock  |
| 1        | Crystal_SMD_3225-4Pin_3.2x2.5mm         | Crystal, 32.768 kHz                                           | $0.49             | $0.49                       | https://jlcpcb.com/partdetail/AbraconLLC-ABS07_32_768KHZT/C130253                 | In Stock  |
| 5        | C_0402_1005Metric                       | Capacitor, 1uF                                                | $0.01             | $0.05                       | https://jlcpcb.com/partdetail/MurataElectronics-GRM155R61A105KE15D/C76999         | In Stock  |
| 6        | C_0402_1005Metric                       | Capacitor, 10pF                                               | $0.01             | $0.06                       | https://jlcpcb.com/partdetail/MurataElectronics-GRM1555C1H100JA01D/C76946         | In Stock  |
| 1        | ADAU1787_Ultralib                       | DSP(Digital Signal Processor) used for processing sound       | $19.07            | $19.07                      | https://jlcpcb.com/partdetail/AnalogDevices-ADAU1787BCBZRL7/C3226201              | In Stock  |
| 1        | SOT-223-3_TabPin2                       | 3.3V Power Regulator                                          | $0.29             | $0.29                       | https://jlcpcb.com/partdetail/DiodesIncorporated-AP7361C_33E13/C500795            | In Stock  |
| 2        | R_0402_1005Metric                       | Resistor, 5.1k                                                | $0.01             | $0.02                       | https://jlcpcb.com/partdetail/YAGEO-RC0402FR075K1L/C105872                        | In Stock  |
| 1        | L_0603_1608Metric                       | Inductor, 1.5uH                                               | $0.10             | $0.10                       | https://jlcpcb.com/partdetail/MurataElectronics-DFE252012F_1R5MP2/C909806         | In Stock  |
| 1        | BGM220S_SIL                             | Bluetooth Chip                                                | $13.84            | $13.84                      | https://jlcpcb.com/partdetail/1603489-BGM220SC12WGA2R/C1512693                    | Pre-Order |
| 1        | Crystal_SMD_3225-4Pin_3.2x2.5mm         | Crystal                                                       | $0.08             | $0.08                       | https://jlcpcb.com/partdetail/YXC_CrystalOscillators-X322525MQB4SI/C70585         | In Stock  |
| 1        | Balun_Johanson_1.6x0.8mm                | Transformer                                                   | $8.97             | $8.97                       | https://jlcpcb.com/partdetail/YXC_CrystalOscillators-X322525MQB4SI/C70585         | In Stock  |
| 2        | R_0402_1005Metric                       | Resistor, 2.2kΩ                                               | $0.01             | $0.02                       | https://jlcpcb.com/partdetail/YAGEO-RC0402FR072K2L/C114762                        | In Stock  |
| 1        | R_0402_1005Metric                       | Resistor, 170Ω                                                | $0.01             | $0.01                       | https://jlcpcb.com/partdetail/YAGEO-RC0402FR07180RL/C138045                       | In Stock  |
| 5        | R_0402_1005Metric                       | Resistor, 10kΩ                                                | $0.01             | $0.05                       | https://jlcpcb.com/partdetail/YAGEO-RC0402FR0710KL/C60490                         | In Stock  |
| 2        | C_0402_1005Metric                       | Capacitor, 2.2uF                                              | $0.01             | $0.02                       | https://jlcpcb.com/partdetail/MurataElectronics-GRM155R61A225KE95D/C77002         | In Stock  |
| 1        | SOT-23-6                                | ESD protection diode, used for headphone jack                 | $0.13             | $0.13                       | https://jlcpcb.com/partdetail/STMicroelectronics-USBLC62SC6/C7519                 | In Stock  |
| 2        | CONN_503480-0540_MOL                    | Molex connector used for linking button PCB with main PCB     | $0.83             | $1.66                       | https://jlcpcb.com/partdetail/MOLEX-5034800540/C5527934                           | In Stock  |
| 3        | LED_SK6805_PLCC4_2.4x2.7mm_P1.3mm       | LEDS on the Button PCB                                        | $3.95             | $11.86                      | https://www.adafruit.com/product/4492                                             | In Stock  |
| 1        | SW_Push_1P1T_NO_CK_KMR2                 | Button on the Button PCB                                      | $0.61             | $0.61                       | https://jlcpcb.com/partdetail/CK-KMR221GLFS/C72443                                | In Stock  |
| 1        | Vapcell N40                             | Battery                                                       | $20.00            | $20.00                      | https://www.vapcelltech.com/h-pd-193.html                                         | In Stock  |
| 1        | N/A                                     | Nickel Strips used for connecting the + and - of the battery  | $6.45             | $6.45                       | https://www.amazon.ca/Nickel-Plated-Connection-Refined-Welding/dp/B0CPFL5ZWM/     | In Stock  |
| 1        | N/A                                     | Pair of Pogo Pins                                             | $6.06             | $6.06                       | https://www.amazon.ca/Connector-Positions-Pogopin-Contact-3PIN/dp/B0BXDFJVVZ?th=1 | In Stock  |
| 1        | N/A                                     | uxcell 45mm x 0.5mm 6 Pin FPC/FFC Flat Ribbon Cable Connector | $9.99             | $9.99                       | https://www.amazon.ca/gp/product/B00H8PCW06                                       |           |
| 1        | N/A                                     | N/A                                                           | $53.85            | $53.85                      |                                                                                   |           |
| 1        | N/A                                     | N/A                                                           | $7.20             | $7.20                       |                                                                                   |           |

| Subtotal               | Source       | Notes                                                                                                                                                                    |
|------------------------|--------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| $228.21                | JLCPCB Parts | 2x (JLCPCB requires 2 of each part)                                                                                                                                      |
| $61.05                 | JLCPCB PCB   | 0.15mm via and epoxy filled & capped selectedas it is required by the ADAU1787 Chip. Lead free coating also selected for safety and its only a dollar extra. 6 Layer manufacturing is selected because it is cheaper than 2/4 layer manufacturing due to a coupon. Although other options were explored, most DSPs(Digital Singal Processors) which is required for fast processing of audio(required for ANC) are WLCSP chips requiring 0.15mm vias which are epoxy filled & capped. Other solutions are too slow for this application.|
| $22.50                 | Amazon       |                                                                                                                                                                          |
| $20.56                 | AliExpress   |                                                                                                                                                                          |
| $11.86                 | Adafruit     | For the LEDs                                                                                                                                                             |
| $250.08                | All          | Not accounting for 2x JLCPCB Parts                                                                                                                                       |
| $364.18                | All          | 2x (JLCPCB required 2 of each part)                                                                                                                                      |
|                        |              |                                                                                                                                                                          |
| JLCParts Grand Total   | $238.13      | 2x (JLCPCB required 2 of each part)                                                                                                                                      |
| JLCPCB Grand Total     | $72.25       | JLCPCB Advanced is cheaper due to coupons                                                                                                                                |
| Amazon Subtotal        | $16.28       | 22.5 CAD --> 16.28 USD                                                                                                                                                   |
| Adafruit Grand Total   | $23.08       |                                                                                                                                                                          |
| AliExpress Grand Total | $20.70       | 28.07 CAD --> 20.70 USD                                                                                                                                                  |
| Vapcell Grand Total    | $22.99       |                                                                                                                                                                          |
| Grand Total            | $393.43      |                                                                                                                                                                          |

### Screenshots of total with shipping and taxes.

Amazon:
<img width="507" height="285" alt="image" src="https://github.com/user-attachments/assets/e92a0cdc-b490-451f-ad90-d9e480f6f69a" />

(6 layer manufacturing for Main PCB, less expensive)
<img width="531" height="308" alt="image" src="https://github.com/user-attachments/assets/56fba184-d8d4-4598-8a8e-73e33f9c3967" />
<img width="574" height="334" alt="image" src="https://github.com/user-attachments/assets/d77fcd5b-af47-46c3-8fe0-f54b75862d19" />

(4 layer manufacturing for Main PCB, more expensive and thus not used)
<img width="504" height="299" alt="image" src="https://github.com/user-attachments/assets/ba898d97-9c16-49fc-bb57-6ad5d3582e26" />

Button PCB:
<img width="439" height="251" alt="image" src="https://github.com/user-attachments/assets/7d6217e9-ba68-4d48-9b11-a7d160179512" />

AliExpress:
<img width="614" height="282" alt="image" src="https://github.com/user-attachments/assets/8f56cc2b-43ba-402c-80a0-56d51fad0760" />

Vapcell:
<img width="463" height="278" alt="image" src="https://github.com/user-attachments/assets/8452e4ad-b364-4ce4-8cac-b01819ecd9fb" />

Adafruit:
<img width="486" height="179" alt="image" src="https://github.com/user-attachments/assets/f8738833-cfa1-4d91-b6a0-0330815d6da6" />



