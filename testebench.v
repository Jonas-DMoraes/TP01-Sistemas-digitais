// =================================================================================
// Arquivo:         testbench.v
// Descrição:       Testbench para o projeto Elevador.v
// =Module a ser testado: Elevador_Top
// =================================================================================
`timescale 1ns / 1ps

module tb_Elevador;

    // =============================================================================
    // --- Parâmetros de Simulação ---
    // =============================================================================

    // Período do clock_50MHz (20ns)
    localparam CLOCK_PERIOD = 20;

    // O tempo de 1 segundo (usado pelo slow_clock) em nanossegundos
    // 50.000.000 de ciclos * 20ns/ciclo = 1.000.000.000 ns
    localparam SIM_TIME_1S = 1_000_000_000;

    // =============================================================================
    // --- Sinais (regs para Entradas, wires para Saídas) ---
    // =============================================================================

    // --- Entradas ---
    reg clock_50MHz;
    reg reset_geral;
    reg [4:0] botoes_chamar;
    reg botao_emergencia;
    reg botao_pessoa_entra;
    reg botao_pessoa_sai;

    // --- Saídas ---
    wire [6:0] display_andar;
    wire led_parado;
    wire led_subindo;
    wire led_descendo;
    wire led_lotado;

    // =============================================================================
    // --- Instanciação do Módulo (Device Under Test) ---
    // =============================================================================

    Elevador_Top DUT (
        .clock_50MHz(clock_50MHz),
        .reset_geral(reset_geral),
        .botoes_chamar(botoes_chamar),
        .botao_emergencia(botao_emergencia),
        .botao_pessoa_entra(botao_pessoa_entra),
        .botao_pessoa_sai(botao_pessoa_sai),
        .display_andar(display_andar),
        .led_parado(led_parado),
        .led_subindo(led_subindo),
        .led_descendo(led_descendo),
        .led_lotado(led_lotado)
    );

    // =============================================================================
    // --- Geração de Clock ---
    // =============================================================================

    // Gera o clock de 50MHz (período de 20ns)
    always # (CLOCK_PERIOD / 2) begin
        clock_50MHz = ~clock_50MHz;
    end

    // =============================================================================
    // --- Monitoramento (O que vemos no console) ---
    // =============================================================================

    // Esta variável auxiliar 'andar_atual_num' "traduz" o display
    // de 7 segmentos de volta para um número para facilitar a leitura.
    reg [2:0] andar_atual_num;

    always @(*) begin
        case (display_andar)
            7'b0111111: andar_atual_num = 0;
            7'b0000110: andar_atual_num = 1;
            7'b1011011: andar_atual_num = 2;
            7'b1001111: andar_atual_num = 3;
            7'b1100110: andar_atual_num = 4;
            default:    andar_atual_num = 9; // 'E' de Erro
        endcase
    end

    // Monitora os sinais e imprime no console sempre que algo mudar
    initial begin
        $display("----------------------------------------------------------------------");
        $display(" Início da Simulação do Elevador (GEX1209) ");
        $display(" Tempo(s) | Andar | Estado (P/S/D) | Lotado | Chamadas | Emergência");
        $display("----------------------------------------------------------------------");
        
        // $time / 1_000_000_000 = tempo em segundos
        $monitor(" %6.1f s |  %d  |      (%d/%d/%d)     |   %d    | %b |      %d",
                 $time / 1000000000.0,
                 andar_atual_num,
                 led_parado, led_subindo, led_descendo,
                 led_lotado,
                 botoes_chamar,
                 botao_emergencia);
    end

    // =============================================================================
    // --- Tarefas Auxiliares (para facilitar os testes) ---
    // =============================================================================
    
    // Simula o pressionar de um botão (por 2 ciclos de clock)
    task press_button_scalar;
        input button_reg; // O 'reg' a ser pressionado
        begin
            @(posedge clock_50MHz);
            button_reg = 1'b1;
            @(posedge clock_50MHz);
            @(posedge clock_50MHz);
            button_reg = 1'b0;
        end
    endtask

    // Simula o pressionar de um vetor de botões (ex: botões_chamar)
    task press_button_vector;
        input [4:0] button_value;
        begin
            @(posedge clock_50MHz);
            botoes_chamar = button_value;
            @(posedge clock_50MHz);
            @(posedge clock_50MHz);
            botoes_chamar = 5'b0;
        end
    endtask


    // =============================================================================
    // --- Sequência Principal de Teste ---
    // =============================================================================

    initial begin
        // --- Inicialização ---
        clock_50MHz = 0;
        reset_geral = 1; // Começa em reset
        botoes_chamar = 5'b0;
        botao_emergencia = 0;
        botao_pessoa_entra = 0;
        botao_pessoa_sai = 0;
        
        // Espera 5 ciclos de clock e libera o reset
        #(5 * CLOCK_PERIOD);
        reset_geral = 0;
        $display(">>> (TESTE 1) Sistema iniciado. Elevador deve estar no Térreo (0).");
        
        // Espera 1 segundo (simula tempo parado)
        #(SIM_TIME_1S);

        // --- CENÁRIO 2: Chamada Simples (0 -> 4) ---
        $display(">>> (TESTE 2) Chamando para o andar 4.");
        press_button_vector(5'b10000); // Chama o andar 4
        
        // Espera 6 segundos (1s de 'delay' + 4s de viagem + 1s de folga)
        #(6 * SIM_TIME_1S);
        $display(">>> (TESTE 2) Deve ter chegado ao andar 4.");

        // --- CENÁRIO 3: Prioridade (Mais Próximo) ---
        // Estamos no andar 4.
        $display(">>> (TESTE 3) No andar 4. Chamando Andar 1 e Andar 3 (simultâneo).");
        press_button_vector(5'b01010); // Chama andar 1 e 3
        
        // Deve ir para o Andar 3 primeiro (distância 1)
        #(3 * SIM_TIME_1S); // (1s delay + 1s viagem + 1s folga)
        $display(">>> (TESTE 3) Deve ter parado no Andar 3 (o mais próximo).");
        
        // Agora, deve automaticamente seguir para o Andar 1 (a outra chamada)
        #(4 * SIM_TIME_1S); // (1s delay + 2s viagem + 1s folga)
        $display(">>> (TESTE 3) Deve ter chegado ao Andar 1 (segunda chamada).");
        
        #(SIM_TIME_1S);

        // --- CENÁRIO 4: Atender no Caminho (1 -> 3) ---
        // Estamos no andar 1.
        $display(">>> (TESTE 4) No andar 1. Chamando para o Andar 3.");
        press_button_vector(5'b01000); // Chama andar 3
        
        // Espera 1.5 segundos (estará entre o andar 1 e 2)
        #(1.5 * SIM_TIME_1S);
        $display(">>> (TESTE 4) Em trânsito... Chamando Andar 2 (parada no caminho).");
        press_button_vector(5'b00100); // Chama andar 2
        
        // Deve parar no 2 primeiro
        #(2 * SIM_TIME_1S);
        $display(">>> (TESTE 4) Deve ter parado no Andar 2.");
        
        // E agora seguir para o 3
        #(3 * SIM_TIME_1S);
        $display(">>> (TESTE 4) Deve ter chegado ao Andar 3.");

        // --- CENÁRIO 5: Lotação ---
        // Estamos no andar 3.
        $display(">>> (TESTE 5) No andar 3. Simulando 5 pessoas entrando (lotação).");
        // Simula 5 pessoas entrando (MAX_PESSOAS = 5)
        repeat (5) begin
            press_button_scalar(botao_pessoa_entra);
            #(CLOCK_PERIOD * 10);
        end
        $display(">>> (TESTE 5) Elevador está LOTADO.");
        
        $display(">>> (TESTE 5) Chamando para o Andar 0.");
        press_button_vector(5'b00001); // Chama andar 0

        // Espera 1.5 segundos (estará entre 3 e 2)
        #(1.5 * SIM_TIME_1S);
        $display(">>> (TESTE 5) Em trânsito... Chamando Andar 1 (deve IGNORAR).");
        press_button_vector(5'b00010); // Chama andar 1

        // Deve ir direto para o 0, ignorando a chamada no 1
        #(4 * SIM_TIME_1S);
        $display(">>> (TESTE 5) Deve ter chegado ao Andar 0 (ignorado Andar 1).");
        
        // Esvazia o elevador
        repeat (5) begin
            press_button_scalar(botao_pessoa_sai);
            #(CLOCK_PERIOD * 10);
        end
        $display(">>> (TESTE 5) Elevador vazio. LED Lotado deve apagar.");

        // --- CENÁRIO 6: Emergência ---
        // Estamos no andar 0.
        $display(">>> (TESTE 6) No andar 0. Chamando para o Andar 4.");
        press_button_vector(5'b10000); // Chama andar 4

        // Espera 2.5 segundos (estará no andar 2, subindo)
        #(2.5 * SIM_TIME_1S);
        $display(">>> (TESTE 6) Em trânsito... ACIONANDO EMERGÊNCIA!");
        press_button_scalar(botao_emergencia);

        // Deve parar de subir e descer imediatamente para o 0
        #(4 * SIM_TIME_1S); // (Tempo para descer de volta)
        $display(">>> (TESTE 6) Deve ter retornado ao Andar 0.");

        // --- Fim ---
        #(2 * SIM_TIME_1S);
        $display("----------------------------------------------------------------------");
        $display(" Fim da Simulação ");
        $display("----------------------------------------------------------------------");
        $finish;
    end

endmodule