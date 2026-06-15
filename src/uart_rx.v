// ============================================================================
// Proyecto: Controlador Digital de Seguidor de Línea Competitivo (UV 2026)
// Módulo: uart_rx (Receptor Serial)
//
// Descripción:
// Receptor UART básico a 9600 baudios para leer los comandos enviados 
// por el módulo Bluetooth HC-05.
// Reloj del sistema: 27 MHz
// ============================================================================

module uart_rx (
    input  wire       CLK,       // Reloj del sistema (27 MHz)
    input  wire       RST,       // Reset activo en bajo
    input  wire       RX,        // Pin de recepción de datos (Desde el HC-05 TX)
    output reg  [7:0] rx_data,   // Byte recibido
    output reg        rx_ready   // Pulso de 1 ciclo de reloj cuando hay un dato nuevo
);

    // Parámetros para 9600 baudios a 27 MHz
    // Ciclos por bit = 27,000,000 / 9600 = 2812
    localparam [11:0] CYCLES_PER_BIT = 12'd2812;
    localparam [11:0] HALF_CYCLE     = 12'd1406;

    // Estados de la máquina de estados finita (FSM)
    localparam [2:0] IDLE  = 3'd0;
    localparam [2:0] START = 3'd1;
    localparam [2:0] DATA  = 3'd2;
    localparam [2:0] STOP  = 3'd3;

    reg [2:0]  state;
    reg [11:0] clock_count;
    reg [2:0]  bit_index;
    reg [7:0]  rx_buffer;
    
    // Sincronizador de la señal RX para evitar metaestabilidad
    reg rx_sync_1, rx_sync_2;

    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            rx_sync_1 <= 1'b1;
            rx_sync_2 <= 1'b1;
        end else begin
            rx_sync_1 <= RX;
            rx_sync_2 <= rx_sync_1;
        end
    end

    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            state       <= IDLE;
            clock_count <= 12'd0;
            bit_index   <= 3'd0;
            rx_buffer   <= 8'd0;
            rx_data     <= 8'd0;
            rx_ready    <= 1'b0;
        end else begin
            rx_ready <= 1'b0; // Por defecto no hay dato nuevo (pulso de 1 ciclo)

            case (state)
                IDLE: begin
                    clock_count <= 12'd0;
                    bit_index   <= 3'd0;
                    if (rx_sync_2 == 1'b0) begin
                        // Se detectó un flanco de bajada (Posible Start Bit)
                        state <= START;
                    end
                end

                START: begin
                    if (clock_count == HALF_CYCLE) begin
                        if (rx_sync_2 == 1'b0) begin
                            // Confirmado que es un Start Bit válido (sigue en 0 a la mitad)
                            clock_count <= 12'd0;
                            state       <= DATA;
                        end else begin
                            // Falsa alarma (ruido)
                            state <= IDLE;
                        end
                    end else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                DATA: begin
                    if (clock_count == CYCLES_PER_BIT) begin
                        clock_count          <= 12'd0;
                        rx_buffer[bit_index] <= rx_sync_2; // Guardar el bit recibido
                        
                        if (bit_index == 3'd7) begin
                            state <= STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                STOP: begin
                    // Esperar la mitad del bit de Stop para asegurar que la línea vuelve a 1
                    if (clock_count == HALF_CYCLE) begin
                        state    <= IDLE;
                        rx_data  <= rx_buffer; // Exponer el dato validado
                        rx_ready <= 1'b1;      // Generar el pulso de validación
                    end else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
