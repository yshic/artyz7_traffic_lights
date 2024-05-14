`timescale 1ns/1ps

module traffic_light_tb;

    reg clk;
    reg rst;
    reg sw0;
    reg sw1;
    reg [2:0] btn;
    wire [6:0] seg1;
    wire [6:0] seg2;
    wire [2:0] led1;
    wire [2:0] led2;

    // instantiate traffic_light module
    traffic_light uut (
        .clk(clk),
        .rst(rst),
        .sw0(sw0),
        .sw1(sw1),
        .btn(btn),
        .seg1(seg1),
        .seg2(seg2),
        .led1(led1),
        .led2(led2)
    );

    // generate clock signal
    always begin
        #5 clk = ~clk;
    end
    
    initial begin
        $monitor("Time: %0t, switch0: %b, switch1: %b, btn0: %b, btn1: %b, btn2: %b, seg1: %b, seg2: %b, led1: %b, led2: %b", 
        $time, sw0, sw1, btn[0], btn[1], btn[2], seg1, seg2, led1, led2);
    end

    // apply reset and input signals
    initial begin
        // initialize signals
        clk = 0;
        rst = 1;
        sw0 = 0;
        sw1 = 0;
        btn = 3'b000;

        // turn on system
        #10 sw0 = 1;
        
        #10 rst = 0;
        
        #180        
        // test pause/unpause functionality
        #5 btn[0] = 1; // pause
        #50 btn[0] = 0;
        #20 btn[0] = 1; #10 btn[0] = 0;// unpause

        // test caution mode functionality
        #50 btn[2] = 1; // caution mode
        
        // test speed up functionality
        #100 sw1 = 1; // speed up
        #100 sw1 = 0;
        #50 btn[2] = 0;
        #10 rst = 1; #20 rst = 0;
    end

endmodule
