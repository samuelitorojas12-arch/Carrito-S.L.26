# Reporte Técnico: Controlador Digital de Seguidor de Línea Competitivo con FPGA Tang Nano 9K
**Curso: Programacion Avanzada  / Diseño con FPGAs**  
**Departamento de Ingeniería Electrónica - Universidad Veracruzana**

---

## Resumen

El presente proyecto consiste en el diseño e implementación de un vehículo robótico seguidor de línea basado en una FPGA Tang Nano 9K, desarrollado para competir en la modalidad de carrera de alcance. El sistema fue diseñado para cumplir estrictamente con el reglamento de competencia, incorporando un mecanismo de arranque autónomo mediante un sensor LDR que detecta la señal luminosa de inicio y evita falsos arranques mediante técnicas de filtrado digital e histéresis temporal.

La arquitectura del controlador está compuesta por módulos independientes que realizan tareas de filtrado de arranque, comunicación Bluetooth, seguimiento de línea, control PWM e indicación visual de estados. Los sensores infrarrojos permiten detectar la posición de la línea en tiempo real, mientras que el núcleo de control implementa estrategias de corrección progresiva y giros por pivote dinámico para mejorar la maniobrabilidad en curvas cerradas y aumentar la velocidad de recuperación ante pérdidas de trayectoria.

Como complemento, se incorporó un módulo Bluetooth HC-05 conectado al pin 27 de la FPGA, permitiendo el control y monitoreo inalámbrico del sistema. Asimismo, se añadieron indicadores visuales mediante un LED rojo conectado al pin 25 y un LED verde conectado al pin 26, los cuales muestran de forma inmediata el estado operativo del vehículo.

El control de velocidad de los motores se realiza mediante señales PWM de alta frecuencia generadas directamente por hardware, proporcionando una respuesta rápida y eficiente. Gracias a la naturaleza paralela de la FPGA, el sistema alcanza tiempos de procesamiento extremadamente bajos, garantizando una reacción inmediata frente a cambios detectados por los sensores.

Las pruebas de simulación confirmaron el correcto funcionamiento del arranque seguro, la detección de línea, los giros de corrección, la recuperación automática de trayectoria y los mecanismos de protección ante pérdida prolongada de la pista. Como resultado, se obtuvo una plataforma robusta, escalable y competitiva, capaz de ofrecer un alto rendimiento en aplicaciones de robótica móvil y competencias de seguimiento de línea.


---

## 1. Introducción y Cumplimiento del Reglamento

El diseño de un vehículo robótico seguidor de línea de competencia (modalidad carrera de alcance) requiere maximizar la velocidad promedio en rectas y la estabilidad en curvas, garantizando a su vez el estricto cumplimiento de las normas oficiales establecidas en el reglamento:

1.  **Arranque Autónomo Obligatorio:** El reglamento prohíbe cualquier movimiento del carro antes del destello de la luz LED blanca de inicio. Para cumplir esto, el sistema integra un sensor óptico frontal (fotoresistencia LDR acoplada a un comparador LM393) que actúa como llave de encendido. La FPGA filtra y valida esta señal física en un módulo digital exclusivo para evitar descalificaciones por salidas en falso.
2.  **Dimensiones Máximas (24 cm de largo, 20 cm de ancho):** El chasis de tracción diferencial cuenta con unas dimensiones de $18\text{ cm} \times 14\text{ cm}$, lo que cumple cómodamente con la regla y optimiza el momento de inercia rotacional en curvas cerradas.
3.  **Algoritmo de Recuperación en Pista (Línea Perdida):** Ante salidas totales de la línea negra de 2 cm de ancho, el carro dispone de 10 segundos reglamentarios para reincorporarse de forma autónoma. El controlador de la FPGA memoriza la última corrección válida de los sensores infrarrojos e inicia una rotación de pivote (motores opuestos) en la misma dirección de escape para re-detectar la trayectoria. Si tras 2 segundos de búsqueda no se detecta la pista, el sistema se detiene automáticamente por seguridad.

---

## 2. Arquitectura Electrónica y Modular

Para reducir al mínimo la latencia del lazo de control y optimizar la mantenibilidad del software de descripción de hardware, el diseño se dividió en cuatro módulos principales interconectados de forma síncrona a un dominio de reloj de 27 MHz:

```
[Entradas]                                [Núcleo de Procesamiento FPGA]                               [Salidas]

  CLK (52)  ---------------------------> [  filtro_arranque  ]
                                               |
  LDR (33)  ---------------------------------->|
                                               v (start_flag)

  HC-05 Bluetooth (RX/TX) (27) ----------> [  control_comunicacion  ]
                                               |
                                               v (enable/estado)

  S1...S5 (28...32) ---------------------> [  seguidor_linea_core ] -------------------------> Dirección Motores
                                               |                                                 (34 y 35)
                                               v (duty_cycle)

                                          [  controlador_pwm   ] ---------------------------> Velocidad Motores (PWM)
                                                                                               (10 y 11)

                                          [  indicador_estado  ] ---------------------------> LED Rojo (25)
                                                                                               LED Verde (26)
```

### A. Filtro del Sensor de Arranque LDR (`filtro_arranque.v`)

La señal entregada por el comparador LM393 asociado a la fotoresistencia LDR puede presentar oscilaciones y transitorios provocados por la iluminación ambiental, reflejos o flashes presentes en la pista. Para garantizar un arranque seguro, el módulo implementa un contador digital de histéresis temporal, exigiendo que la entrada LDR_IN permanezca en nivel alto de manera continua durante al menos 10 ms (270,000 ciclos a 27 MHz) antes de activar la bandera start_flag.

Una vez validado el arranque, la señal queda enclavada permanentemente en ‘1’ hasta que ocurra un reinicio físico de la FPGA, evitando que sombras, vibraciones o cambios de iluminación durante la carrera provoquen desactivaciones accidentales.

### B. Controlador PWM de Frecuencia Portadora (`controlador_pwm.v`)
El control continuo de velocidad de los micromotores N20 se realiza mediante Modulación por Ancho de Pulso (PWM). El módulo implementa dos generadores de rampa de 8 bits (resolución de 0 a 255). A partir de la frecuencia de reloj del sistema, se introduce un prescaler divisor entre 5 que disminuye la base de tiempos a un periodo de rampa de $48.3\ \mu\text{s}$, lo que equivale a una frecuencia portadora de **20.7 kHz**. Esta frecuencia ultrasónica es ideal para pequeños servomotores y motores DC metálicos: elimina por completo el molesto silbido mecánico audible en los bobinados y reduce de forma significativa las corrientes de rizado y disipación térmica en el chip driver (TB6612FNG).

### C. Núcleo de Control y Recuperación (arranque_bt.v)

Este módulo constituye el núcleo de control encargado de gestionar la secuencia de arranque del sistema a través de comunicación Bluetooth. Supervisa continuamente los datos validados por el receptor UART y analiza la información recibida. Cuando detecta el carácter ASCII **'1'** (código hexadecimal **0x31**), activa la señal **start_flag_bt**, la cual indica que se ha recibido una orden válida de inicio. Una vez activada, esta bandera permanece enclavada para garantizar la conservación del estado de arranque, evitando pérdidas de la señal por interrupciones o variaciones temporales. La señal solo puede restablecerse mediante un reinicio (**reset**) del sistema, asegurando un funcionamiento estable y confiable.



### D. Núcleo de Control y Recuperación (`seguidor_linea_core.v`)
El núcleo implementa la máquina de control de velocidad y sentido de giro, traduciendo los estados de los sensores infrarrojos reflectantes ($S_1$ a $S_5$) en salidas de potencia de acuerdo con la tabla de verdad y la estrategia de control competitiva:
*   **Marcha Recta (`00100`):** Máxima potencia hacia ambos motores (`VEL_MAX = 225`) en sentido directo para recortar distancias en tramos lineales.
*   **Curvas Suaves (`01100` y `00110`):** Se desacelera levemente el motor interno a la curva (`VEL_MED = 150`) mientras el exterior se mantiene a potencia máxima para realizar correcciones sin detener el carro.
*   **Curvas Cerradas (`01000` y `00010`):** El motor interno se frena a velocidad mínima (`VEL_MIN = 70`) para inducir un radio de giro cerrado.
*   **Curvas Críticas / Pivote (`10000` y `00001`):** Para giros de emergencia, el motor interno se invierte físicamente en sentido de retroceso (`VEL_REV = 130`, `dir = 1`) y el exterior se mantiene en avance directo, forzando un giro rápido sobre su propio eje (torque diferencial puro).
*   **Línea Perdida (`00000`):** Se activa un temporizador de seguridad de $54,000,000$ de ciclos (2 segundos). Mientras corre el tiempo, el núcleo consulta el registro `last_direction` y ordena un giro de pivote en el sentido donde vio por última vez la línea para recuperarla de forma inmediata.

---

## 3. Mapa de Pines del Sistema
La siguiente tabla consolida el mapeo físico de los puertos del controlador a la FPGA Tang Nano 9K, utilizando los estándares eléctricos e impedancias requeridos en el archivo `.cst` de restricciones:

| Puerto | Dirección | Pin FPGA | Estándar E/S | Configuración / Pull-mode | Función Física |
|:---|:---:|:---:|:---:|:---:|:---|
| **CLK** | Entrada | 52 | LVCMOS33 | Pull-up Interno | Reloj de Sistema (Oscilador 27 MHz) |
| **RST** | Entrada | 4 | LVCMOS18 | Pull-up Interno | Botón USR_KEY (Reset Activo en Bajo) |
| **LDR_IN** | Entrada | 33 | LVCMOS33 | Ninguno (Floating) | Sensor óptico de arranque autónomo |
| **S1** | Entrada | 28 | LVCMOS33 | Ninguno (Floating) | Sensor Infrarrojo Extremo Izquierdo |
| **S2** | Entrada | 29 | LVCMOS33 | Ninguno (Floating) | Sensor Infrarrojo Izquierdo Central |
| **S3** | Entrada | 30 | LVCMOS33 | Ninguno (Floating) | Sensor Infrarrojo Central |
| **S4** | Entrada | 31 | LVCMOS33 | Ninguno (Floating) | Sensor Infrarrojo Derecho Central |
| **S5** | Entrada | 32 | LVCMOS33 | Ninguno (Floating) | Sensor Infrarrojo Extremo Derecho |
| **M_IZQ** | Salida | 10 | LVCMOS18 | DRIVE = 8mA | Velocidad Motor Izq. (PWM, LED0 Integrado) |
| **M_DER** | Salida | 11 | LVCMOS18 | DRIVE = 8mA | Velocidad Motor Der. (PWM, LED1 Integrado) |
| **M_IZQ_DIR**| Salida | 34 | LVCMOS33 | DRIVE = 8mA | Sentido Motor Izq. (0: FWD, 1: REV) |
| **M_DER_DIR**| Salida | 35 | LVCMOS33 | DRIVE = 8mA | Sentido Motor Der. (0: FWD, 1: REV) |
| **LED_REC** | Salida | 13 | LVCMOS18 | DRIVE = 8mA | LED Indicador Recto (LED2 Integrado) |
| **LED_IZQ** | Salida | 14 | LVCMOS18 | DRIVE = 8mA | LED Indicador Giro Izq. (LED3 Integrado) |
| **LED_DER** | Salida | 15 | LVCMOS18 | DRIVE = 8mA | LED Indicador Giro Der. (LED4 Integrado) |
| **LED_STOP**| Salida | 16 | LVCMOS18 | DRIVE = 8mA | LED Indicador Parada (LED5 Integrado) |
| **MOD_BLU**| Salida | 27 | LVCMOS33 | Ninguno (Floating) | Modulo Bluetooth (LED5 Integrado) |
| **LED_RED**| Salida | 25 | LVCMOS33 | Ninguno (Floating)| LED Indicador Parada (LED Fisico) |
| **LED_GREEN**| Salida | 26 | LVCMOS33 | Ninguno (Floating) | LED Indicador Movimiento (LED Fisico) |

*Nota sobre voltajes de banco:* Todos los pines pertenecientes al Banco 3 (pines 4, 10, 11, 13, 14, 15 y 16) están configurados con el estándar `LVCMOS18` debido a la restricción física de hardware de la Tang Nano 9K (VCCIO hardwired a 1.8V para la PSRAM), evitando fallas durante la fase de Place & Route.

---

## 4. Plan de Pruebas y Resultados de Simulación
La verificación funcional del controlador se realizó por medio de simulación RTL utilizando el testbench `seguidor_linea_tb.v`. Los parámetros de tiempo se acortaron proporcionalmente mediante directivas `defparam` en el simulador para realizar un barrido rápido de las pruebas:

1.  **Arranque Bloqueado (0 a 100 ns):** Se simula el encendido con sensores activos (`S3=1`) pero LDR en bajo (`LDR_IN=0`). Se confirma que las velocidades de los motores permanecen en cero y que `LED_STOP` se mantiene encendido, demostrando la obediencia al semáforo de salida.
2.  **Rechazo de Transitorio (100 ns a 300 ns):** Se aplica un pulso corto de luz en el LDR. El sistema lo ignora al no cumplir la histéresis temporal.
3.  **Disparo por Luz Estable (300 ns a 500 ns):** Se enciende `LDR_IN` de forma continua. La bandera `start_flag` cambia a `1` y habilita de forma permanente las salidas del puente H.
4.  **Verificación de Modulación PWM y Marcha Recta:** Con la entrada `00100`, los motores giran en sentido de avance (`M_IZQ_DIR=0`, `M_DER_DIR=0`) con una modulación del ciclo de trabajo en alto de la señal PWM correspondiente a `VEL_MAX`.
5.  **Prueba de Giro de Pivote (Giro Fuerte):** Con la entrada `00001` (desvío extremo derecho), el motor izquierdo se mantiene en avance directo, mientras el motor derecho invierte su sentido de rotación (`M_DER_DIR=1`) a velocidad controlada (`VEL_REV`), validando la torsión diferencial de pivote.
6.  **Memoria ante Pérdida y Detención Segura (Línea Perdida):** Al pasar abruptamente de giro derecho a la lectura `00000`, la FPGA mantiene el pivote derecho por inercia para recapturar la línea. Si la condición persiste durante el intervalo del timer, los motores pasan a `0` y la bandera `stop_timeout` detiene el carro, cumpliendo el límite seguro del reglamento.

---

## 5.**Conclusiones del Diseño**

1. **Garantía de Cero Falsos Arranques:**
   El módulo de histéresis digital implementado para el sensor LDR proporciona una elevada inmunidad frente a variaciones de iluminación ambiental, reflejos y ruido óptico presentes en el entorno de competencia. Gracias a esta estrategia, el vehículo inicia su operación únicamente cuando detecta la señal luminosa del semáforo de salida, evitando activaciones accidentales y mejorando la confiabilidad general del sistema.

2. **Maniobrabilidad con Pivote Dinámico:**
   La estrategia de control basada en inversión física de motores durante curvas pronunciadas y condiciones de pérdida de línea permite realizar giros sobre su propio eje. Esta técnica reduce significativamente el derrape causado por la inercia, mejora la capacidad de corrección de trayectoria y aumenta la velocidad de recuperación frente a errores de seguimiento.

3. **Integración de Comunicación Inalámbrica:**
   La incorporación del módulo Bluetooth HC-05 conectado al pin 27 de la FPGA permite la comunicación inalámbrica con dispositivos externos para tareas de monitoreo, configuración y control. Esta funcionalidad incrementa la flexibilidad del sistema y facilita las pruebas, el diagnóstico y futuras ampliaciones del proyecto sin necesidad de conexiones físicas adicionales.

4. **Sistema de Indicadores Visuales de Estado:**
   Se implementó un sistema de señalización mediante dos LEDs de estado: un LED rojo conectado al pin 25 y un LED verde conectado al pin 26. Estos indicadores permiten conocer de forma inmediata la condición operativa del vehículo. El LED rojo señala estados de espera, detención o error, mientras que el LED verde indica funcionamiento correcto, conexión activa y operación normal del sistema.

5. **Eficiencia y Confiabilidad Eléctrica:**
   La configuración de los puertos de salida bajo el estándar LVCMOS18 garantiza la compatibilidad eléctrica con el hardware de la FPGA Tang Nano 9K, respetando las limitaciones de voltaje de sus bancos de E/S. Esto evita problemas de sobrecorriente, sobrecalentamiento y degradación de los componentes, obteniendo además un proceso de síntesis, Place & Route y generación de bitstream libre de errores y advertencias.

6. **Baja Latencia de Procesamiento:**
   Al ejecutarse completamente en hardware digital paralelo dentro de la FPGA, el sistema procesa simultáneamente las señales de los sensores, los algoritmos de seguimiento de línea y la generación de PWM para los motores. Esto permite alcanzar tiempos de respuesta inferiores a 40 ns entre la detección de un evento y la acción correctiva correspondiente, superando ampliamente el rendimiento de soluciones basadas en microcontroladores tradicionales.

7. **Arquitectura Escalable y Competitiva:**
   La estructura modular del diseño facilita la incorporación de nuevas funcionalidades, sensores y estrategias de control sin modificar significativamente la arquitectura principal. La combinación de procesamiento paralelo, control preciso de motores, comunicación inalámbrica y monitoreo visual proporciona una plataforma robusta, eficiente y adecuada para aplicaciones de robótica móvil y competencias de seguimiento de línea de alto rendimiento.

