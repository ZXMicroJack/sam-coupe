`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:42:40 06/01/2015 
// Design Name: 
// Module Name:    scancode_to_speccy 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module scancode_to_sam (
    input wire clk,  // el mismo clk de ps/2
    input wire rst,
    input wire scan_received,
    input wire [7:0] scan,
    input wire extended,
    input wire released,
    input wire kbclean,
    //------------------------
    input wire [8:0] sam_row,
    output wire [7:0] sam_col,
    output wire user_reset,
    output wire master_reset,
    output wire user_nmi,
    output wire [1:0] user_toggles,
    //------------------------
    input wire [7:0] din,
    output reg [7:0] dout,
    input wire cpuwrite,
    input wire cpuread,
    input wire rewind
    );
    
    // las teclas del SAM. Se inicializan a "no pulsadas".
    reg [7:0] row[0:8];
    initial begin
        row[0] = 8'hFF;
        row[1] = 8'hFF;
        row[2] = 8'hFF;
        row[3] = 8'hFF;
        row[4] = 8'hFF;
        row[5] = 8'hFF;
        row[6] = 8'hFF;
        row[7] = 8'hFF;
        row[8] = 8'hFF;
    end
        
    // El gran mapa de teclado y sus registros de acceso
//     reg [7:0] keymap[0:16383];  // 16K x 8 bits
    reg [13:0] addr = 14'h0000;
    reg [13:0] cpuaddr = 14'h0000;  // Dirección E/S desde la CPU. Se autoincrementa en cada acceso
//     initial begin
//         $readmemh ("../keymaps/keyb_es_hex.txt", keymap);
//     end
    
    reg [3:0] keyrow1 = 4'h0;
    reg [7:0] keycol1 = 8'h00;
    reg [3:0] keyrow2 = 4'h0;
    reg [7:0] keycol2 = 8'h00;
    reg [2:0] keymodifiers = 3'b000;
    reg [2:0] signalstate = 3'b000;
    reg [1:0] togglestate = 2'b00;

    reg rmaster_reset = 1'b0, ruser_reset = 1'b0, ruser_nmi = 1'b0;
    reg [1:0] ruser_toggles = 2'b00;
    assign master_reset = rmaster_reset;
    assign user_reset = ruser_reset;
    assign user_nmi = ruser_nmi;
    assign user_toggles = ruser_toggles;
    
    // Asi funciona la matriz de teclado cuando se piden semifilas
    // desde la CPU.
    // Un always @* hubiera quedado más claro en la descripción
    // pero por algun motivo, el XST no lo ha admitido en este caso
    assign sam_col = ((sam_row[0] == 1'b0)? row[0] : 8'hFF) &
                     ((sam_row[1] == 1'b0)? row[1] : 8'hFF) &
                     ((sam_row[2] == 1'b0)? row[2] : 8'hFF) &
                     ((sam_row[3] == 1'b0)? row[3] : 8'hFF) &
                     ((sam_row[4] == 1'b0)? row[4] : 8'hFF) &
                     ((sam_row[5] == 1'b0)? row[5] : 8'hFF) &
                     ((sam_row[6] == 1'b0)? row[6] : 8'hFF) &
                     ((sam_row[7] == 1'b0)? row[7] : 8'hFF) &
                     ((sam_row[8] == 1'b0)? row[8] : 8'hFF);
                    
    reg [2:0] modifiers = 3'b000;
    reg [3:0] keycount = 4'b0000;
        
    parameter 
        CLEANMATRIX = 4'd0, 
        IDLE        = 4'd1, 
        ADDR0PUT    = 4'd2, 
        ADDR1PUT    = 4'd3, 
        ADDR2PUT    = 4'd4, 
        ADDR3PUT    = 4'd5,
        TRANSLATE1  = 4'd6,
        TRANSLATE2  = 4'd7,
        TRANSLATE3  = 4'd8,
        CPUTIME     = 4'd9,
        CPUREAD     = 4'd10,
        CPUWRITE    = 4'd11,
        CPUINCADD   = 4'd12,
        UPDCOUNTERS1= 4'd13,
        UPDCOUNTERS2= 4'd14;
        
    reg [3:0] state = CLEANMATRIX;
    reg key_is_pending = 1'b0;
    wire[7:0] keymap_data;
    
    keymap keymap_inst(.addr(addr), .data(keymap_data));
    
    always @(posedge clk) begin
        if (scan_received == 1'b1)
            key_is_pending <= 1'b1;
        if (rst == 1'b1 || (kbclean == 1'b1 && state == IDLE && scan_received == 1'b0))
            state <= CLEANMATRIX;
        else begin
            case (state)
                CLEANMATRIX: begin
                    modifiers <= 3'b000;
                    keycount <= 4'b0000;
                    row[0] <= 8'hFF;
                    row[1] <= 8'hFF;
                    row[2] <= 8'hFF;
                    row[3] <= 8'hFF;
                    row[4] <= 8'hFF;
                    row[5] <= 8'hFF;
                    row[6] <= 8'hFF;
                    row[7] <= 8'hFF;
                    row[8] <= 8'hFF;
                    state <= IDLE;
                end
                IDLE: begin
                    if (key_is_pending == 1'b1) begin
                        addr <= {modifiers, extended, scan, 2'b00};  // 1 scan tiene 8 bits + 1 bit para indicar scan extendido + 3 bits para el modificador usado
                        state <= ADDR0PUT;
                        key_is_pending <= 1'b0;
                    end
                    else if (cpuread == 1'b1 || cpuwrite == 1'b1 || rewind == 1'b1)
                        state <= CPUTIME;
                end
                ADDR0PUT: begin
//                     {keyrow1,keycol1[7:4]} <= keymap[addr];
                    {keyrow1,keycol1[7:4]} <= keymap_data;
                    addr <= {modifiers, extended, scan, 2'b01};
                    state <= ADDR1PUT;
                end
                ADDR1PUT: begin
//                     {keycol1[3:0],keyrow2} <= keymap[addr];
                    {keycol1[3:0],keyrow2} <= keymap_data;
                    addr <= {modifiers, extended, scan, 2'b10};
                    state <= ADDR2PUT;
                end
                ADDR2PUT: begin
//                     {keycol2} <= keymap[addr];
                    {keycol2} <= keymap_data;
                    addr <= {modifiers, extended, scan, 2'b11};
                    state <= ADDR3PUT;
                end
                ADDR3PUT: begin
//                     {signalstate,keymodifiers,togglestate} <= keymap[addr];
                    {signalstate,keymodifiers,togglestate} <= keymap_data;
                    state <= TRANSLATE1;
                end
                TRANSLATE1: begin
                    // Actualiza las 8 semifilas del teclado con la primera tecla
                    if (~released) begin            
                      if (keyrow1[3] == 1'b1)
                        row[8] <= row[8] & ~keycol1;
                      else
                        row[keyrow1[2:0]] <= row[keyrow1[2:0]] & ~keycol1;
                    end
                    else begin
                      if (keyrow1[3] == 1'b1)
                        row[8] <= row[8] | keycol1;
                      else
                        row[keyrow1[2:0]] <= row[keyrow1[2:0]] | keycol1;
                    end
                    state <= TRANSLATE2;
                end
                TRANSLATE2: begin
                    // Actualiza las 8 semifilas del teclado con la segunda tecla
                    if (~released) begin            
                      if (keyrow2[3] == 1'b1)
                        row[8] <= row[8] & ~keycol2;
                      else
                        row[keyrow2[2:0]] <= row[keyrow2[2:0]] & ~keycol2;
                    end
                    else begin
                      if (keyrow2[3] == 1'b1)
                        row[8] <= row[8] | keycol2;
                      else
                        row[keyrow2[2:0]] <= row[keyrow2[2:0]] | keycol2;
                    end
                    state <= TRANSLATE3;
                end
                TRANSLATE3: begin
                    // Actualiza modificadores
                    if (~released)
                        modifiers <= modifiers | keymodifiers;
                    else
                        modifiers <= modifiers & ~keymodifiers;
                        
                    // Y de la misma forma tendria que actualizar resets y los user_toogles
                    if (~released)
                        {rmaster_reset,ruser_reset,ruser_nmi} <= {rmaster_reset,ruser_reset,ruser_nmi} | signalstate;
                    else
                        {rmaster_reset,ruser_reset,ruser_nmi} <= {rmaster_reset,ruser_reset,ruser_nmi} & ~signalstate;
                        
                    if (~released)
                        ruser_toggles <= ruser_toggles | togglestate;
                    else
                        ruser_toggles <= ruser_toggles & ~togglestate;
                                    
                    //state <= UPDCOUNTERS1;
                    state <= IDLE;
                end
                CPUTIME: begin            
                    if (rewind == 1'b1) begin
                        cpuaddr <= 14'h0000;
                        state <= IDLE;
                    end
                    else if (cpuread == 1'b1) begin
                        addr <= cpuaddr;
                        state <= CPUREAD;
                    end
                    else if (cpuwrite == 1'b1) begin
                        addr <= cpuaddr;
                        state <= CPUWRITE;
                    end
                    else
                        state <= IDLE;
                end
                CPUREAD: begin   // CPU wants to read from keymap
//                     dout <= keymap[addr];
                    dout <= keymap_data;
                    state <= CPUINCADD;
                end
                CPUWRITE: begin
//                     keymap[addr] <= din;
                    state <= CPUINCADD;
                end
                CPUINCADD: begin
                    if (cpuread == 1'b0 && cpuwrite == 1'b0) begin
                        cpuaddr <= cpuaddr + 1;
                        state <= IDLE;
                    end
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

module keyboard_pressed_status (
    input wire clk,
    input wire rst,
    input wire scan_received,
    input wire [7:0] scancode,
    input wire extended,
    input wire released,
    output reg kbclean
    );
    
    parameter
        RESETTING = 2'd0,
        UPDATING  = 2'd1,
        SCANNING  = 2'd2;
        
    reg keybstat_ne[0:255];  // non extended keymap
    reg keybstat_ex[0:255];  // extended keymap
    reg [7:0] addrscan = 8'h00; // keymap bit address
    reg keypressed_ne = 1'b0; // there is at least one key pressed
    reg keypressed_ex = 1'b0; // there is at least one extended key pressed
    reg [1:0] state = RESETTING;
    
    integer i;
    initial begin
        kbclean = 1'b1;
        for (i=0;i<256;i=i+1) begin
            keybstat_ne[i] = 1'b0;
            keybstat_ex[i] = 1'b0;
        end
    end
    
    always @(posedge clk) begin
        if (rst == 1'b1) begin
            state <= RESETTING;
            addrscan <= 8'h00;
        end
        else begin
            case (state)
                RESETTING:
                    begin
                        if (addrscan == 8'hFF) begin
                            addrscan <= 8'h00;
                            state <= SCANNING;
                            kbclean <= 1'b1;
                        end
                        else begin
                            keybstat_ne[addrscan] <= 1'b0;
                            keybstat_ex[addrscan] <= 1'b0;
                            addrscan <= addrscan + 8'd1;
                        end
                    end
                UPDATING:
                    begin
                        state <= SCANNING;
                        addrscan <= 8'h00;
                        kbclean <= 1'b0;
                        keypressed_ne <= 1'b0;
                        keypressed_ex <= 1'b0;
                        if (extended == 1'b0)
                            keybstat_ne[scancode] <= ~released;
                        else
                            keybstat_ex[scancode] <= ~released;
                    end
                SCANNING:
                    begin
                        if (scan_received == 1'b1)
                            state <= UPDATING;
                        addrscan <= addrscan + 8'd1;
                        if (addrscan == 8'hFF) begin
                            kbclean <= ~(keypressed_ne | keypressed_ex);
                            keypressed_ne <= 1'b0;
                            keypressed_ex <= 1'b0;
                        end
                        else begin
                            keypressed_ne <= keypressed_ne | keybstat_ne[addrscan];
                            keypressed_ex <= keypressed_ex | keybstat_ex[addrscan];
                        end
                    end
            endcase
        end
    end
endmodule

module scancode_to_sam2 (
    input wire clk,  // el mismo clk de ps/2
    input wire rst,
    input wire scan_received,
    input wire [7:0] scan,
    input wire extended,
    input wire released,
    input wire kbclean,
    //------------------------
    input wire [8:0] sam_row,
    output wire [7:0] sam_col,
    output wire user_reset,
    output wire master_reset,
    output wire user_nmi,
    output wire [1:0] user_toggles,
    //------------------------
    input wire [7:0] din,
    output reg [7:0] dout,
    input wire cpuwrite,
    input wire cpuread,
    input wire rewind
    );
    
    reg[7:0] row[0:8];
    
//     assign sam_col[7:0] = 
//       ((sam_row[0] == 1'b0) ? (~row[0]) : 8'hff) &
//       ((sam_row[1] == 1'b0) ? (~row[1]) : 8'hff) &
//       ((sam_row[2] == 1'b0) ? (~row[2]) : 8'hff) &
//       ((sam_row[3] == 1'b0) ? (~row[3]) : 8'hff) &
//       ((sam_row[4] == 1'b0) ? (~row[4]) : 8'hff) &
//       ((sam_row[5] == 1'b0) ? (~row[5]) : 8'hff) &
//       ((sam_row[6] == 1'b0) ? (~row[6]) : 8'hff) &
//       ((sam_row[7] == 1'b0) ? (~row[7]) : 8'hff) &
//       ((sam_row[8] == 1'b0) ? (~row[8]) : 8'hff);
//       ;

    assign sam_col[7:0] = 8'hff ^ (
      ((sam_row[0] == 1'b0) ? row[0] : 8'h00) |
      ((sam_row[1] == 1'b0) ? row[1] : 8'h00) |
      ((sam_row[2] == 1'b0) ? row[2] : 8'h00) |
      ((sam_row[3] == 1'b0) ? row[3] : 8'h00) |
      ((sam_row[4] == 1'b0) ? row[4] : 8'h00) |
      ((sam_row[5] == 1'b0) ? row[5] : 8'h00) |
      ((sam_row[6] == 1'b0) ? row[6] : 8'h00) |
      ((sam_row[7] == 1'b0) ? row[7] : 8'h00) |
      ((sam_row[8] == 1'b0) ? row[8] : 8'h00));

    reg kextended = 1'b0;
    reg kreleased = 1'b0;
    always @(posedge scan_received) begin
      if (scan == 8'hf0) kreleased <= 1'b1;
      else if (scan == 8'he0) kextended <= 1'b1;
      else begin
        case ({kextended, scan})
//           9'h1f0: {kextended, kreleased} <= 2'b11;
//           9'h0f0: {kextended, kreleased} <= 2'b01;
//           9'h0e0: {kextended, kreleased} <= 2'b10;
//           
          //cs   z  x  c  v  f1  f2  f3
          // a   s  d  f  g  f4  f5  f6
          // q   w  e  r  t  f7  f8  f9
          // 1   2  3  4  5  esc tab caps
          // 0   9  8  7  6  -   +   del
          // p   o  i  u  y  =   ~   f0
          // ent l  k  j  h  ;   :   edit
          // src ss m  n  b  ,   .   inv
          // ctl up dn lt rt
          
          //cs   z  x  c  v  f1  f2  f3
          8'h12: row[0][0] <= ! kreleased;
          8'h59: row[0][0] <= ! kreleased;

          8'h1a: row[0][1] <= ! kreleased;
          8'h22: row[0][2] <= ! kreleased;
          8'h21: row[0][3] <= ! kreleased;
          8'h2a: row[0][4] <= ! kreleased;
          8'h69: row[0][5] <= ! kreleased;
          8'h72: row[0][6] <= ! kreleased;
          8'h7a: row[0][7] <= ! kreleased;

          // a   s  d  f  g  f4  f5  f6
          8'h1c: row[1][0] <= ! kreleased;
          8'h1b: row[1][1] <= ! kreleased;
          8'h23: row[1][2] <= ! kreleased;
          8'h2b: row[1][3] <= ! kreleased;
          8'h34: row[1][4] <= ! kreleased;
          8'h6b: row[1][5] <= ! kreleased;
          8'h73: row[1][6] <= ! kreleased;
          8'h74: row[1][7] <= ! kreleased;

          // q   w  e  r  t  f7  f8  f9
          8'h15: row[2][0] <= ! kreleased;
          8'h1d: row[2][1] <= ! kreleased;
          8'h24: row[2][2] <= ! kreleased;
          8'h2d: row[2][3] <= ! kreleased;
          8'h2c: row[2][4] <= ! kreleased;
          8'h6c: row[2][5] <= ! kreleased;
          8'h75: row[2][6] <= ! kreleased;
          8'h7d: row[2][7] <= ! kreleased;

          // 1   2  3  4  5  esc tab caps
          8'h16: row[3][0] <= ! kreleased;
          8'h1e: row[3][1] <= ! kreleased;
          8'h26: row[3][2] <= ! kreleased;
          8'h25: row[3][3] <= ! kreleased;
          8'h2e: row[3][4] <= ! kreleased;
          8'h76: row[3][5] <= ! kreleased;
          8'h0d: row[3][6] <= ! kreleased;
          8'h58: row[3][7] <= ! kreleased;

          // 0   9  8  7  6  -   +   del
          8'h45: row[4][0] <= ! kreleased;
          8'h46: row[4][1] <= ! kreleased;
          8'h3e: row[4][2] <= ! kreleased;
          8'h3d: row[4][3] <= ! kreleased;
          8'h36: row[4][4] <= ! kreleased;
          8'h4e: row[4][5] <= ! kreleased;
          8'h55: row[4][6] <= ! kreleased;
          8'h66: row[4][7] <= ! kreleased;
          
          // p   o  i  u  y  =   ~   f0
          8'h4d: row[5][0] <= ! kreleased;
          8'h44: row[5][1] <= ! kreleased;
          8'h43: row[5][2] <= ! kreleased;
          8'h3c: row[5][3] <= ! kreleased;
          8'h35: row[5][4] <= ! kreleased;
          8'h5d: row[5][5] <= ! kreleased;
          8'h0e: row[5][6] <= ! kreleased;
          8'h70: row[5][7] <= ! kreleased;
          
          // ent l  k  j  h  ;   :   edit
          8'h5a: row[6][0] <= ! kreleased;
          8'h4b: row[6][1] <= ! kreleased;
          8'h42: row[6][2] <= ! kreleased;
          8'h3b: row[6][3] <= ! kreleased;
          8'h33: row[6][4] <= ! kreleased;
          8'h4c: row[6][5] <= ! kreleased;
          8'h52: row[6][6] <= ! kreleased;
          9'h111: row[6][7] <= ! kreleased;
          
          // src ss m  n  b  ,   .   inv
          8'h29: row[7][0] <= ! kreleased;
          8'h11: row[7][1] <= ! kreleased;
          8'h3a: row[7][2] <= ! kreleased;
          8'h31: row[7][3] <= ! kreleased;
          8'h32: row[7][4] <= ! kreleased;
          8'h41: row[7][5] <= ! kreleased;
          8'h49: row[7][6] <= ! kreleased;
          8'h4a: row[7][7] <= ! kreleased;

          // ctl up dn lt rt
          8'h14: row[8][0] <= ! kreleased;
          9'h175: row[8][1] <= ! kreleased;
          9'h172: row[8][2] <= ! kreleased;
          9'h16b: row[8][3] <= ! kreleased;
          9'h174: row[8][4] <= ! kreleased;
        endcase
        kextended <= 1'b0;
        kreleased <= 1'b0;
      end
    end
    
endmodule

    
module scancode_to_sam3 (
    input wire scan_received,
    input wire [7:0] scan,
    //------------------------
    input wire [8:0] sam_row,
    output wire [7:0] sam_col,
    output wire user_reset,
    output wire master_reset,
    output wire user_nmi
    );
    
    assign user_reset = 1'b1;
    assign master_reset = 1'b1;
    assign user_nmi = 1'b1;
    
    reg[7:0] row[0:8];
    
    assign sam_col[7:0] = 8'hff ^ (
      ((sam_row[0] == 1'b0) ? row[0] : 8'h00) |
      ((sam_row[1] == 1'b0) ? row[1] : 8'h00) |
      ((sam_row[2] == 1'b0) ? row[2] : 8'h00) |
      ((sam_row[3] == 1'b0) ? row[3] : 8'h00) |
      ((sam_row[4] == 1'b0) ? row[4] : 8'h00) |
      ((sam_row[5] == 1'b0) ? row[5] : 8'h00) |
      ((sam_row[6] == 1'b0) ? row[6] : 8'h00) |
      ((sam_row[7] == 1'b0) ? row[7] : 8'h00) |
      ((sam_row[8] == 1'b0) ? row[8] : 8'h00));

    reg kextended = 1'b0;
    reg kreleased = 1'b0;
    always @(posedge scan_received) begin
      if (scan == 8'hf0) kreleased <= 1'b1;
      else if (scan == 8'he0) kextended <= 1'b1;
      else begin
        case ({kextended, scan})
//           9'h1f0: {kextended, kreleased} <= 2'b11;
//           9'h0f0: {kextended, kreleased} <= 2'b01;
//           9'h0e0: {kextended, kreleased} <= 2'b10;
//           
          //cs   z  x  c  v  f1  f2  f3
          // a   s  d  f  g  f4  f5  f6
          // q   w  e  r  t  f7  f8  f9
          // 1   2  3  4  5  esc tab caps
          // 0   9  8  7  6  -   +   del
          // p   o  i  u  y  =   ~   f0
          // ent l  k  j  h  ;   :   edit
          // src ss m  n  b  ,   .   inv
          // ctl up dn lt rt
          
          //cs   z  x  c  v  f1  f2  f3
          8'h12: row[0][0] <= ! kreleased;
          8'h59: row[0][0] <= ! kreleased;

          8'h1a: row[0][1] <= ! kreleased;
          8'h22: row[0][2] <= ! kreleased;
          8'h21: row[0][3] <= ! kreleased;
          8'h2a: row[0][4] <= ! kreleased;
          8'h69: row[0][5] <= ! kreleased;
          8'h72: row[0][6] <= ! kreleased;
          8'h7a: row[0][7] <= ! kreleased;

          // a   s  d  f  g  f4  f5  f6
          8'h1c: row[1][0] <= ! kreleased;
          8'h1b: row[1][1] <= ! kreleased;
          8'h23: row[1][2] <= ! kreleased;
          8'h2b: row[1][3] <= ! kreleased;
          8'h34: row[1][4] <= ! kreleased;
          8'h6b: row[1][5] <= ! kreleased;
          8'h73: row[1][6] <= ! kreleased;
          8'h74: row[1][7] <= ! kreleased;

          // q   w  e  r  t  f7  f8  f9
          8'h15: row[2][0] <= ! kreleased;
          8'h1d: row[2][1] <= ! kreleased;
          8'h24: row[2][2] <= ! kreleased;
          8'h2d: row[2][3] <= ! kreleased;
          8'h2c: row[2][4] <= ! kreleased;
          8'h6c: row[2][5] <= ! kreleased;
          8'h75: row[2][6] <= ! kreleased;
          8'h7d: row[2][7] <= ! kreleased;

          // 1   2  3  4  5  esc tab caps
          8'h16: row[3][0] <= ! kreleased;
          8'h1e: row[3][1] <= ! kreleased;
          8'h26: row[3][2] <= ! kreleased;
          8'h25: row[3][3] <= ! kreleased;
          8'h2e: row[3][4] <= ! kreleased;
          8'h76: row[3][5] <= ! kreleased;
          8'h0d: row[3][6] <= ! kreleased;
          8'h58: row[3][7] <= ! kreleased;

          // 0   9  8  7  6  -   +   del
          8'h45: row[4][0] <= ! kreleased;
          8'h46: row[4][1] <= ! kreleased;
          8'h3e: row[4][2] <= ! kreleased;
          8'h3d: row[4][3] <= ! kreleased;
          8'h36: row[4][4] <= ! kreleased;
          8'h4e: row[4][5] <= ! kreleased;
          8'h55: row[4][6] <= ! kreleased;
          8'h66: row[4][7] <= ! kreleased;
          
          // p   o  i  u  y  =   ~   f0
          8'h4d: row[5][0] <= ! kreleased;
          8'h44: row[5][1] <= ! kreleased;
          8'h43: row[5][2] <= ! kreleased;
          8'h3c: row[5][3] <= ! kreleased;
          8'h35: row[5][4] <= ! kreleased;
          8'h5d: row[5][5] <= ! kreleased;
          8'h0e: row[5][6] <= ! kreleased;
          8'h70: row[5][7] <= ! kreleased;
          
          // ent l  k  j  h  ;   :   edit
          8'h5a: row[6][0] <= ! kreleased;
          8'h4b: row[6][1] <= ! kreleased;
          8'h42: row[6][2] <= ! kreleased;
          8'h3b: row[6][3] <= ! kreleased;
          8'h33: row[6][4] <= ! kreleased;
          8'h4c: row[6][5] <= ! kreleased;
          8'h52: row[6][6] <= ! kreleased;
          9'h111: row[6][7] <= ! kreleased;
          
          // src ss m  n  b  ,   .   inv
          8'h29: row[7][0] <= ! kreleased;
          8'h11: row[7][1] <= ! kreleased;
          8'h3a: row[7][2] <= ! kreleased;
          8'h31: row[7][3] <= ! kreleased;
          8'h32: row[7][4] <= ! kreleased;
          8'h41: row[7][5] <= ! kreleased;
          8'h49: row[7][6] <= ! kreleased;
          8'h4a: row[7][7] <= ! kreleased;

          // ctl up dn lt rt
          8'h14: row[8][0] <= ! kreleased;
          9'h175: row[8][1] <= ! kreleased;
          9'h172: row[8][2] <= ! kreleased;
          9'h16b: row[8][3] <= ! kreleased;
          9'h174: row[8][4] <= ! kreleased;
        endcase
        kextended <= 1'b0;
        kreleased <= 1'b0;
      end
    end
    
endmodule

    
