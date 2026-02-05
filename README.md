# SERENE

Can't hear your friend talking on the highway? Do you need to blast your music just to hear it well? Well, you're in luck, because **Serene** is a portable noise-cancelling device that can remove all of that noise!

Just stick it to the roof of your car, and Serene will capture the road noise and output sounds waves that cancel them out, so that you can enjoy a peaceful car ride. 

Serene is a small, portable device that connects directly to your phone and car speaker. It sticks seamlessly to the walls of your car, and using ANC algorithms, it minimizes the external noise that it picks up inside the car.  

---

## Inspiration 

During family road trips, I sat in the backseat as a child, and if I didn't yell, my parents in the front couldn't hear me. This was so annoying, as a long highway drive almost always came with losing my voice. 

With my dad's hearing getting worse, I figured that we needed a way to drown out the road noise. I was desparate for a solution, so taking inspiration from noise-cancelling technology in headphones, I thought: "What if we did the same thing in cars?". 

Asking around to gather interest for this project, my chemistry teacher also said that she wishes her 1 and a half hour commute in the morning was quieter. So, with another client that could benefit, we began developing Serene. 

While a few very luxury cars offer ANC, we wanted to make ANC more accessible to all people, because everyone deserves sereneness!

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

<img width="655" height="434" alt="image" src="https://github.com/user-attachments/assets/7ac86c27-29ce-4630-ba3a-70ae58f0bd60" />
<img width="722" height="445" alt="image" src="https://github.com/user-attachments/assets/e35c6efb-e188-4985-9bd6-9fb9750783b0" />


### Casing:

<img width="589" height="428" alt="image" src="https://github.com/user-attachments/assets/a1ef4850-2492-4c4f-aa21-fb156484d491" />
<img width="729" height="626" alt="image" src="https://github.com/user-attachments/assets/13c21e6f-37f3-41f0-8109-21be4e4fdf20" />

---

## PCB
<img width="500" height="890" alt="image" src="https://github.com/user-attachments/assets/b163734b-e3cd-4c76-bce3-792532eaf435" />

---

## Wiring Diagram
<img width="1318" height="931" alt="image" src="https://github.com/user-attachments/assets/f642dc4a-51fe-4a3d-9341-d7e705c53a9a" />

---

## BOM
[JLCPCB_BOM_Template (3).csv](https://github.com/user-attachments/files/25109044/JLCPCB_BOM_Template.3.csv)
Quantity,Reference,Footprint Name,Part Name,Compoenent,Manufcaturer Part #,Price(1 Quantity),Total Price for all quantiy,Source,Link,Status
1,U6,BQ25620RYKR,WQFN-HR18__RYK_TEX,Power Chip,BQ25620RYKR,$2.48,$2.48,JLCPCB,https://jlcpcb.com/partdetail/TexasInstruments-BQ25620RYKR/C6164243,In Stock
2,"J1,J6",Conn_Coaxial,CONN_X.FL-R-SMT-180_HIR,Coaxial Connector for bluetooth and UWB antennas,X.FL-R-SMT-1(80),$0.27,$0.53,JLCPCB,https://jlcpcb.com/partdetail/HRS_Hirose-X_FL_R_SMT_1_80/C434819,In Stock
17,"C10,C18,C31,C17,C20,C8,C11,C4,C28,C13,C27,C14,C9,C15,C12,C19,C16",0.1uF,C_0402_1005Metric,"Capacitor, 0.1uF",GRM155R71C104KA88D,$0.00,$0.03,JLCPCB,https://jlcpcb.com/partdetail/MurataElectronics-GRM155R71C104KA88D/C71629,In Stock
1,C37,47nF,C_0402_1005Metric,"Capacitor, 47nF",GRM155R71E473KA88D,$0.00,$0.00,JLCPCB,https://jlcpcb.com/partdetail/MurataElectronics-GRM155R71E473KA88D/C77017,In Stock
1,U9,~,Spark_SR1120_QFN32,"UWB Chip, used for audio transmission",SR1120AA-4Q32-TR,$16.54,$16.54,JLCPCB,https://jlcpcb.com/partdetail/SPARKMicrosystems-SR1120AA_4Q32TR/C47090725,Pre-Order
1,U2,AP2112K-1.8,SOT-23-5,1.8V Power Regulator,AP2112K-1.8TRG1,$0.11,$0.11,JLCPCB,https://jlcpcb.com/partdetail/DiodesIncorporated-AP2112K_18TRG1/C176944,In Stock
2,"MK2,MK1",IM73A135V01,Infineon_PG-LLGA-5-2,Mics,IM73A135V01XTSA1,$10.28,$20.56,AliExpress,https://www.aliexpress.com/i/1005008454918413.html,In Stock
1,J5,USB_C_Receptacle_USB2.0_14P,USB_C_Receptacle_GCT_USB4085,USB C Port (USB 2.0),USB4085-GF-A,$1.19,$1.19,JLCPCB,https://jlcpcb.com/partdetail/8061907-USB4085_GFA/C7095263,In Stock
1,J4,AudioJack3_Switch,Jack_3.5mm_CUI_SJ2-3593D-SMT_Horizontal,Headphone Jack,SJ2-3593D-SMT-TR,$11.30,$11.30,JLCPCB,https://jlcpcb.com/partdetail/CUI-SJ2_3593D_SMTTR/C4991621,In Stock
4,"R12,R16,R10,R9",100kΩ,R_0402_1005Metric,"Resistor, 100kΩ",RC0402FR-07100KL,$0.01,$0.04,JLCPCB,https://jlcpcb.com/partdetail/YAGEO-RC0402FR07100KL/C60491,In Stock
1,U3,STM32H753ZITx,STM32H743ZIT6,"Microcontroller, STM32H743ZIT6",STM32H743ZIT6,$8.19,$8.19,JLCPCB,https://jlcpcb.com/partdetail/STMicroelectronics-STM32H743ZIT6/C114408,In Stock
7,"C1,C40,C39,C7,C2,C36,C38",10uF,C_0402_1005Metric,"Capacitor, 10uF",Murata GRM155R60J106ME44D,$0.01,$0.07,JLCPCB,https://jlcpcb.com/partdetail/MurataElectronics-GRM155R60J106ME44D/C76991,In Stock
1,C35,4.7µF,C_0402_1005Metric,"Capacitor, 4.7µF",Murata GRM155R61A475MEAAD,$0.01,$0.01,JLCPCB,https://jlcpcb.com/partdetail/313626-GRM155R61A475MEAAD/C335105,In Stock
1,U4,ADXL382-1BCCZ-RL,ADXL382_Ultralib,"Vibration Sensor, used for predicting sound",ADXL382-1BCCZ-RL7,$28.05,$28.05,JLCPCB,https://jlcpcb.com/partdetail/AnalogDevices-ADXL382_1BCCZRL7/C41718413,In Stock
1,L1,180nH,L_0603_1608Metric,"Inductor, 180nH",Murata LQW18ANR18G80D,$0.09,$0.09,JLCPCB,https://jlcpcb.com/partdetail/MurataElectronics-LQW18ANR18G80D/C162650,In Stock
1,Y2,32.768 kHz,Crystal_SMD_3225-4Pin_3.2x2.5mm,"Crystal, 32.768 kHz",ABS07-32.768KHZ-T,$0.49,$0.49,JLCPCB,https://jlcpcb.com/partdetail/AbraconLLC-ABS07_32_768KHZT/C130253,In Stock
5,"C32,C23,C29,C30,C26",1uF,C_0402_1005Metric,"Capacitor, 1uF",GRM155R61A105KE15D,$0.01,$0.05,JLCPCB,https://jlcpcb.com/partdetail/MurataElectronics-GRM155R61A105KE15D/C76999,In Stock
6,"C33,C25,C34,C3,C6,C24",10pF,C_0402_1005Metric,"Capacitor, 10pF",GRM1555C1H100JA01D,$0.01,$0.06,JLCPCB,https://jlcpcb.com/partdetail/MurataElectronics-GRM1555C1H100JA01D/C76946,In Stock
1,U5,ADAU1787BCBZRL,ADAU1787_Ultralib,DSP(Digital Signal Processor) used for processing sound,ADAU1787BCBZRL,$19.07,$19.07,JLCPCB,https://jlcpcb.com/partdetail/AnalogDevices-ADAU1787BCBZRL7/C3226201,In Stock
1,U1,AP7361C-33E,SOT-223-3_TabPin2,3.3V Power Regulator,AP7361C-33E-13,$0.29,$0.29,JLCPCB,https://jlcpcb.com/partdetail/DiodesIncorporated-AP7361C_33E13/C500795,In Stock
2,"R2,R1",5.1k,R_0402_1005Metric,"Resistor, 5.1k",RC0402FR-075K1L,$0.01,$0.02,JLCPCB,https://jlcpcb.com/partdetail/YAGEO-RC0402FR075K1L/C105872,In Stock
1,L2,1.5uH,L_0603_1608Metric,"Inductor, 1.5uH",Murata DFE252012F-1R5M=P2,$0.10,$0.10,JLCPCB,https://jlcpcb.com/partdetail/MurataElectronics-DFE252012F_1R5MP2/C909806,In Stock
1,U7,BGM220SC12WGA2R,BGM220S_SIL,Bluetooth Chip,BGM220SC12WGA2R,$13.84,$13.84,JLCPCB,https://jlcpcb.com/partdetail/1603489-BGM220SC12WGA2R/C1512693,Pre-Order
1,Y1,Crystal_GND24,Crystal_SMD_3225-4Pin_3.2x2.5mm,Crystal,X322525MQB4SI,$0.08,$0.08,JLCPCB,https://jlcpcb.com/partdetail/YXC_CrystalOscillators-X322525MQB4SI/C70585,In Stock
1,T1,Transformer_1P_1S,Balun_Johanson_1.6x0.8mm,Transformer,Johanson 6750BL14A0100001T,$8.97,$8.97,JLCPCB,https://jlcpcb.com/partdetail/YXC_CrystalOscillators-X322525MQB4SI/C70585,In Stock
2,"R4,R5",2.2kΩ,R_0402_1005Metric,"Resistor, 2.2kΩ",RC0402FR-072K2L,$0.01,$0.02,JLCPCB,https://jlcpcb.com/partdetail/YAGEO-RC0402FR072K2L/C114762,In Stock
1,R6,170Ω,R_0402_1005Metric,"Resistor, 170Ω",RC0402FR-07170RL,$0.01,$0.01,JLCPCB,https://jlcpcb.com/partdetail/YAGEO-RC0402FR07180RL/C138045,In Stock
5,"R8,R15,R11,R7, R3",10kΩ,R_0402_1005Metric,"Resistor, 10kΩ",RC0402FR-0710KL,$0.01,$0.05,JLCPCB,https://jlcpcb.com/partdetail/YAGEO-RC0402FR0710KL/C60490,In Stock
2,"C21,C22",2.2uF,C_0402_1005Metric,"Capacitor, 2.2uF",GRM155R61A225KE95D,$0.01,$0.02,JLCPCB,https://jlcpcb.com/partdetail/MurataElectronics-GRM155R61A225KE95D/C77002,In Stock
1,U8,USBLC6-2SC6,SOT-23-6,"ESD protection diode, used for headphone jack",USBLC6-2SC6,$0.13,$0.13,JLCPCB,https://jlcpcb.com/partdetail/STMicroelectronics-USBLC62SC6/C7519,In Stock
2,J2,Conn_01x06_Socket,CONN_503480-0540_MOL,Molex connector used for linking button PCB with main PCB,5034800540,$0.83,$1.66,JLCPCB,https://jlcpcb.com/partdetail/MOLEX-5034800540/C5527934,In Stock
3,"D18,D9,D2,D7,D16,D12,D5,D13,D20,D15,D21,D8,D14,D1,D3,D11,D4,D10,D6,D17,D19",SK6805,LED_SK6805_PLCC4_2.4x2.7mm_P1.3mm,LEDS on the Button PCB,SK6805-E-J,$3.95,$11.86,Adafruit (cheaper than digikey),https://www.adafruit.com/product/4492,In Stock
1,SW1,SW_Push,SW_Push_1P1T_NO_CK_KMR2,Button on the Button PCB,KMR221GLFS,$0.61,$0.61,JLCPCB,https://jlcpcb.com/partdetail/CK-KMR221GLFS/C72443,In Stock
1,Battery,N/A,Vapcell N40 ,Battery,Vapcell N40 ,$20.00,$20.00,VAPCELL,https://www.vapcelltech.com/h-pd-193.html,In Stock
1,Nickel Strips,N/A,N/A,Nickel Strips used for connecting the + and - of the battery,N/A,$6.45,$6.45,Amazon,https://www.amazon.ca/Nickel-Plated-Connection-Refined-Welding/dp/B0CPFL5ZWM/,In Stock
1,Pogo Pins,N/A,N/A,Pair of Pogo Pins,N/A,$6.06,$6.06,Amazon,https://www.amazon.ca/Connector-Positions-Pogopin-Contact-3PIN/dp/B0BXDFJVVZ?th=1,In Stock
1,FPC/FFC Flat Ribbon Cable,N/A,N/A,uxcell 45mm x 0.5mm 6 Pin FPC/FFC Flat Ribbon Cable Connector,N/A,$9.99,$9.99,Amazon,https://www.amazon.ca/gp/product/B00H8PCW06,
1,Main PCB,N/A,N/A,N/A,N/A,$53.85,$53.85,JLCPCB PCB,,
1,Button PCB,N/A,N/A,N/A,N/A,$7.20,$7.20,JLCPCB PCB,,
