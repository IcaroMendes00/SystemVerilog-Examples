// I2C SystemVerilog module
// 8bits IO
// *************************************************************************
// Existem duas maneiras de criar um escravo I2C em um FPGA ou CPLD.
// Usando diretamente a linha SCL como um sinal de clock dentro do seu FPGA/CPLD
// Usando um clock rápido para sobreamostrar os sinais SDA e SCL
// A primeira forma permite criar um design compacto. Mas não é tão confiável quanto a segunda forma.

// Exemplo de escravo I2C: extensor IO, usando a forma 2 (SCL como um relógio no FPGA/CPLD)
// O módulo escravo I2C é conectado a uma pequena memória de 8 bits 
// que pode ser lida e escrita do barramento I2C. Os 8 bits também 
// são exportados para fora do FPGA/CPLD. Isso cria um extensor I2C IO.
// *************************************************************************

// source from: https://www.fpga4fun.com/I2C.html

module I2C_SLAVE
(
    inout        SDA,
    input        SCL,
    output [7:0] IOout
);

    parameter I2C_ADR = 7'h27; // o endereço de 7 bits que queremos para nosso escravo I2C.

    // Então a logica de deteccao das condicoes de inicio e parada.
    // Essa e a parte "magica negra" deste design...
    // Usamos dois fios com um loop combinatorio para detectar as condicoes de inicio e parada
    // garantindo que esses dois fios nao sejam otimizados
    wire SDA_shadow;    /* synthesis keep = 1 */
    wire start_or_stop; /* synthesis keep = 1 */
    assign SDA_shadow = (~SCL | start_or_stop) ? SDA : SDA_shadow;
    assign start_or_stop = ~SCL ? 1'b0 : (SDA ^ SDA_shadow);

    logic incycle;

    always @(negedge SCL or posedge start_or_stop) 
    begin
        if(start_or_stop) incycle <= 1'b0;
        else if (~SDA)    incycle <= 1'b1;
    end

    // Now we are ready to count the I2C bits coming in...
    logic [3:0] bit_counter;          //conta os bits I2C de 7 a 0, mais um bit ACK
    wire  bit_DATA = ~bit_counter[3]; // os bits DATA são os primeiros 8 bits enviados
    wire  bit_ACK  =  bit_counter[3]; // o bit ACK é o 9º bit enviado
    logic data_PHASE;

    always @(negedge SCL or negedge incycle)
    begin
        if(~incycle) 
        begin
            bit_counter <= 4'h7; // o bit 7 eh o primeiro a chegar
            data_PHASE  <=    0;
        end
        else
        begin
            if(bit_ACK)
            begin
                bit_counter <= 4'h7;
                data_PHASE  <=    1;
            end
            else bit_counter <= bit_counter - 4'h1;
        end
    end

    // and detect if the I2C address matches our own...
    wire adr_PHASE = ~data_PHASE;
    logic adr_MATCH, op_READ, got_ACK;
    // exemplo SDA em posedge, já que a especificação I2C especifica um tempo de espera tão baixo quanto 0µs em negedge
    logic SDAr; 
    always @(posedge SCL)
    begin
        SDAr <= SDA;
    end

    logic [7:0] mem;
    wire op_WRITE = ~op_READ;

    always @(negedge SCL or negedge incycle)
    begin
        if(~incycle)
        begin
            got_ACK   <= 0;
            adr_MATCH <= 1;
            op_READ   <= 0;
        end
        else
        begin
            if(adr_PHASE & bit_counter == 7 & SDAr != I2C_ADR[6]) adr_MATCH <= 0;
            if(adr_PHASE & bit_counter == 6 & SDAr != I2C_ADR[5]) adr_MATCH <= 0;
            if(adr_PHASE & bit_counter == 5 & SDAr != I2C_ADR[4]) adr_MATCH <= 0;
            if(adr_PHASE & bit_counter == 4 & SDAr != I2C_ADR[3]) adr_MATCH <= 0;
            if(adr_PHASE & bit_counter == 3 & SDAr != I2C_ADR[2]) adr_MATCH <= 0;
            if(adr_PHASE & bit_counter == 2 & SDAr != I2C_ADR[1]) adr_MATCH <= 0;
            if(adr_PHASE & bit_counter == 1 & SDAr != I2C_ADR[0]) adr_MATCH <= 0;
            if(adr_PHASE & bit_counter == 0) op_READ <= SDAr;
            // monitoramos o ACK para poder liberar o barramento quando o mestre não faz o ACK durante uma operação de leitura            
            if(bit_ACK) got_ACK <= ~SDAr;
            if(adr_MATCH & bit_DATA & data_PHASE & op_WRITE) mem[bit_counter] <= SDAr; // escrita na memoria
        end
    end

    // e conduzir a linha SDA quando necessário...
    wire mem_bit_low = ~mem[bit_counter[2:0]];
    wire SDA_assert_low = adr_MATCH & bit_DATA & data_PHASE & op_READ & mem_bit_low & got_ACK;
    wire SDA_assert_ACK = adr_MATCH & bit_ACK & (adr_PHASE | op_WRITE);
    wire SDA_low = SDA_assert_low | SDA_assert_ACK;
    
    assign SDA = SDA_low ? 1'b0 : 1'bz;
    assign IOout = mem;
    
endmodule