`timescale 1ns / 1ps
`default_nettype none

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Miguel Angel Rodriguez Jodar
// 
// Create Date:    03:34:47 07/25/2015 
// Design Name:    SAM Coup� clone
// Module Name:    ram 
// Project Name:   SAM Coup� clone
// Target Devices: Spartan 6
// Tool versions:  ISE 12.4
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module ram_dual_port_turnos (
    input wire clk,
    input wire whichturn,
    input wire [18:0] vramaddr,
    input wire [18:0] cpuramaddr,
    input wire cpu_we_n,
    input wire [7:0] data_from_cpu,
    output reg [7:0] data_to_asic,
    output reg [7:0] data_to_cpu,
    // Actual interface with SRAM
    output reg [18:0] sram_a,
    output reg sram_we_n,
    inout wire [7:0] sram_d,
    // bootrom
    input wire[7:0] romwrite_data,
    input wire romwrite_wr,
    input wire[18:0] romwrite_addr,
    // rom
    input wire[14:0] romaddr,
    output reg[7:0] data_from_rom,
    input wire rom_oe_n,
    input wire rom_initialised
    );
    
    wire romwrite_wr_safe = romwrite_wr == 1'b1 && rom_initialised == 1'b0;
    assign sram_d = romwrite_wr_safe == 1'b1 ? romwrite_data :
                    (cpu_we_n == 1'b0 && whichturn == 1'b0) ? data_from_cpu :
                    8'hZZ;
                    
    always @* begin
        data_to_cpu = 8'hFF;
        data_to_asic = 8'hFF;
        if (whichturn && rom_initialised) begin // ASIC
            sram_a = vramaddr;
            sram_we_n = 1'b1;
            data_to_asic = sram_d;
        end
        else begin
            sram_a = romwrite_wr_safe ? romwrite_addr :
                     !rom_oe_n ? {4'b1000, romaddr} :
                     cpuramaddr;
            sram_we_n = cpu_we_n && !romwrite_wr_safe;
            data_to_cpu = cpuramaddr[18] ? 8'hFF : sram_d;
            data_from_rom = rom_oe_n ? 8'hFF : sram_d;
        end
    end
endmodule


module ram_dual_port (
    input wire clk,
    input wire whichturn,
    input wire [18:0] vramaddr,
    input wire [18:0] cpuramaddr,
    input wire mreq_n,
    input wire rd_n,
    input wire wr_n,
    input wire rfsh_n,
    input wire [7:0] data_from_cpu,
    output wire [7:0] data_to_asic,
    output reg [7:0] data_to_cpu,
    // Actual interface with SRAM
    output reg [18:0] sram_a,
    output reg sram_we_n,
    inout wire [7:0] sram_d
    );

    parameter ASIC = 3'd0,
              CPU1 = 3'd1,
              CPU2 = 3'd2,
              CPU3 = 3'd3,
              CPU4 = 3'd4,
              CPU5 = 3'd5,
              CPU6 = 3'd6,
              CPU7 = 3'd7;
              
    reg [2:0] state = ASIC;
    
    assign sram_d = (state == CPU5 || state == CPU6)? data_from_cpu : 8'hZZ;
    assign data_to_asic = sram_d;
    
    always @* begin
        if (whichturn == 1'b1) begin
            sram_a = vramaddr;
            sram_we_n = 1'b1;            
        end
        else begin
            sram_a = cpuramaddr;            
            data_to_cpu = sram_d;
            if (state == CPU6 || state == CPU5)
                sram_we_n = 1'b0;
            else
                sram_we_n = 1'b1;
        end
    end
    
    always @(posedge clk) begin
        case (state)
            ASIC:
                begin
                    if (whichturn == 1'b0)
                        state <= CPU1;
                end
            CPU1:
                begin
                    if (whichturn == 1'b1)
                        state <= ASIC;
                    else if (mreq_n == 1'b0 && rd_n == 1'b0)
                        state <= CPU2;
                    else if (mreq_n == 1'b0 && rd_n == 1'b1 && rfsh_n == 1'b1)
                        state <= CPU5;
                end
            CPU2:
                begin
                    if (whichturn == 1'b1)
                        state <= ASIC;
                    else
                        state <= CPU3;
                end
            CPU3:
                begin                    
                    if (whichturn == 1'b1)
                        state <= ASIC;
                    else
                        state <= CPU1;
                end
            CPU5:
                begin
                    if (whichturn == 1'b1)
                        state <= ASIC;
                    else if (mreq_n == 1'b1)
                        state <= CPU1;
                    else if (wr_n == 1'b0)
                        state <= CPU6;
                end
            CPU6:
                begin
                    state <= CPU7;
                end
            CPU7:
                begin
                    if (whichturn == 1'b1)
                        state <= ASIC;
                    else if (mreq_n == 1'b1)
                        state <= CPU1;
                end
            default: 
                begin
                    if (whichturn == 1'b1)
                        state <= ASIC;
                     else
                        state <= CPU1;
                end
        endcase
    end
endmodule
