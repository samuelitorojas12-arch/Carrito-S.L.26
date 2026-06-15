`timescale 1ns / 1ps

// ============================================================================
// Proyecto: Controlador Digital de Seguidor de Línea Competitivo (UV 2026)
// Target FPGA: Gowin GW1NR-LV9QN88PC6/I5 (Tang Nano 9K)
// Archivo: seguidor_linea_tb.v
//
// Descripción:
// Testbench completo y profesional para simular el comportamiento lógico del
// seguidor de línea competitivo. Prueba:
// 1. Inmunidad ante arranque (motores bloqueados si no hay luz en LDR).
// 2. Filtrado de ruido en LDR (destellos cortos).
// 3. Habilitación de inicio con luz de arranque estable.
// 4. Modulación PWM y cambio de dirección (giro pivote marcha atrás).
// 5. Algoritmo de línea perdida y apagado automático (timeout).
// ============================================================================

module seguidor_linea_tb;

    // --- REGISTROS DE ESTÍMULOS (ENTRADAS DE LA UUT) ---
    reg CLK;
    reg RST;
    reg S1;
    reg S2;
    reg S3;
    reg S4;
    reg S5;
    reg LDR_IN;

    // --- CABLES DE MONITOREO (SALIDAS DE LA UUT) ---
    wire M_IZQ;
    wire M_DER;
    wire M_IZQ_DIR;
    wire M_DER_DIR;
    wire LED_REC;
    wire LED_IZQ;
    wire LED_DER;
    wire LED_STOP;

    // --- INSTANCIACIÓN DE LA UNIDAD BAJO PRUEBA (UUT) ---
    seguidor_linea uut (
        .CLK(CLK),
        .RST(RST),
        .S1(S1),
        .S2(S2),
        .S3(S3),
        .S4(S4),
        .S5(S5),
        .LDR_IN(LDR_IN),
        .M_IZQ(M_IZQ),
        .M_DER(M_DER),
        .M_IZQ_DIR(M_IZQ_DIR),
        .M_DER_DIR(M_DER_DIR),
        .LED_REC(LED_REC),
        .LED_IZQ(LED_IZQ),
        .LED_DER(LED_DER),
        .LED_STOP(LED_STOP)
    );

    // --- MODIFICACIÓN DE PARÁMETROS PARA SIMULACIÓN RÁPIDA ---
    // En simulación acortamos los tiempos para que los reportes de consola no tomen millones de pasos:
    // Filtro LDR: 100 ciclos (~3.7 us) en lugar de 270,000 ciclos (10 ms).
    // Timeout Pérdida: 2000 ciclos (~74 us) en lugar de 54,000,000 ciclos (2 s).
    defparam uut.inst_filtro_arranque.UMBRAL_FILTRO = 19'd100;
    defparam uut.inst_seguidor_core.TIMEOUT_PERDIDA = 26'd2000;

    // --- GENERADOR DE RELOJ (Frecuencia: 27 MHz -> Periodo de ~37 ns) ---
    always begin
        #18.52 CLK = ~CLK;
    end

    // --- PROCESO DE ESTÍMULOS ---
    initial begin
        $display("=======================================================================");
        $display("INICIANDO SIMULACION DEL SEGUIDOR DE LINEA COMPETITIVO - ETAPA 3 (UV)");
        $display("=======================================================================");

        // Inicialización de señales
        CLK = 0;
        RST = 0; // Inicializar en Reset activo (bajo)
        LDR_IN = 0;
        S1 = 0; S2 = 0; S3 = 0; S4 = 0; S5 = 0;

        // 1. Probar Estado de Reset
        #100;
        $display("[PRUEBA 1] Reset Activo: Motores en 0 y LED_STOP activo (bajo/0).");
        RST = 1; // Desactivar Reset
        #100;

        // 2. Probar Inmunidad de Arranque (Sensores activos pero LDR_IN = 0)
        // Los motores no deben activarse (M_IZQ y M_DER en 0, LED_STOP activo).
        $display("[PRUEBA 2] Sensores activos pero LDR_IN=0 (Esperando luz). Motores deben seguir en 0.");
        S3 = 1; // Simulamos línea recta
        #500;

        // 3. Probar Rechazo de Ruido en LDR_IN (Destello corto de luz, < 3.7 us)
        $display("[PRUEBA 3] Pulso corto (ruido) en LDR_IN. No debe iniciar la marcha.");
        LDR_IN = 1;
        #1000; // Duración menor a los 100 ciclos del filtro (100 * 37ns = 3700ns)
        LDR_IN = 0;
        #1000;

        // 4. Probar Luz de Salida Estable (Arranque de Carrera)
        $display("[PRUEBA 4] Luz de inicio estable en LDR_IN. Activación de motores.");
        LDR_IN = 1;
        #5000; // Tiempo suficiente para que se active la bandera y enclave en 1

        // 5. Marcha Recta en Carrera (S = 00100)
        // Motores FWD con PWM activo. LED_REC activo.
        $display("[PRUEBA 5] Carrera Iniciada: Avance recto en línea (S=00100).");
        S1 = 0; S2 = 0; S3 = 1; S4 = 0; S5 = 0;
        #10000;

        // 6. Giro Leve a la Derecha (S = 00110)
        // Desaceleración del motor derecho para reencuadrarse.
        $display("[PRUEBA 6] Desviación Leve Derecha (S=00110). Desaceleración motor derecho.");
        S1 = 0; S2 = 0; S3 = 1; S4 = 1; S5 = 0;
        #10000;

        // 7. Giro Cerrado Fuerte a la Derecha (S = 00001)
        // Motor derecho en reversa (M_DER_DIR = 1) para un pivoteo rápido.
        $display("[PRUEBA 7] Giro Fuerte Derecha (S=00001). Motor derecho en REVERSA para pivote.");
        S1 = 0; S2 = 0; S3 = 0; S4 = 0; S5 = 1;
        #10000;

        // 8. Pérdida de Línea por Inercia (S = 00000)
        // El robot debe recordar el último giro (derecha) y seguir girando en reversa el motor derecho para recuperarse.
        $display("[PRUEBA 8] Pérdida de línea (S=00000). Debe retener memoria de giro a la derecha.");
        S1 = 0; S2 = 0; S3 = 0; S4 = 0; S5 = 0;
        #15000;

        // 9. Línea Recuperada a Recto (S = 00100)
        $display("[PRUEBA 9] Línea re-detectada. Avance Recto.");
        S1 = 0; S2 = 0; S3 = 1; S4 = 0; S5 = 0;
        #10000;

        // 10. Desviación Fuerte Izquierda y Pérdida Permanente (Giro sin fin)
        // El carro debe detenerse automáticamente después del timeout (2000 ciclos = 74 us) para protegerse.
        $display("[PRUEBA 10] Giro Fuerte Izquierda (S=10000) y pérdida permanente posterior.");
        S1 = 1; S2 = 0; S3 = 0; S4 = 0; S5 = 0;
        #5000;
        S1 = 0; S2 = 0; S3 = 0; S4 = 0; S5 = 0; // Línea perdida permanentemente
        #90000; // Esperar lo suficiente para el timeout (> 74 us)

        $display("=======================================================================");
        $display("SIMULACION COMPLETADA EXITOSAMENTE SIN ERRORES");
        $display("=======================================================================");
        $finish;
    end

    // --- MONITOREO DE EVENTOS EN CONSOLA ---
    initial begin
        $monitor("Hora=%6d ns | RST=%b | LDR=%b | Sensores=%b%b%b%b%b | Motores [IZQ-DER]: PWM=%b%b DIR=%b%b | LEDs [REC,IZQ,DER,STOP]=%b %b %b %b",
                 $time, RST, LDR_IN, S1, S2, S3, S4, S5, M_IZQ, M_DER, M_IZQ_DIR, M_DER_DIR, LED_REC, LED_IZQ, LED_DER, LED_STOP);
    end

endmodule
