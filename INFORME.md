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

El desarrollo de un vehículo robótico seguidor de línea para competencias de velocidad y alcance representa un desafío que combina diseño electrónico, control digital y optimización mecánica. El objetivo principal consiste en maximizar la velocidad de desplazamiento en tramos rectos y mantener una elevada estabilidad durante la toma de curvas, sin comprometer la precisión del seguimiento de la trayectoria. Asimismo, el diseño debe cumplir rigurosamente con las especificaciones establecidas en el reglamento oficial de la competencia.

Para garantizar dicho cumplimiento, se consideraron los siguientes aspectos fundamentales:

1. Arranque Autónomo Obligatorio

De acuerdo con el reglamento, el vehículo no debe iniciar ningún movimiento antes de la señal oficial de salida emitida mediante un destello de luz LED blanca. Para satisfacer este requisito, se implementó un sistema de detección óptica basado en una fotoresistencia (LDR) acoplada a un comparador LM393, encargado de convertir la variación luminosa en una señal digital interpretable por la FPGA.

Con el fin de evitar activaciones accidentales provocadas por interferencias lumínicas o variaciones del entorno, la señal es procesada por un módulo digital de filtrado y validación que verifica su estabilidad antes de habilitar el arranque. Esta estrategia garantiza un inicio confiable y evita posibles descalificaciones derivadas de falsas detecciones.

2. Cumplimiento de las Restricciones Dimensionales

El reglamento establece dimensiones máximas de 24 cm de largo y 20 cm de ancho para los vehículos participantes. El prototipo desarrollado emplea un sistema de tracción diferencial montado sobre un chasis compacto de aproximadamente 18 cm × 14 cm, manteniéndose ampliamente dentro de los límites permitidos.

Además de cumplir con la normativa, estas dimensiones contribuyen a mejorar la maniobrabilidad del vehículo, reduciendo el momento de inercia durante los cambios de dirección y favoreciendo una respuesta más rápida en curvas cerradas.

3. Recuperación Autónoma ante Pérdida de Línea

Durante el recorrido, pueden presentarse situaciones en las que los sensores infrarrojos pierdan completamente la referencia de la línea de seguimiento. Para estos casos, el reglamento permite un tiempo determinado para que el vehículo recupere la trayectoria de forma autónoma.

Con el propósito de incrementar la probabilidad de recuperación, el controlador implementado en la FPGA almacena la última dirección válida detectada por el sistema de sensores. Cuando ocurre una pérdida total de la línea, el algoritmo activa una maniobra de búsqueda basada en un giro de pivote orientado hacia la última dirección registrada, permitiendo localizar nuevamente la trayectoria de manera rápida y eficiente.

Adicionalmente, se incorporó un mecanismo de seguridad que supervisa el tiempo de búsqueda. Si la línea no es recuperada después de dos segundos de operación continua, el sistema detiene automáticamente los motores para evitar desplazamientos indeseados y preservar la integridad del vehículo y del entorno de prueba.

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

### C. Módulo de Comunicación Bluetooth (control_comunicacion.v)

Este módulo es responsable de gestionar la comunicación inalámbrica entre el sistema y dispositivos externos mediante el módulo Bluetooth HC-05, conectado a la FPGA a través de una interfaz UART. Su función principal consiste en supervisar continuamente los datos recibidos, validar los comandos entrantes y garantizar una comunicación confiable durante la operación del vehículo.

Cuando el receptor detecta el carácter ASCII '1' (0x31), interpretado como una orden válida de inicio, el módulo activa la señal start_flag_bt, habilitando el funcionamiento del robot seguidor de línea. Para incrementar la robustez del sistema frente a posibles interrupciones, pérdidas temporales de enlace o errores de transmisión, esta bandera permanece enclavada una vez activada, conservando el estado de arranque incluso si la comunicación Bluetooth se interrumpe momentáneamente.

La señal únicamente puede restablecerse mediante un reinicio del sistema, garantizando un comportamiento estable, predecible y seguro durante las pruebas y la competencia.

La integración Bluetooth permite realizar pruebas, monitoreo y control inalámbrico, facilitando el diagnóstico y futuras expansiones del proyecto.


### D. Núcleo de Control y Recuperación (`seguidor_linea_core.v`)
El módulo seguidor_linea_core.v constituye el núcleo principal del sistema de navegación, siendo el encargado de interpretar las lecturas provenientes de los cinco sensores infrarrojos reflectantes (S1–S5) y convertirlas en acciones de control para los motores. A partir de una lógica de decisión basada en una tabla de estados, el controlador determina la velocidad y el sentido de giro más adecuados para mantener al vehículo sobre la trayectoria con la mayor precisión y estabilidad posibles.

La estrategia de control implementada contempla distintos escenarios de operación:

Marcha Recta (00100)
Cuando el sensor central detecta la línea, el sistema interpreta que el vehículo se encuentra correctamente alineado con la trayectoria. En esta condición, ambos motores operan en sentido de avance a velocidad máxima (VEL_MAX = 225), permitiendo alcanzar la mayor velocidad posible en tramos rectos y optimizando el tiempo de recorrido.
Curvas Suaves (01100 y 00110)
Ante una ligera desviación de la línea respecto al centro, el controlador reduce moderadamente la velocidad del motor ubicado en el interior de la curva (VEL_MED = 150), mientras mantiene el motor exterior a velocidad máxima. Esta acción genera una corrección progresiva de la trayectoria sin comprometer significativamente la velocidad del vehículo.
Curvas Cerradas (01000 y 00010)
Cuando la línea se desplaza hacia sensores más alejados del centro, se interpreta una curva de mayor intensidad. En consecuencia, el motor interno reduce su velocidad hasta un valor mínimo (VEL_MIN = 70), incrementando la diferencia de velocidades entre ambos motores y permitiendo realizar giros más pronunciados con estabilidad.
Curvas Críticas o Giro de Pivote (10000 y 00001)
En situaciones donde la línea es detectada únicamente por los sensores extremos, el sistema ejecuta una maniobra de recuperación agresiva. Para ello, el motor interno invierte su sentido de giro (VEL_REV = 130, dir = 1), mientras el motor externo continúa avanzando. Esta configuración genera un movimiento de pivote sobre el propio eje del vehículo, permitiendo corregir rápidamente desviaciones severas y recuperar la trayectoria.
Pérdida Total de Línea (00000)
Si ninguno de los sensores detecta la línea, el controlador activa un modo de búsqueda automática. Durante este proceso, se consulta el registro last_direction, que almacena la última dirección válida detectada, y se ejecuta una maniobra de pivote orientada hacia dicha dirección con el objetivo de localizar nuevamente la pista. Paralelamente, se inicia un temporizador de seguridad de 54,000,000 ciclos de reloj (aproximadamente 2 segundos). Si la línea no es recuperada dentro de este intervalo, el sistema detiene automáticamente ambos motores para evitar desplazamientos erráticos y garantizar una operación segura.

Gracias a esta estrategia de control jerárquica, el vehículo es capaz de adaptarse dinámicamente a diferentes condiciones de la pista, manteniendo un equilibrio entre velocidad, precisión y capacidad de recuperación ante situaciones críticas.
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

