// ============================================================================
// Proyecto: Controlador Digital de Seguidor de Línea con 5 Sensores
// Target FPGA: Gowin GW1NR-LV9QN88PC6/I5 (Tang Nano 9K)
// Archivo de Restricciones de Tiempo: seguidor_linea.sdc
//
// Descripción:
// Define la frecuencia del reloj del sistema (27 MHz - período de 37.037 ns)
// para el analizador de tiempos de Gowin, eliminando el Warning TA1132.
// ============================================================================

create_clock -name CLK -period 37.037 -waveform {0 18.518} [get_ports {CLK}]
