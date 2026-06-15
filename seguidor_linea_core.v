// ============================================================================
// Proyecto: Controlador Digital de Seguidor de Línea Competitivo (UV 2026)
// Módulo: controlador_pwm
//
// Descripción:
// Generador PWM de 8 bits (resolución 0 a 255) para controlar la velocidad
// de los dos motores. La frecuencia portadora es de aprox. 20.7 kHz,
// ideal para motores N20 (fuera de rango audible y reduce zumbidos).
// ============================================================================

module controlador_pwm (
    input  wire       CLK,             // Reloj del sistema (27 MHz)
    input  wire       RST,             // Reset activo en bajo
    input  wire [7:0] duty_cycle_izq,  // Ciclo de trabajo izquierdo (0-255)
    input  wire [7:0] duty_cycle_der,  // Ciclo de trabajo derecho (0-255)
    output reg        PWM_IZQ,         // Señal PWM para motor izquierdo
    output reg        PWM_DER          // Señal PWM para motor derecho
);

    // Prescaler para bajar de 27 MHz a la frecuencia del paso del contador
    // Queremos frecuencia PWM ~20.7 kHz -> Periodo ~48.3 us.
    // Con un contador de 8 bits (256 pasos), cada paso debe durar: 48.3 us / 256 = 188.6 ns.
    // Ciclo de reloj de 27 MHz = 37.037 ns.
    // 188.6 ns / 37.037 ns = 5.09 ciclos.
    // Usamos un divisor entre 5 (cuenta de 0 a 4).
    reg [2:0] prescaler;
    reg [7:0] pwm_counter;

    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            prescaler   <= 3'd0;
            pwm_counter <= 8'd0;
        end else begin
            if (prescaler >= 3'd4) begin
                prescaler   <= 3'd0;
                pwm_counter <= pwm_counter + 1'b1;
            end else begin
                prescaler <= prescaler + 1'b1;
            end
        end
    end

    // Lógica de comparación para generar el ancho de pulso
    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            PWM_IZQ <= 1'b0;
            PWM_DER <= 1'b0;
        end else begin
            PWM_IZQ <= (duty_cycle_izq > pwm_counter) ? 1'b1 : 1'b0;
            PWM_DER <= (duty_cycle_der > pwm_counter) ? 1'b1 : 1'b0;
        end
    end

endmodule
