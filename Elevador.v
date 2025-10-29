module Elevador(
    input wire clock,
    input wire reset,         // reinicia o FSM
    input wire emergencia,    // botão para voltar ao andar 0
    input wire [2:0] andar_atual,        // andares de 0 a 4
    input wire [2:0] andar_requisitado,  // destino
    output reg motor_liga,
    output reg motor_direcao, // 1 sobe, 0 desce
    output reg [1:0] led_estado
);

    // Definição dos estados
    parameter S0 = 2'b00; // Parado
    parameter S1 = 2'b01; // Subindo
    parameter S2 = 2'b10; // Descendo

    reg [1:0] estado_atual;
    reg [1:0] proximo_estado;

    // =====================================
    // Atualização do estado
    // =====================================
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            estado_atual <= S0; // Começa parado
        end else begin
            estado_atual <= proximo_estado;
        end
    end

    // =====================================
    // Lógica de transição de estados
    // =====================================
    always @(*) begin
        proximo_estado = estado_atual;

        if (emergencia) begin
            if (andar_atual == 3'b000)
                proximo_estado = S0;
            else
                proximo_estado = S2; // força a descer
        end else begin
            case (estado_atual)
                S0: begin
                    if (andar_requisitado > andar_atual)
                        proximo_estado = S1;
                    else if (andar_requisitado < andar_atual)
                        proximo_estado = S2;
                    else
                        proximo_estado = S0;
                end

                S1: begin
                    if (andar_atual == andar_requisitado)
                        proximo_estado = S0;
                end

                S2: begin
                    if (andar_atual == andar_requisitado)
                        proximo_estado = S0;
                end

                default: proximo_estado = S0;
            endcase
        end
    end

    // =====================================
    // Saídas (motor e LEDs)
    // =====================================
    always @(*) begin
        motor_liga = 1'b0;
        motor_direcao = 1'b0;

        case (estado_atual)
            S0: motor_liga = 1'b0; // Parado
            S1: begin
                motor_liga = 1'b1;
                motor_direcao = 1'b1; // Sobe
            end
            S2: begin
                motor_liga = 1'b1;
                motor_direcao = 1'b0; // Desce
            end
        endcase

        led_estado = estado_atual;
    end

endmodule
