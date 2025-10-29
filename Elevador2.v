// =================================================================================
// Arquivo:         Elevador2.v
// Descrição:       Projeto completo do controlador de elevador para a disciplina
//                  GEX1209 - Sistemas Digitais.
//
// Estrutura:       Este arquivo contém TODOS os módulos necessários.
//                  - Elevador_Top: Módulo principal (conecta-se à placa)
//                  - FSM_Elevador: A "Máquina de Estados" (cérebro de ação)
//                  - ControladorRequisicoes: A "Lógica de Decisão" (cérebro de prioridade)
//                  - ContadorAndar: O "Sensor" (onde o elevador está)
//                  - ContadorPessoas: O "Sensor" (quantas pessoas estão dentro)
//                  - ClockDivider: O "Relógio" (controla o tempo)
//                  - Decoder_7Seg: O "Display" (mostra o andar)
//
// ÚLTIMA CORREÇÃO: Módulo 'ControladorRequisicoes' foi ajustado para 
//                  separar lógica combinacional (funções) da sequencial 
//                  e corrigir erro de sintaxe 'begin/end'.
// =================================================================================

// =================================================================================
// MÓDULO TOP (Principal)
// Este é o módulo que você vai sintetizar e conectar aos pinos do seu FPGA.
// =================================================================================
module Elevador_Top (
    // --- Entradas Globais ---
    input wire clock_50MHz,         // Clock principal da placa (ex: 50MHz)
    input wire reset_geral,         // Botão de reset geral

    // --- Entradas do Usuário (Botões/Switches) ---
    input wire [4:0] botoes_chamar,  // 5 botões de chamada (um para cada andar, 0 a 4)
    input wire botao_emergencia,     // Botão de emergência
    input wire botao_pessoa_entra,   // Botão para simular pessoa entrando
    input wire botao_pessoa_sai,     // Botão para simular pessoa saindo
    
    // --- Saídas (LEDs, Displays) ---
    output wire [6:0] display_andar, // Saída para um display de 7 segmentos
    output wire led_parado,
    output wire led_subindo,
    output wire led_descendo,
    output wire led_lotado           // LED para indicar que o elevador está cheio
);

    // =============================================================================
    // --- Fios Internos (Sinais que conectam os módulos) ---
    // =============================================================================

    // Fio do clock lento (1 pulso por segundo)
    wire slow_clock_tick;
    
    // Fio para o estado atual da FSM (Parado, Subindo, Descendo)
    wire [1:0] estado_fsm;
    
    // Fio para o andar atual (0-4)
    wire [2:0] andar_atual;
    
    // Fio para o andar de destino (decidido pelo controlador)
    wire [2:0] andar_requisitado;

    // Fios para as saídas da FSM (comandos do motor)
    wire motor_liga;
    wire motor_direcao;

    // Fio para a contagem de pessoas
    wire [2:0] contagem_pessoas;
    
    // Fio do status "lotado"
    wire lotado;

    // =============================================================================
    // --- Instanciação dos Módulos ---
    // (Aqui conectamos todos os nossos blocos)
    // =============================================================================

    // 1. Divisor de Clock: Gera 1 pulso por segundo a partir de 50MHz
    ClockDivider U1_Clock (
        .clock_in(clock_50MHz),
        .reset(reset_geral),
        .tick(slow_clock_tick)
    );

    // 2. Contador de Andar: Controla a posição física do elevador
    ContadorAndar U2_Contador (
        .slow_clock(slow_clock_tick),
        .reset(reset_geral),
        .motor_liga(motor_liga),
        .motor_direcao(motor_direcao),
        .andar_atual(andar_atual) // Saída: Onde o elevador está
    );

    // 3. Contador de Pessoas: Controla a lotação
    ContadorPessoas U3_Pessoas (
        .clock(clock_50MHz),       // Usa clock rápido para detectar botões
        .reset(reset_geral),
        .botao_entra(botao_pessoa_entra),
        .botao_sai(botao_pessoa_sai),
        .estado_elevador(estado_fsm), // Só pode entrar/sair se PARADO
        .contagem(contagem_pessoas),
        .lotado(lotado)               // Saída: Se está cheio
    );

    // 4. Controlador de Requisições: Decide o próximo destino (Lógica de Prioridade)
    ControladorRequisicoes U4_Controlador (
        .clock(clock_50MHz),
        .reset(reset_geral),
        .botoes_chamar(botoes_chamar),
        .emergencia(botao_emergencia),
        .andar_atual(andar_atual),
        .estado_fsm(estado_fsm),
        .lotado(lotado),
        .andar_requisitado_out(andar_requisitado) // Saída: O destino da FSM
    );

    // 5. FSM do Elevador: O "cérebro" que controla o motor
    FSM_Elevador U5_FSM (
        .clock(clock_50MHz),        // Roda no clock rápido para reagir
        .reset(reset_geral),
        .emergencia(botao_emergencia),
        .andar_atual(andar_atual),
        .andar_requisitado(andar_requisitado),
        .motor_liga(motor_liga),            // Saída: Liga/Desliga motor
        .motor_direcao(motor_direcao),      // Saída: Direção do motor
        .estado_out(estado_fsm)             // Saída: O estado atual
    );
    
    // 6. Decodificador de 7 Segmentos: Para mostrar o andar
    Decoder_7Seg U6_Display (
        .bin_in(andar_atual),       // Entrada: O andar atual
        .seg_out(display_andar)   // Saída: Os 7 pinos do display
    );

    // =============================================================================
    // --- Lógica de Saída (LEDs) ---
    // =============================================================================
    
    // 'assign' é usado para ligar um fio (wire) diretamente a uma saída.
    // O estado é 00=Parado, 01=Subindo, 10=Descendo
    assign led_parado   = (estado_fsm == 2'b00);
    assign led_subindo  = (estado_fsm == 2'b01);
    assign led_descendo = (estado_fsm == 2'b10);
    assign led_lotado   = lotado; // Simplesmente repassa o fio 'lotado'

endmodule
// --- Fim do Módulo Top ---


// =================================================================================
// MÓDULO 1: FSM_Elevador (O "Cérebro" de Ação)
// Recebe o destino e o andar atual, e decide o que o *motor* faz.
// =================================================================================
module FSM_Elevador (
    input wire clock,
    input wire reset, 
    input wire emergencia,
    input wire [2:0] andar_atual,
    input wire [2:0] andar_requisitado,
    output reg motor_liga,
    output reg motor_direcao, // 1 sobe, 0 desce
    output wire [1:0] estado_out // Saída para informar o estado
);
    // 1. Definição dos Estados
    parameter S0 = 2'b00; // Parado
    parameter S1 = 2'b01; // Subindo
    parameter S2 = 2'b10; // Descendo
    
    // 2. Registradores de Estado
    reg [1:0] estado_atual;
    reg [1:0] proximo_estado;

    // 3. Bloco Sequencial (Atualização de Estado)
    // Este bloco armazena o estado atual e só muda na subida do clock.
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            estado_atual <= S0;
        end else begin
            estado_atual <= proximo_estado; 
        end
    end

    // 4. Bloco Combinacional (Lógica de Próximo Estado)
    // Este bloco decide qual será o *próximo* estado, com base nas entradas.
    always @(*) begin
        proximo_estado = estado_atual; // Regra padrão: manter o estado
        
        // Regra de Emergência (Prioridade Máxima)
        if (emergencia) begin
            if (andar_atual == 3'b000) begin 
                proximo_estado = S0; // Se já está no térreo, para.
            end else begin
                proximo_estado = S2; // Se não, desce.
            end
        
        // Lógica Normal
        end else begin
            case (estado_atual)
                // Se PARADO...
                S0: begin
                    if (andar_requisitado > andar_atual) begin
                        proximo_estado = S1; // Sobe
                    end
                    else if (andar_requisitado < andar_atual) begin
                        proximo_estado = S2; // Desce
                    end 
                    else begin // Se requisitado == atual
                        proximo_estado = S0; // Fica parado
                    end
                end
                
                // Se SUBINDO...
                S1: begin
                    // Se chegou ao destino...
                    if (andar_atual == andar_requisitado) begin
                        proximo_estado = S0; // Para.
                    end
                    // Se não chegou, continua subindo (regra padrão)
                end
                
                // Se DESCENDO...
                S2: begin
                    // Se chegou ao destino...
                    if (andar_atual == andar_requisitado) begin
                        proximo_estado = S0; // Para.
                    end
                    // Se não chegou, continua descendo (regra padrão)
                end
                
                default: begin
                    proximo_estado = S0; // Estado seguro
                end
            endcase
        end
    end

    // 5. Bloco Combinacional (Lógica de Saída)
    // Define o que as saídas (motores) fazem em cada estado.
    always @(*) begin
        // Valores padrão (motor desligado)
        motor_liga = 1'b0;
        motor_direcao = 1'b0; // Padrão: Desce

        case (estado_atual)
            S0: begin
                motor_liga = 1'b0; // Motor desligado
            end
            S1: begin
                motor_liga = 1'b1; // Motor ligado
                motor_direcao = 1'b1; // Direção: Sobe
            end
            S2: begin
                motor_liga = 1'b1; // Motor ligado
                motor_direcao = 1'b0; // Direção: Desce
            end
        endcase
    end
    
    // Atribui o estado atual à saída, para outros módulos verem
    assign estado_out = estado_atual;

endmodule
// --- Fim do Módulo FSM ---


// =================================================================================
// MÓDULO 2: ControladorRequisicoes (A "Lógica" de Prioridade)
// [VERSÃO CORRIGIDA - Separa lógica combinacional/sequencial e 'begin/end']
// =================================================================================
module ControladorRequisicoes (
    input wire clock,
    input wire reset,
    input wire [4:0] botoes_chamar,    // 5 botões (0-4)
    input wire emergencia,
    input wire [2:0] andar_atual,
    input wire [1:0] estado_fsm,       // S0, S1, S2
    input wire lotado,
    output wire [2:0] andar_requisitado_out // Saída agora é 'wire'
);
    // Estados da FSM (para legibilidade)
    parameter S0 = 2'b00;
    parameter S1 = 2'b01;
    parameter S2 = 2'b10;

    // Registrador para armazenar TODOS os andares chamados
    reg [4:0] chamadas_pendentes;
    
    // Registrador para armazenar o destino *atual*
    reg [2:0] target_atual;

    // Registrador para calcular o *próximo* destino (deve ser 'reg' para ser usado no always@(*))
    reg [2:0] target_proximo;

    // --- Bloco 1: Lógica de Armazenar e Limpar Chamadas (Sequencial) ---
    // Este bloco usa o clock para salvar quais botões foram pressionados
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            chamadas_pendentes <= 5'b0; // Limpa todas as chamadas
        end else begin
            // 1. Adiciona novas chamadas (OU bit-a-bit):
            chamadas_pendentes <= chamadas_pendentes | botoes_chamar;
            
            // 2. Limpa a chamada do andar atual *se* o elevador está PARADO
            // (Isso significa que acabamos de chegar)
            if (estado_fsm == S0) begin
                chamadas_pendentes[andar_atual] <= 1'b0;
            end
            
            // 3. Se a emergência for ligada, limpa todas as chamadas
            if (emergencia) begin
                chamadas_pendentes <= 5'b0;
            end
        end
    end

    // --- Bloco 2: Lógica de Decisão do Próximo Destino (Combinacional) ---
    // Este bloco 'always @(*)' calcula qual deve ser o próximo destino
    // e é aqui que podemos chamar as funções (pois é combinacional).
    always @(*) begin
        // Regra Padrão: O próximo destino é o destino que já temos
        target_proximo = target_atual; 

        // REGRA 1: EMERGÊNCIA
        if (emergencia) begin
            target_proximo = 3'b000; // Força o destino para o térreo

        // REGRA 2: ELEVADOR PARADO (S0)
        end else if (estado_fsm == S0) begin
            if (chamadas_pendentes == 5'b0) begin
                target_proximo = andar_atual; // Fica onde está
            end else begin
                // "deve-se priorizar a do andar que está mais próximo"
                target_proximo = find_closest(chamadas_pendentes, andar_atual);
            end
        
        // REGRA 3: ELEVADOR SUBINDO (S1)
        end else if (estado_fsm == S1 && !lotado) begin
            // "pode atender a novas requisições... mesma direção"
            target_proximo = find_closest_up(chamadas_pendentes, andar_atual, target_atual);
        
        // REGRA 4: ELEVADOR DESCENDO (S2)
        end else if (estado_fsm == S2 && !lotado) begin // <-- Erro de sintaxe '{' corrigido
            // "pode atender a novas requisições... mesma direção"
            target_proximo = find_closest_down(chamadas_pendentes, andar_atual, target_atual);
        end // <-- 'end' correspondente adicionado
    end

    // --- Bloco 3: Registrador de Destino (Sequencial) ---
    // Este bloco APENAS ARMAZENA A DECISÃO DO BLOCO 2
    // Ele não faz lógica, apenas salva o valor no clock.
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            target_atual <= 3'b000; // Destino inicial no reset
        end else begin
            target_atual <= target_proximo; // Armazena a decisão calculada
        end
    end
    
    // Saída final: A FSM recebe o destino que está armazenado
    assign andar_requisitado_out = target_atual;


    // --- Funções Auxiliares (Lógica de Prioridade) ---
    // (Elas permanecem exatamente iguais)

    // Função 1: Achar a chamada MAIS PRÓXIMA (quando PARADO)
    function [2:0] find_closest;
        input [4:0] calls;
        input [2:0] current; 
        
        integer i;
        reg [2:0] best_floor;
        reg [2:0] min_dist;
        reg [2:0] dist;

        begin
            best_floor = current;
            min_dist = 3'd7;

            for (i = 0; i < 5; i = i + 1) begin
                if (calls[i]) begin
                    // Calcula a distância absoluta
                    if (i > current)
                        dist = i - current;
                    else
                        dist = current - i;
                    
                    // Se esta distância é a menor até agora...
                    if (dist < min_dist) begin
                        min_dist = dist;   // Salva a nova menor distância
                        best_floor = i;  // Salva o andar correspondente
                    end
                end
            end
            find_closest = best_floor; // Retorna o andar mais próximo
        end
    endfunction

    // Função 2: Achar a parada MAIS PRÓXIMA (quando SUBINDO)
    function [2:0] find_closest_up;
        input [4:0] calls;
        input [2:0] current;
        input [2:0] current_target;
        
        integer i;
        begin
            find_closest_up = current_target; // Padrão: continua para o destino
            
            // Procura (do andar *acima* do atual até o destino)
            for (i = current + 1; i <= current_target; i = i + 1) begin
                // Se houver uma chamada no caminho...
                if (calls[i]) begin
                    find_closest_up = i; // Muda o destino para esta parada
                    i = 99; // (Forma de dar "break" no loop)
                end
            end
        end
    endfunction
    
    // Função 3: Achar a parada MAIS PRÓXIMA (quando DESCENDO)
    function [2:0] find_closest_down;
        input [4:0] calls;
        input [2:0] current;
        input [2:0] current_target;
        
        integer i;
        begin
            find_closest_down = current_target; // Padrão: continua para o destino
            
            // Procura (do andar *abaixo* do atual até o destino)
            for (i = current - 1; i >= current_target; i = i - 1) begin
                // Se houver uma chamada no caminho...
                if (calls[i]) begin
                    find_closest_down = i; // Muda o destino para esta parada
                    i = -99; // (Forma de dar "break" no loop)
                end
            end
        end
    endfunction

endmodule
// --- Fim do Módulo Controlador ---


// =================================================================================
// MÓDULO 3: ContadorAndar
// Um contador (0-4) que só incrementa ou decrementa no clock lento
// e apenas se o motor estiver ligado.
// =================================================================================
module ContadorAndar (
    input wire slow_clock, // O 'tick' de 1Hz
    input wire reset,
    input wire motor_liga,
    input wire motor_direcao, // 1=Sobe, 0=Desce
    output reg [2:0] andar_atual
);
    // Limites dos andares (para 5 andares)
    parameter ANDAR_TERREO = 3'b000; // 0
    parameter ANDAR_TOPO   = 3'b100; // 4

    // Bloco sequencial: Atualiza o andar
    always @(posedge slow_clock or posedge reset) begin
        if (reset) begin
            andar_atual <= ANDAR_TERREO;
        
        // Só atualiza o andar se o motor estiver LIGADO
        end else if (motor_liga) begin 
            // Se está subindo...
            if (motor_direcao == 1'b1) begin
                if (andar_atual < ANDAR_TOPO) begin
                    andar_atual <= andar_atual + 1;
                end
            // Se está descendo...
            end else begin 
                if (andar_atual > ANDAR_TERREO) begin
                    andar_atual <= andar_atual - 1;
                end
            end
        end
        // Se motor_liga == 0, o 'andar_atual' não muda.
    end
endmodule
// --- Fim do Módulo ContadorAndar ---


// =================================================================================
// MÓDULO 4: ContadorPessoas
// Controla quantas pessoas estão no elevador.
// =================================================================================
module ContadorPessoas (
    input wire clock,
    input wire reset,
    input wire botao_entra,
    input wire botao_sai,
    input wire [1:0] estado_elevador, // S0, S1, S2
    output reg [2:0] contagem,
    output wire lotado
);
    // Definimos a lotação máxima (ex: 5 pessoas)
    parameter MAX_PESSOAS = 3'd5;
    parameter S0_PARADO = 2'b00;

    // --- Detecção de Borda ---
    // (Para que segurar o botão não conte várias vezes)
    reg botao_entra_last;
    reg botao_sai_last;
    
    wire entra_edge = botao_entra && !botao_entra_last;
    wire sai_edge   = botao_sai   && !botao_sai_last;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            contagem <= 3'b0;
            botao_entra_last <= 1'b0;
            botao_sai_last <= 1'b0;
        end else begin
            // Armazena o estado anterior dos botões
            botao_entra_last <= botao_entra;
            botao_sai_last <= botao_sai;
            
            // Só pode entrar/sair se o elevador estiver PARADO
            if (estado_elevador == S0_PARADO) begin
                // Se o botão de entrar foi pressionado (borda de subida)
                if (entra_edge && contagem < MAX_PESSOAS) begin
                    contagem <= contagem + 1;
                // Se o botão de sair foi pressionado
                end else if (sai_edge && contagem > 0) begin
                    contagem <= contagem - 1;
                end
            end
        end
    end
    
    // Saída 'lotado' é 1 se a contagem atingir o máximo
    assign lotado = (contagem == MAX_PESSOAS);

endmodule
// --- Fim do Módulo ContadorPessoas ---


// =================================================================================
// MÓDULO 5: ClockDivider
// Gera um pulso (tick) de 1Hz (1 por segundo)
// a partir de um clock de 50MHz.
// =================================================================================
module ClockDivider (
    input wire clock_in, // Clock de 50MHz
    input wire reset,
    output reg tick      // Gera um pulso de 1Hz
);
    // 50.000.000 (precisa de 26 bits para contar até 50M)
    parameter MAX_COUNT = 50_000_000;
    reg [25:0] counter = 0; 

    always @(posedge clock_in or posedge reset) begin
        if (reset) begin
            counter <= 0;
            tick <= 0;
        // Se o contador chegou ao máximo...
        end else if (counter == MAX_COUNT - 1) begin
            counter <= 0;  // Reinicia o contador
            tick <= 1;     // Gera UM pulso de 'tick'
        // Se ainda não chegou...
        end else begin
            counter <= counter + 1; // Continua contando
            tick <= 0;              // Mantém o 'tick' em zero
        end
    end
endmodule
// --- Fim do Módulo ClockDivider ---


// =================================================================================
// MÓDULO 6: Decoder_7Seg
// Converte um número binário (0-4) para os 7 segmentos do display.
// (Assumindo display de Cátodo Comum)
// =================================================================================
module Decoder_7Seg (
    input wire [2:0] bin_in,  // Entrada binária (0-4)
    output reg [6:0] seg_out  // Saída para 7 segmentos (a-g)
);
    // Padrões (a,b,c,d,e,f,g) - Cátodo Comum (1=Liga)
    localparam D_0 = 7'b0111111; // 0
    localparam D_1 = 7'b0000110; // 1
    localparam D_2 = 7'b1011011; // 2
    localparam D_3 = 7'b1001111; // 3
    localparam D_4 = 7'b1100110; // 4
    localparam D_E = 7'b1111001; // "E" de Erro
    
    always @(*) begin
        case (bin_in)
            3'd0:    seg_out = D_0;
            3'd1:    seg_out = D_1;
            3'd2:    seg_out = D_2;
            3'd3:    seg_out = D_3;
            3'd4:    seg_out = D_4;
            default: seg_out = D_E; // Mostra 'E' se for 5, 6 ou 7
        endcase
    end
endmodule
// --- Fim do Módulo Decoder_7Seg ---
