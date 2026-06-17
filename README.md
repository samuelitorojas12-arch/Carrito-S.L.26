# Controlador Digital de Seguidor de Línea Competitivo en FPGA Tang Nano 9K

Este repositorio contiene el desarrollo completo del proyecto realizado para la asignatura de Programación Avanzada, enfocado en el diseño e implementación de un sistema de control digital para un robot móvil seguidor de línea de alto rendimiento.

La arquitectura fue desarrollada íntegramente en hardware digital utilizando una FPGA Gowin GW1NR-LV9QN88PC6/I5 sobre la plataforma Tang Nano 9K, aprovechando las ventajas del procesamiento paralelo para ejecutar las tareas de control, monitoreo y toma de decisiones en tiempo real. Esta implementación permite alcanzar tiempos de respuesta del orden de los nanosegundos, proporcionando una alta precisión en el seguimiento de trayectoria, una rápida capacidad de reacción ante cambios en la pista y un desempeño óptimo durante operaciones a altas velocidades.

## Características Competitivas del Diseño

1. **Arranque Autónomo por Luz (LDR):** Cumple con la regla oficial del arranque autónomo. Cuenta con un módulo digital con filtro antirrebote de 10 ms e histéresis temporal que evita arranques falsos ante flashes u oscilaciones de luz ambiental. Una vez detectada la señal de salida, la bandera de carrera se enclava de forma permanente.

2. **Comunicación Inalámbrica por Bluetooth (HC-05):** Se incorporó soporte para un módulo Bluetooth HC-05 conectado mediante una interfaz UART implementada en la FPGA Tang Nano 9K. Esta funcionalidad permite la transmisión inalámbrica de información de diagnóstico, monitoreo de sensores y recepción de comandos externos para pruebas y futuras expansiones del sistema sin necesidad de conexión física por cable.

4. ### Modulación PWM Dual (20.7 kHz)

El sistema implementa una modulación por ancho de pulso (PWM) dual con una frecuencia de operación de **20.7 kHz**, permitiendo el control independiente y continuo de la velocidad de dos micromotores N20 mediante el controlador de puente H **TB6612FNG**. La resolución de **8 bits** proporciona un ajuste preciso de la potencia suministrada a cada motor, mejorando la respuesta dinámica y el control de movimiento. Además, al operar por encima del rango audible humano, se minimizan los ruidos generados por los bobinados de los motores, incrementando la eficiencia del sistema y optimizando la entrega de torque.


5. **Giro por Pivoteo Activo (Curvas Cerradas):** En curvas críticas, el sistema invierte físicamente el sentido de giro del motor interno (marcha atrás) y acelera el externo hacia adelante. Esto proporciona un torque diferencial máximo para virajes de emergencia sin pérdida de adherencia.

6. **Algoritmo de Recuperación Inteligente:** Al perder el contraste de la pista (`00000`), el robot recuerda su última dirección conocida y gira sobre su propio eje en ese sentido para reincorporarse. Si tras 2 segundos no recupera la línea, se detiene automáticamente por seguridad.

7. **Leds indicadores de estatus:** Un led rojo indica el estatus de reposo mientras que un led verde indica que el carrito se enciuentra en labor.

---

## Hardware Utilizado

* FPGA Tang Nano 9K (Gowin GW1NR-LV9QN88PC6/I5)
* Arreglo de 5 sensores infrarrojos para detección de línea
* Driver de motores TB6612FNG
* Dos motores N20 de corriente continua
* Sensor LDR para arranque autónomo
* Módulo Bluetooth HC-05 para comunicación inalámbrica UART
* Batería LiPo de 7.4 V
* Leds de colores indicadores de estado

---

## Comunicación Bluetooth

El sistema incorpora compatibilidad con el módulo Bluetooth HC-05 mediante una interfaz UART implementada en lógica digital dentro de la FPGA Tang Nano 9K.

Esta funcionalidad permite:

* Monitorear el estado del robot de forma remota.
* Transmitir información de diagnóstico durante las pruebas.
* Recibir comandos externos para validación y depuración.
* Facilitar futuras integraciones con aplicaciones móviles.
* Registrar información de sensores sin necesidad de conexión física directa.

La arquitectura fue diseñada para permitir futuras ampliaciones sin afectar el desempeño del controlador principal de seguimiento de línea, manteniendo la operación en tiempo real característica de la implementación sobre FPGA.


## Estructura del Repositorio

*   **`src/`**: Archivos de código fuente y restricciones.
    *   `seguidor_linea.v`: Módulo top-level integrador.
    *   `filtro_arranque.v`: Lógica de debouncing y enclavamiento del sensor LDR.
    *   `seguidor_linea_core.v`: Núcleo de control de velocidad, dirección y algoritmos.
    *   `controlador_pwm.v`: Generador PWM de 20.7 kHz para motores.
    *   `seguidor_linea.cst`: Restricciones de pines físicos (corregido a 1.8V para el Banco 3).
    *   `seguidor_linea.sdc`: Restricciones de frecuencia de reloj de 27 MHz (0 Warnings).
    *   `arranque_bt.v`: Módulo: arranque_bt (Decodificador de Comando Bluetooth).
    *   `uart_rx.v`: Receptor UART básico a 9600 baudios para leer los comandos enviados por el módulo Bluetooth HC-05.
*   **`tb/`**: Suite de simulación.
    *   `seguidor_linea_tb.v`: Banco de pruebas completo para verificar transiciones de sensores, arranque, PWM y recuperación en simuladores HDL.
*   **`doc/`**: Documentación de ingeniería.
    *   `GUIA_GOWIN_EDA.md`: Manual paso a paso para compilar, asignar pines y programar la FPGA.
    *   `REPORTE_UNIVERSITARIO.md`: Informe académico formal detallando el diseño, diagrama de cableado, plan de pruebas y conclusiones técnicas.
*   **`fpga_project_seguidor/impl/pnr/fpga_project_seguidor.fs`**: Archivo bitstream compilado final, listo para ser grabado directamente en la memoria Flash de la Tang Nano 9K utilizando Gowin Programmer.

---

##  Verificación de Requisitos (Comité Técnico)

Con el objetivo de garantizar la conformidad del prototipo con las especificaciones establecidas por el comité organizador de la competencia, se realizó una verificación de los principales requisitos técnicos y constructivos del sistema:

Línea de Seguimiento:
El vehículo fue diseñado para operar sobre una pista compuesta por una línea negra de 2 cm de ancho trazada sobre una superficie de color blanco, cumpliendo con las características definidas en el reglamento oficial.

Sistema de Sensado:
La detección de trayectoria se realiza mediante un arreglo frontal de cinco sensores infrarrojos reflectantes, distribuidos estratégicamente para proporcionar una cobertura amplia de la pista y permitir una respuesta rápida ante cambios de dirección.

Arranque Autónomo:
El sistema incorpora un mecanismo de arranque automático basado en una fotoresistencia LDR conectada a un comparador LM393. La señal digital resultante es procesada por la FPGA a través del Pin 33, donde se aplica un filtrado temporal para validar la señal de inicio y evitar activaciones erróneas ocasionadas por ruido o variaciones de iluminación ambiental.

Dimensiones del Prototipo:
El reglamento establece dimensiones máximas de 24 cm de largo y 20 cm de ancho. El vehículo desarrollado presenta unas dimensiones aproximadas de 18 cm × 14 cm, manteniéndose dentro de los límites permitidos y favoreciendo una mayor maniobrabilidad durante el recorrido.

Sistema de Alimentación:
La energía del sistema es suministrada por una batería LiPo de 2 celdas (7.4 V), integrada de forma segura dentro del chasis y con el aislamiento eléctrico necesario para garantizar un funcionamiento confiable de la electrónica de control y potencia.

Peso del Vehículo:
El peso final del prototipo se encuentra en proceso de validación y calibración. No obstante, el diseño ha sido optimizado para mantener una masa reducida, estimada en menos de 250 gramos, con el propósito de maximizar la aceleración, mejorar la respuesta dinámica y reducir las pérdidas por inercia durante las maniobras de giro.

En conjunto, estas características permiten concluir que el prototipo cumple satisfactoriamente con los requerimientos técnicos establecidos para la competencia, proporcionando una plataforma compacta, ligera y adecuada para la implementación de estrategias avanzadas de seguimiento de línea basadas en FPGA.

---

##  Instrucciones de Ejecución

Para grabar el controlador en tu hardware:
1. Abre **Gowin Programmer**.
2. Conecta la **Tang Nano 9K** mediante USB.
3. Carga el archivo precompilado ubicado en: `/fpga_project_seguidor/impl/pnr/fpga_project_seguidor.fs`.
4. Elige **Access Mode: Embedded Flash Mode** y presiona **Play**.






---
 - Facultad de Ingeniería UV, 2026.*
