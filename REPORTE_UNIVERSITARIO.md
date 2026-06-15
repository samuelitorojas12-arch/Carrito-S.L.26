# Guía de Desarrollo en Gowin EDA - Seguidor de Línea Competitivo (UV 2026)

Esta guía describe detalladamente los pasos para crear el proyecto, configurar el entorno, compilar, asignar pines y programar el **Controlador de Seguidor de Línea Competitivo** utilizando **Gowin EDA Educational v1.9.x** y la placa **Tang Nano 9K** (FPGA `GW1NR-LV9QN88PC6/I5`).

---

## 1. Crear el Proyecto y Configurar la FPGA

1.  Abra **Gowin EDA**.
2.  Haga clic en **File > New...** o presione `Ctrl + N`.
3.  Seleccione **FPGA Design Project** y presione **OK**.
4.  Configure el nombre del proyecto como `fpga_project_seguidor` y seleccione la ruta:
    `C:\Users\Rio Gil\.gemini\antigravity-ide\scratch\seguidor_linea_fpga`
5.  **Selección del Dispositivo (Crítico)**:
    *   **Series**: `GW1N`
    *   **Device**: `GW1NR-9C`
    *   **Device list**: Seleccione exactamente **`GW1NR-LV9QN88PC6/I5`** (encapsulado QFN88P).
    *   Haga clic en **Next** y luego en **Finish**.

---

## 2. Agregar Archivos al Proyecto

El diseño competitivo está modularizado para optimizar el rendimiento y la facilidad de mantenimiento. Debe agregar los siguientes archivos al proyecto:

1.  En el panel izquierdo **Design**, haga clic derecho en la carpeta **src** y elija **Add Files...**.
2.  Importe los 5 archivos fuente ubicados en la carpeta `src/` del proyecto:
    *   `src/seguidor_linea.v` (Módulo Top-Level integrador)
    *   `src/filtro_arranque.v` (Filtro antirrebote de LDR)
    *   `src/controlador_pwm.v` (Generador de velocidad PWM de 20 kHz)
    *   `src/seguidor_linea_core.v` (Núcleo lógico y memoria de recuperación)
    *   `src/seguidor_linea.cst` (Archivo de restricciones de pines)
    *   `src/seguidor_linea.sdc` (Archivo de restricciones de tiempos para el reloj de 27 MHz)
3.  Haga clic en **OK**. En la jerarquía de diseño, el módulo `seguidor_linea` debe aparecer en negrita como el módulo principal (Top Module).

---

## 3. Síntesis y Place & Route (P&R)

1.  En el panel izquierdo **Process**, expanda el flujo de diseño.
2.  Haga clic derecho en **Synthesize** y elija **Run** (o haga doble clic).
    *   *Resultado esperado*: Icono de check verde tras completarse con éxito.
3.  Haga clic derecho en **Place & Route** y elija **Run** (o haga doble clic).
    *   *Resultado esperado*: Icono de check verde tras completarse con éxito.
    *   *Nota*: La compilación generará el archivo de configuración binario con extensión `.fs` dentro del directorio `impl/pnr/fpga_project_seguidor.fs`.

---

## 4. Programar la FPGA (Tang Nano 9K)

1.  Conecte la placa **Tang Nano 9K** a la computadora por medio del puerto USB-C.
2.  En el panel **Process**, haga doble clic en **Programmer** (o **Program Device**).
3.  En Gowin Programmer, haga clic en el botón **Scan Device** (lupa con chip en la barra superior) para buscar la placa.
4.  Configure el archivo en la tabla:
    *   Haga doble clic en la celda vacía bajo la columna **FS File** (o bajo la columna **Operation**).
    *   En **Access Mode**, seleccione `SRAM Mode` (graba temporalmente en memoria volátil).
    *   En **File name**, presione el botón de los tres puntos `...`, busque el archivo `impl/pnr/fpga_project_seguidor` (que Windows identifica como *Archivo de origen F#* de tipo `.fs`) y presione **Save**.
5.  Haga clic en el icono de **Program/Configure (Play)** (el 7.º botón de la barra de herramientas, representado por una flecha verde tipo "Play" con un chip de fondo) para cargar el circuito en la FPGA.

---

## 5. Resolución de Errores Comunes de Compilación

### A. Conflicto de VCCIO en el Banco 3 (Error CT1136)
*   **Error típico**: `Bank 3 vccio(1.8) is locked by other constraint..., conflicting BANK_VCCIO set by 'M_IZQ_obuf' : IO_TYPE = LVCMOS33`
*   **Causa**: El Banco 3 de la placa Tang Nano 9K está conectado internamente de forma fija a 1.8V para alimentar la memoria PSRAM integrada. Intentar asignar un estándar de 3.3V (`LVCMOS33`) a pines de este banco causa un error crítico.
*   **Solución**: Los puertos asignados a los pines `4`, `10`, `11`, `13`, `14`, `15` y `16` deben tener obligatoriamente el estándar **`LVCMOS18`** en el archivo `.cst` (por ejemplo: `IO_PORT "M_IZQ" IO_TYPE=LVCMOS18;`).

### B. Advertencia de Reloj sin Declarar (Warning TA1132)
*   **Advertencia típica**: `'CLK' was determined to be a clock but was not created.`
*   **Causa**: Gowin EDA detecta que `CLK` actúa como reloj en la lógica Verilog, pero no se ha especificado su frecuencia de muestreo para el análisis de tiempos.
*   **Solución**: Importe al proyecto el archivo `seguidor_linea.sdc`. Este archivo define formalmente el reloj con el comando `create_clock -name CLK -period 37.037`, eliminando por completo las advertencias y logrando una compilación con **0 Warnings**.

### C. Conflicto de Pines Duales de Programación JTAG o MSPI
*   **Error**: Falla la compilación al intentar utilizar pines asignados por defecto al sistema de carga de la FPGA.
*   **Solución**: 
    1.  Vaya a **Project > Configuration > Place & Route > Dual Purpose Pin** en Gowin EDA.
    2.  Cambie las configuraciones de pines especiales (como MSPI o JTAG) a **Use as regular I/O** para liberar su uso.
