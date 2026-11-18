`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/10/2026 07:23:38 PM
// Design Name: 
// Module Name: command_pulse_sim
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module command_pulse_sim( );
    reg  clk;
    reg  rst;
    reg  command;
    wire pulse;
    
    integer i,j;
    
    command_pulse cp(
        .clk(clk),
        .rst(rst),
        .command(command),
        .pulse(pulse)
    );
    
    // Generate a clock that should be driven to design
    // This clock will flip its value every 5ns -> time period = 10ns -> freq = 100 MHz
    always #5 clk = ~clk;
    
    
    initial begin
        clk     <= 0;
        rst     <= 1;
        command <= 0;
        
        // hold reset for 3 clock cycles
        for (i = 0; i < 3; i = i + 1) 
        begin
            @(negedge clk);
        end
        
        rst     <= 0;
        command <= 1;
        
        // hold command high for several cycles
        for (j = 0; j < 3; j = j + 1)
        begin
            @(negedge clk);
        end
    
        // Hold low for at least one rising clock edge
        command <= 0;
        @(negedge clk);
        
        // Raise it again
        command <= 1;
        @(negedge clk);

        #100 $finish;
    end
endmodule
