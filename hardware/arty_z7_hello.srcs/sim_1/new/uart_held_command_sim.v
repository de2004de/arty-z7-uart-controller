`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/11/2026 09:02:36 AM
// Design Name: 
// Module Name: uart_held_command_sim
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


module uart_held_command_sim( );

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
    wire tx_complete;
    wire read_complete;
    
    integer j,l,m;
    reg [7:0] y [0:0];

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
            .rx_error(rx_error),
            .tx_complete(tx_complete),
            .read_complete(read_complete)
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
    
    y[0] = 8'h55;  // 'U'

    
    // reset for a few clock cycles
    rst      <= 1;
    for (j = 0; j < 3; j = j + 1) begin
        @(negedge clk);
    end
    rst <= 0;


    // 2. trigger to start sending data
    tx_data <= y[0];
        
    @(negedge clk);
    tx_command <= 1;
        
    wait(tx_complete === 1'b1);
    
    for (l = 0; l < 200_000; l = l + 1)
        begin
            @(negedge clk);
            
            if (tx_busy !== 0)
                $fatal(1, "ERROR: tx_busy is 1");
                
            if (tx_complete !== 1'b1)
                $fatal(1, "ERROR: tx_complete is 0");
        end
        
    tx_command <= 0;
    @(negedge clk);
    if (tx_complete !== 1'b0) 
        $fatal(1, "ERROR: tx_complete is 1");
    
    if (fifo_empty !== 0 || fifo_full !== 0)
            $fatal(1, "ERROR");
    
    // 3. trigger to start reading data   
    @(negedge clk);
    read_command <=1;
    wait(read_complete);
        
    if (fifo_data !== y[0])
        $fatal(1, "ERROR: expected=%02h, actual=%02h", y[0], fifo_data);    
    else 
        $display("byte: number=%0d data=%02h",1,fifo_data);        
            
    for (m = 0; m < 5; m = m + 1)
    begin
        @(negedge clk);
        
        if (read_complete !== 1)
            $fatal(1, "ERROR: read_complete is 0");
    end
    
    read_command <=0;
    @(negedge clk);
    if (read_complete === 1'b0)
        $display("read_complete is cleared");
    else 
        $fatal(1, "ERROR: read_complete did not clear");
        
    #10000;
    
    if (fifo_empty !== 1'b1)
        $fatal(1, "ERROR: there are still bytes left");
    else
       $display("no more bytes to read");  
       
    #300 $finish;
end endmodule
