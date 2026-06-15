// ============================================================================
// Proyecto: Controlador Digital de Seguidor de Línea Competitivo (UV 2026)
// Target FPGA: Gowin GW1NR-LV9QN88PC6/I5 (Tang Nano 9K)
// Módulo Top-Level: seguidor_linea (Reemplaza la versión básica)
//
// Descripción:
// Módulo integrador principal del seguidor de línea competitivo.
// Interconecta el filtro de luz LDR, el procesador de control y el generador PWM.
// ============================================================================

module seguidor_linea (
    input  wire CLK,         // Reloj del sistema (Pin 52 - 27MHz/50MHz)
    input  wire RST,         // Reset activo en bajo (Pin 4 - USR_KEY)
    input  wire S1,          // Sensor extremo izquierdo (Pin 28)
    input  wire S2,          // Sensor izquierdo centro (Pin 29)
    input  wire S3,          // Sensor centro (Pin 30)
    input  wire S4,          // Sensor derecho centro (Pin 31)
    input  wire S5,          // Sensor extremo derecho (Pin 32)
    input  wire LDR_IN,      // Sensor óptico de arranque autónomo (Pin 33)
    output wire M_IZQ,       // Velocidad Motor Izquierdo - PWM (Pin 40)
    output wire M_DER,       // Velocidad Motor Derecho - PWM (Pin 41)
    output wire M_IZQ_DIR,   // Dirección Motor Izquierdo (Pin 34)
    output wire M_DER_DIR,   // Dirección Motor Derecho (Pin 35)
    
    output wire LED_REC,     // LED marcha recta (Pin 13 - LED2, activo en bajo)
    output wire LED_IZQ,     // LED giro izquierda (Pin 14 - LED3, activo en bajo)
    output wire LED_DER,     // LED giro derecha (Pin 15 - LED4, activo en bajo)
    output wire LED_STOP     // LED parada / espera (Pin 16 - LED5, activo en bajo)
);

    // --- SEÑALES DE INTERCONEXIÓN ---
    wire       start_flag;
    wire [7:0] duty_cycle_izq;
    wire [7:0] duty_cycle_der;
    wire       dir_izq_internal;
    wire       dir_der_internal;
    wire       pwm_izq_internal;
    wire       pwm_der_internal;
    wire       led_rec_internal;
    wire       led_izq_internal;
    wire       led_der_internal;
    wire       led_stop_internal;

    // --- INSTANCIACIÓN DE SUBMÓDULOS ---

    // 1. Filtro del Sensor de Arranque LDR (LÓGICA INVERTIDA PARA PRUEBA)
    filtro_arranque inst_filtro_arranque (
        .CLK(CLK),
        .RST(RST),
        .LDR_IN(~LDR_IN), // Vuelve a estar invertido: LUZ = 0 analógico -> 1 Digital
        .start_flag(start_flag)
    );
    
    // ARRANQUE DIRECTO DESACTIVADO
    // assign start_flag = 1'b1;

    // 2. Núcleo Lógico del Seguidor de Línea (SE INVIERTEN LOS SENSORES AQUÍ)
    seguidor_linea_core inst_seguidor_core (
        .CLK(CLK),
        .RST(RST),
        .start_flag(start_flag),
        .S1(~S1), .S2(~S2), .S3(~S3), .S4(~S4), .S5(~S5), // <-- Lógica Invertida
        .duty_cycle_izq(duty_cycle_izq),
        .duty_cycle_der(duty_cycle_der),
        .dir_izq(dir_izq_internal),
        .dir_der(dir_der_internal),
        .LED_REC_state(led_rec_internal),
        .LED_IZQ_state(led_izq_internal),
        .LED_DER_state(led_der_internal),
        .LED_STOP_state(led_stop_internal)
    );

    // 3. Generador de Modulación de Ancho de Pulso (PWM)
    controlador_pwm inst_controlador_pwm (
        .CLK(CLK),
        .RST(RST),
        .duty_cycle_izq(duty_cycle_izq),
        .duty_cycle_der(duty_cycle_der),
        .PWM_IZQ(pwm_izq_internal),
        .PWM_DER(pwm_der_internal)
    );

    // --- ASIGNACIONES ELÉCTRICAS DE CONTROL (Adaptación para L298N a 4 hilos) ---
    // Si dir = 0 (Adelante): IN1 recibe PWM, IN2 recibe 0
    // Si dir = 1 (Atrás):    IN1 recibe 0,   IN2 recibe PWM
    
    // Motor Izquierdo
    assign M_IZQ     = (dir_izq_internal == 1'b0) ? pwm_izq_internal : 1'b0; // Conectar a IN1
    assign M_IZQ_DIR = (dir_izq_internal == 1'b1) ? pwm_izq_internal : 1'b0; // Conectar a IN2

    // Motor Derecho
    assign M_DER     = (dir_der_internal == 1'b0) ? pwm_der_internal : 1'b0; // Conectar a IN3
    assign M_DER_DIR = (dir_der_internal == 1'b1) ? pwm_der_internal : 1'b0; // Conectar a IN4

    // Inversión lógica para LEDs active-low de la placa Tang Nano 9K
    assign LED_REC  = ~led_rec_internal;
    assign LED_IZQ  = ~led_izq_internal;
    assign LED_DER  = ~led_der_internal;
    assign LED_STOP = ~led_stop_internal;

endmodule
