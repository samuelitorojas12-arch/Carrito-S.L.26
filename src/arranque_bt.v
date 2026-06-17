// ============================================================================
// Proyecto: Controlador Digital de Seguidor de Línea Competitivo (UV 2026)
// Módulo: arranque_bt (Decodificador de Comando Bluetooth)
//
// Descripción:
// Escucha los datos validados provenientes del receptor UART.
// Si recibe el caracter ASCII '1' (Hex 0x31), activa la bandera de inicio
// (start_flag_bt) y la mantiene enclavada hasta que haya un reset.
// ============================================================================

module arranque_bt (
    input  wire       CLK,            // Reloj del sistema
    input  wire       RST,            // Reset activo en bajo
    input  wire [7:0] rx_data,        // Byte recibido desde UART
    input  wire       rx_ready,       // Pulso de validación de dato nuevo
    output reg        start_flag_bt   // Bandera de inicio habilitada (Enclavada en 1)
);

    // Caracter de encendido esperado (ASCII '1' = 8'h31)
    localparam [7:0] CMD_START = 8'h31;
always @(posedge CLK or negedge RST) begin
    if (!RST) begin
        start_flag_bt <= 1'b0;
    end
    else if (rx_ready && rx_data == CMD_START) begin
        start_flag_bt <= 1'b1;
    end
end
    
                end
            end
        end
    end

endmodule
