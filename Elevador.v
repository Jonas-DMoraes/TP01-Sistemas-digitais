module Elevador(
    input wire clock,
    input wire reset, /// para reiniciar o fsm
    input wire emergencia, ///botão para voltar a 1 andar
    input wire [2:0] andar_atual, ///andares de  0 a 4 bits
    input wire [2:0] andar_requisitado, ///destino
    output reg motor_liga,
    output reg motor_direcao, // 1 sobe, 0 desce
    output reg [1:0] led_estado
);
parameter     S0 = 2'b00; //Parado
              S1 = 2'b01;   //Subindo
              S2 = 2'b10 ;  // Descendo
    reg [1:0] estado_atual;
    reg [1:0] proximo_estado;

always @(posedge clock or posedge reset) begin // Atualização do estado com o reset
    if (reset) begin
        estado_atual <= S0; /// começa no estado parado
    end else begin
        estado_atual  <= proximo_estado;
    end
end
always @(*) begin
    proximo_estado = estado_atual;
    if (emergencia) begin  /// emergencia tem prioridade
        if (andar_atual == 3'b000) begin 
           proximo_estado = S0; 
        end else begin
            proximo_estado = S2;  /// força a descer o andar
        end
    end
    else begin
        case (estado_atual)
            S0: begin
                if (andar_requisitado > andar_atual) begin
                    proximo_estado = S1;
                end
                else if (andar_requisitado < andar_atual)begin
                    prox_estado = S2;
                end 
                else begin
                    prox_estado = S0;
                end
            end
            S1: begin
                if (andar_atual == andar_requisitado) begin
                    prox_estado = S0;
                end
            end
            S2: begin
                if(andar_atual == andar_requisitado) begin
                    prox_estado = S0;
                end
            end
            default: begin
                prox_estado = S0;
            end
            endcase
    end
end
/// Tive ajuda de IA nesse always
    always @(*) begin
        motor_liga = 1'b0;
        motor_direcao = 1'b0;
    end
    case (estado_atual)
        S0: begin
            motor_liga = 1'b0; // Motor desligado
        end
        S1: begin
            motor_liga = 1'b1; // Ligado
            motor_direcao = 1'b1;// subindo
        end
        S2: begin
            motor_liga = 1'b1;
            motor_direcao = 1'b0; //Desce
        end
    endcase
        led_estado = estado_atual;
    endmodule
