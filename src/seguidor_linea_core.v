// ============================================================================
// Proyecto: Controlador Digital de Seguidor de Línea Competitivo (UV 2026)
// Módulo: seguidor_linea_core
//
// Descripción:
// Núcleo del seguidor de línea. Procesa los sensores de línea y la señal de inicio,
// calcula las velocidades (duty cycles) y direcciones de los motores, y genera
// los estados de los LEDs de monitoreo.
// Incluye algoritmo de recuperación con memoria de giro y parada automática por
// tiempo de línea perdida (2 segundos).
// ============================================================================

module seguidor_linea_core (
    input  wire       CLK,             // Reloj del sistema (27 MHz)
    input  wire       RST,             // Reset activo en bajo
    input  wire       start_flag,      // Bandera de inicio habilitada (1 = Iniciar, 0 = Esperar)
    input  wire       S1, S2, S3, S4, S5, // Entradas de los sensores
    output reg  [7:0] duty_cycle_izq,  // Ciclo de trabajo izquierdo (0-255)
    output reg  [7:0] duty_cycle_der,  // Ciclo de trabajo derecho (0-255)
    output reg        dir_izq,         // Dirección motor izquierdo (0 = FWD, 1 = REV)
    output reg        dir_der,         // Dirección motor derecho (0 = FWD, 1 = REV)
    output reg        LED_REC_state,   // LED marcha recta (activo en alto interno)
    output reg        LED_IZQ_state,   // LED giro izquierda
    output reg        LED_DER_state,   // LED giro derecha
    output reg        LED_STOP_state   // LED parada
);

    // --- PARÁMETROS DE VELOCIDAD EXTREMA (Configuración de Carrera) ---
    localparam [7:0] VEL_MAX  = 8'd255; // Velocidad en recta (100% - Límite físico del hardware)
    localparam [7:0] VEL_MED  = 8'd235; // Correcciones leves casi a tope (para no perder vuelo en curvas abiertas)
    localparam [7:0] VEL_MIN  = 8'd200; // Curvas cerradas bastante rápidas
    localparam [7:0] VEL_REV  = 8'd220; // Giro de pivote sumamente agresivo

    // --- PARÁMETRO DE TIEMPO LÍNEA PERDIDA (2 segundos a 27 MHz = 54,000,000 ciclos) ---
    localparam [25:0] TIMEOUT_PERDIDA = 26'd54000000;

    // --- REGISTROS DE MEMORIA DE ESTADO ---
    reg [1:0]  last_direction; // 00 = Recto, 01 = Izquierda, 10 = Derecha
    reg [25:0] lost_timer;     // Temporizador para contar el tiempo fuera de la línea
    reg        stop_timeout;   // Bandera que detiene el carro tras 2s fuera de la línea

    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            duty_cycle_izq <= 8'd0;
            duty_cycle_der <= 8'd0;
            dir_izq        <= 1'b0;
            dir_der        <= 1'b0;
            LED_REC_state  <= 1'b0;
            LED_IZQ_state  <= 1'b0;
            LED_DER_state  <= 1'b0;
            LED_STOP_state <= 1'b1; // Iniciamos indicando parada
            last_direction <= 2'b00;
            lost_timer     <= 26'd0;
            stop_timeout   <= 1'b0;
        end else if (!start_flag) begin
            // --- ESTADO DE ESPERA (Antes del disparo de luz de salida) ---
            duty_cycle_izq <= 8'd0;
            duty_cycle_der <= 8'd0;
            dir_izq        <= 1'b0;
            dir_der        <= 1'b0;
            LED_REC_state  <= 1'b0;
            LED_IZQ_state  <= 1'b0;
            LED_DER_state  <= 1'b0;
            LED_STOP_state <= 1'b1; // Espera en STOP
            lost_timer     <= 26'd0;
            stop_timeout   <= 1'b0;
        end else if (stop_timeout) begin
            // --- DETENCIÓN MÁXIMA DE SEGURIDAD (Se cumplieron los 2s fuera de línea) ---
            duty_cycle_izq <= 8'd0;
            duty_cycle_der <= 8'd0;
            dir_izq        <= 1'b0;
            dir_der        <= 1'b0;
            LED_REC_state  <= 1'b0;
            LED_IZQ_state  <= 1'b0;
            LED_DER_state  <= 1'b0;
            LED_STOP_state <= 1'b1;
        end else begin
            case ({S1, S2, S3, S4, S5})
                // --- AVANCE RECTO / LEVE DESVIACIÓN (Rectas rápidas) ---
                5'b00100: // Recto puro (Línea de 1cm)
                begin
                    duty_cycle_izq <= VEL_MAX;
                    duty_cycle_der <= VEL_MAX;
                    dir_izq        <= 1'b0;
                    dir_der        <= 1'b0;
                    LED_REC_state  <= 1'b1;
                    LED_IZQ_state  <= 1'b0;
                    LED_DER_state  <= 1'b0;
                    LED_STOP_state <= 1'b0;
                    last_direction <= 2'b00;
                    lost_timer     <= 26'd0;
                end
                5'b01100: // Desviación leve izquierda (Línea de 1cm)
                begin
                    duty_cycle_izq <= VEL_MED; // Frenar motor interno
                    duty_cycle_der <= VEL_MAX;
                    dir_izq        <= 1'b0;
                    dir_der        <= 1'b0;
                    LED_REC_state  <= 1'b1;
                    LED_IZQ_state  <= 1'b0;
                    LED_DER_state  <= 1'b0;
                    LED_STOP_state <= 1'b0;
                    last_direction <= 2'b01; // Guardar última corrección izquierda
                    lost_timer     <= 26'd0;
                end
                5'b00110: // Desviación leve derecha (Línea de 1cm)
                begin
                    duty_cycle_izq <= VEL_MAX;
                    duty_cycle_der <= VEL_MED; // Frenar motor interno
                    dir_izq        <= 1'b0;
                    dir_der        <= 1'b0;
                    LED_REC_state  <= 1'b1;
                    LED_IZQ_state  <= 1'b0;
                    LED_DER_state  <= 1'b0;
                    LED_STOP_state <= 1'b0;
                    last_direction <= 2'b10; // Guardar última corrección derecha
                    lost_timer     <= 26'd0;
                end

                // --- GIRO CERRADO A LA IZQUIERDA ---
                5'b01000: // Curva estándar izquierda (Línea de 1cm)
                begin
                    duty_cycle_izq <= VEL_MIN;
                    duty_cycle_der <= VEL_MAX;
                    dir_izq        <= 1'b0;
                    dir_der        <= 1'b0;
                    LED_REC_state  <= 1'b0;
                    LED_IZQ_state  <= 1'b1;
                    LED_DER_state  <= 1'b0;
                    LED_STOP_state <= 1'b0;
                    last_direction <= 2'b01;
                    lost_timer     <= 26'd0;
                end
                5'b10000: // Curva muy cerrada izquierda (Línea de 1cm)
                begin
                    duty_cycle_izq <= VEL_REV; // Motor interno marcha atrás
                    duty_cycle_der <= VEL_MAX;
                    dir_izq        <= 1'b1; // Marcha atrás activa
                    dir_der        <= 1'b0;
                    LED_REC_state  <= 1'b0;
                    LED_IZQ_state  <= 1'b1;
                    LED_DER_state  <= 1'b0;
                    LED_STOP_state <= 1'b0;
                    last_direction <= 2'b01;
                    lost_timer     <= 26'd0;
                end

                // --- GIRO CERRADO A LA DERECHA ---
                5'b00010: // Curva estándar derecha (Línea de 1cm)
                begin
                    duty_cycle_izq <= VEL_MAX;
                    duty_cycle_der <= VEL_MIN;
                    dir_izq        <= 1'b0;
                    dir_der        <= 1'b0;
                    LED_REC_state  <= 1'b0;
                    LED_IZQ_state  <= 1'b0;
                    LED_DER_state  <= 1'b1;
                    LED_STOP_state <= 1'b0;
                    last_direction <= 2'b10;
                    lost_timer     <= 26'd0;
                end
                5'b00001: // Curva muy cerrada derecha (Línea de 1cm)
                begin
                    duty_cycle_izq <= VEL_MAX;
                    duty_cycle_der <= VEL_REV; // Motor interno marcha atrás
                    dir_izq        <= 1'b0;
                    dir_der        <= 1'b1; // Marcha atrás activa
                    LED_REC_state  <= 1'b0;
                    LED_IZQ_state  <= 1'b0;
                    LED_DER_state  <= 1'b1;
                    LED_STOP_state <= 1'b0;
                    last_direction <= 2'b10;
                    lost_timer     <= 26'd0;
                end

                // --- PARADA INMEDIATA POR FIN DE PISTA ---
                5'b11111: // Línea de meta u oponente muy cerca (obstáculo)
                begin
                    duty_cycle_izq <= 8'd0;
                    duty_cycle_der <= 8'd0;
                    dir_izq        <= 1'b0;
                    dir_der        <= 1'b0;
                    LED_REC_state  <= 1'b0;
                    LED_IZQ_state  <= 1'b0;
                    LED_DER_state  <= 1'b0;
                    LED_STOP_state <= 1'b1; // STOP Activo
                    lost_timer     <= 26'd0;
                end

                // --- ALGORITMO DE LÍNEA PERDIDA (00000) ---
                5'b00000:
                begin
                    // Incrementar el timer para apagar si está perdido permanentemente
                    if (lost_timer >= TIMEOUT_PERDIDA) begin
                        stop_timeout <= 1'b1; // Activar detención automática de 10s
                    end else begin
                        lost_timer <= lost_timer + 1'b1;
                    end

                    // Lógica de recuperación por memoria de dirección
                    if (last_direction == 2'b01) begin
                        // Última vez visto a la izquierda: girar fuerte a la izquierda
                        duty_cycle_izq <= VEL_REV;
                        duty_cycle_der <= VEL_MED;
                        dir_izq        <= 1'b1; // REV
                        dir_der        <= 1'b0; // FWD
                        LED_REC_state  <= 1'b0;
                        LED_IZQ_state  <= 1'b1;
                        LED_DER_state  <= 1'b0;
                        LED_STOP_state <= 1'b0;
                    end else if (last_direction == 2'b10) begin
                        // Última vez visto a la derecha: girar fuerte a la derecha
                        duty_cycle_izq <= VEL_MED;
                        duty_cycle_der <= VEL_REV;
                        dir_izq        <= 1'b0; // FWD
                        dir_der        <= 1'b1; // REV
                        LED_REC_state  <= 1'b0;
                        LED_IZQ_state  <= 1'b0;
                        LED_DER_state  <= 1'b1;
                        LED_STOP_state <= 1'b0;
                    end else begin
                        // Si se perdió en recto puro, avanza despacio para intentar cruzar de nuevo la línea
                        duty_cycle_izq <= VEL_MIN;
                        duty_cycle_der <= VEL_MIN;
                        dir_izq        <= 1'b0;
                        dir_der        <= 1'b0;
                        LED_REC_state  <= 1'b0;
                        LED_IZQ_state  <= 1'b0;
                        LED_DER_state  <= 1'b0;
                        LED_STOP_state <= 1'b1;
                    end
                end

                // --- CASOS INDETERMINADOS (Retener estado previo) ---
                default: begin
                    duty_cycle_izq <= duty_cycle_izq;
                    duty_cycle_der <= duty_cycle_der;
                    dir_izq        <= dir_izq;
                    dir_der        <= dir_der;
                    LED_REC_state  <= LED_REC_state;
                    LED_IZQ_state  <= LED_IZQ_state;
                    LED_DER_state  <= LED_DER_state;
                    LED_STOP_state <= LED_STOP_state;
                end
            endcase
        end
    end

endmodule
