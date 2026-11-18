`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/10/2026 08:40:46 PM
// Design Name: 
// Module Name: uart_software_interface_sim
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


module uart_software_interface_sim( );
    reg  clk;
    reg  rst;
    reg  tx_command;
    reg  [7:0]tx_data;
    reg  read_command;
    wire [7:0]fifo_data;
    wire fifo_empty;
    wire fifo_full;
    wire tx_busy;
    wire tx_done;
    wire rx_error;
    
    integer i,j,k,l,m;
    reg [7:0] y [6:0];

    uart_software_interface uart_comp(
            .clk(clk),
            .rst(rst),
            .tx_command(tx_command),
            .tx_data(tx_data),
            .tx_busy(tx_busy),
            .tx_done(tx_done),
            .read_command(read_command),
            .fifo_data(fifo_data),
            .fifo_empty(fifo_empty),
            .fifo_full(fifo_full),
            .rx_error(rx_error)
    );

// Generate a clock that should be driven to design
// This clock will flip its value every 5ns -> time period = 10ns -> freq = 100 MHz
    always #5 clk = ~clk;
    
    // error monitor
    always @ (posedge clk) begin
        if (!rst)
            if (rx_error !== 1'b0)
                $fatal(1, "ERROR: read error");
     end

    // This initial block sets an exit condition if stuck
    initial begin
        #10_000_000;
        $fatal(1, "TIMEOUT: UART loopback test did not finish within 10 ms.");
    end

// This initial block forms the stimulus of the testbench
    initial begin
// 1. Initialize testbench variables to 0 at start of simulation
    clk            <= 0;
    tx_command     <= 0;
    read_command   <= 0;
    tx_data        <= 8'h30;  // '0'
    
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
        tx_command <= 1;
        for (l = 0; l < 5; l = l + 1)
        begin
            @(negedge clk);
        end
        tx_command <= 0;
        
        wait(tx_done);
        #100;
    end
    
    if (fifo_empty !== 0 || fifo_full !== 0)
            $fatal(1, "ERROR");
    
    // 3. trigger to start reading data   
    for (k = 0; k < 7; k = k + 1) begin
        if (fifo_empty !== 0)
            $fatal(1, "ERROR: no bytes to read");
        
        @(negedge clk);
        read_command <=1;
        for (m = 0; m < 5; m = m + 1)
        begin
            @(negedge clk);
        end
        read_command <=0;
        
        if (fifo_data !== y[k])
            $fatal(1, "ERROR: expected=%02h, actual=%02h", y[k], fifo_data);    
        else 
            $display("byte: number=%0d data=%02h",k+1,fifo_data);        
            
        #10000;
    end
    
    if (fifo_empty !== 1'b1)
        $fatal(1, "ERROR: there are still bytes left");
    else
       $display("no more bytes to read");  
       
    #300 $finish;
end endmodule
