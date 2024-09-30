module fsm_single_master 
(
    input logic clk,
    input logic rst_n,
    input logic ena,
    input logic rw,  // read = 1, write = 0
    output logic ack,
    output logic [2:0] bit_cnt_output
);
    
    // Definindo os estados
    typedef enum logic [2:0] 
    {
        READY = 3'b000,
        START = 3'b001,
        ADR   = 3'b010,
        ACK   = 3'b011,
        READ  = 3'b100,
        WRITE = 3'b101,
        STOP  = 3'b110
    } state_t;

    state_t current_state, next_state;
    logic [2:0] bit_counter

    // Contador de bits
    always_ff @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n)                                               bit_counter <= 3'd0;
        else if (current_state == READ || current_state == WRITE) bit_counter <= bit_counter + 3'd1;
        else                                                      bit_counter <= 3'd0;
    end

    // Logica de transicao de estados
    always_ff @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) current_state <= READY;
        else        current_state <= next_state;
    end

    // Definindo a proxima transicao de estado
    always_comb 
    begin
        next_state = current_state;
        case (current_state)
            READY: 
            begin
                if (~ena) next_state = READY;
                else      next_state = START;
            end
            
            START: 
            begin
                if (~ena) next_state = READY;
                else      next_state = ADR;
            end
            
            ADR: 
            begin
                if (~ena) next_state = READY;
                else      next_state = ACK;
            end
            
            ACK: 
            begin
                if (rw) next_state = READ;
                else    next_state = WRITE;
            end
            
            READ: 
            begin
                if (bit_cnt == 3'd7) next_state = STOP;
            end
            
            WRITE: 
            begin
                if (bit_cnt == 3'd7) next_state = STOP;
            end
            
            STOP: 
            begin
                if(~ena) next_state = READY;
                else     next_state = START;
            end
        endcase
    end

    // Sinal de acknowledge
    always_ff @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n)                    ack <= 1'b0;
        else if (current_state == ACK) ack <= 1'b1;
        else                           ack <= 1'b0;
    end

    assign bit_cnt_output <= bit_counter;

endmodule
