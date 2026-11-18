`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/05/2026 04:49:13 PM
// Design Name: 
// Module Name: uart sim
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

module uart_sim( );
    reg  clk;
    reg  rst;
    reg  tx_start;
    reg  [7:0]tx_data;
    wire tx_busy;
    wire tx_done;
    wire [7:0]rx_data;
    wire rx_done;
    wire rx_error;
    
    integer i,j;
    reg [7:0] y [6:0];

    uart_loopback_core uart_comp(
            .clk(clk),
            .rst(rst),
            .tx_start(tx_start),
            .tx_data(tx_data),
            .tx_busy(tx_busy),
            .tx_done(tx_done),
            .rx_data(rx_data),
            .rx_done(rx_done),
            .rx_error(rx_error)
    );

// Generate a clock that should be driven to design
// This clock will flip its value every 5ns -> time period = 10ns -> freq = 100 MHz
    always #5 clk = ~clk;

// This initial block sets an exit condition if stuck
initial begin
    #10_000_000;
    $fatal(1, "TIMEOUT: UART loopback test did not finish within 10 ms.");
end

// This initial block forms the stimulus of the testbench
    initial begin
// 1. Initialize testbench variables to 0 at start of simulation
    clk      <= 0;
    tx_start <= 0;
    tx_data  <= 8'h30;  // '0'
    
    y[0] = 8'h20;  // space
    y[1] = 8'hFF;
    y[2] = 8'h33;  // '3'
    y[3] = 8'h55;  // 'U'
    y[4] = 8'hAA;
    y[5] = 8'h80;
    y[6] = 8'h01;  // SOH
    
// reset for a few clock cycles
    rst      <= 1;
    for (j = 0; j < 3; j = j + 1) begin
        @(negedge clk);
    end
    rst <= 0;

// 2. trigger to start sending data
    for (i = 0; i < 7; i = i + 1) begin
        tx_data <= y[i];
        
        @(negedge clk);
        tx_start <= 1;
        @(negedge clk);
        tx_start <= 0;
        
        wait(rx_done);
        if (y[i] !== rx_data)
            $fatal(1, "ERROR: expected=%02h, actual=%02h", y[i], rx_data);
        else 
            $display("PASSED: TEST=%0d",i+1);
        
        wait(tx_done);
        #100;
    end
       
    #300 $finish;
end endmodule
