module traffic_light(
    input clk,             // clock signal (125MHz)
    input rst,             // reset signal
    input sw0,             // Turn on/off
    input sw1,             // 2x speed
    input [2:0] btn,       // btn0 = pause/unpause | btn2 = Caution mode
    output reg [6:0] seg1, // first 7-segment display
    output reg [6:0] seg2, // second 7-segment display
    output reg [2:0] led1, // RGB LED for vehicle traffic on the current road
    output reg [2:0] led2  // RGB LED for vehicle traffic on the intersecting road
);

// state definitions
localparam [2:0]
    RED1 = 3'b000,
    RED2 = 3'b001,
    GREEN = 3'b010,
    YELLOW = 3'b011;

localparam
    UNPAUSED = 0,
    PAUSED = 1;

// state register
reg [2:0] state;

// timer register (7-bit to accommodate values up to 99)
reg [6:0] timer;

// pause register
reg pause = 0;

// flashing yellow register
reg flash_yellow;

// flashing yellow counter
reg [31:0] flash_cnt;

// flash yellow period
wire [31:0] FLASH_PERIOD = sw1 ? 4 : 8; //0.5s / 1s

// clock divider (125MHz / 1Hz = 125_000_000)
wire [31:0] CLK_DIV = sw1 ? 4 : 8;      //0.5s / 1s
reg [31:0] clk_cnt;

// function to convert a value to a 7-segment display value
function [6:0] seg_display;
    input [3:0] value;
    case (value)
        4'd0: seg_display = 7'b1000000; // display 0
        4'd1: seg_display = 7'b1111001; // display 1
        4'd2: seg_display = 7'b0100100; // display 2
        4'd3: seg_display = 7'b0110000; // display 3
        4'd4: seg_display = 7'b0011001; // display 4
        4'd5: seg_display = 7'b0010010; // display 5
        4'd6: seg_display = 7'b0000010; // display 6
        4'd7: seg_display = 7'b1111000; // display 7
        4'd8: seg_display = 7'b0000000; // display 8
        4'd9: seg_display = 7'b0010000; // display 9
    endcase
endfunction

// task to pause or unpause based on button pressed
task pause_unpause;
    input btn0;
    begin
	case (pause)
	    UNPAUSED: begin
	       if(btn0) begin
	           pause = PAUSED;
	       end
	    end
	    PAUSED: begin
		  if(btn0) begin
		      pause = UNPAUSED;
		  end
	    end
	endcase
    end
endtask

task flash_yellow_task;
    input btn2;
    begin
        if (btn2) begin
            flash_yellow = 1;
        end
        if (flash_yellow) begin
            seg2 <= 7'b1111111;
            seg1 <= 7'b1111111;
            if (flash_cnt == FLASH_PERIOD - 1) begin
                flash_cnt = 0;  
            end else begin
                flash_cnt = flash_cnt + 1;
            end

            if(flash_cnt < FLASH_PERIOD / 2) begin
                led1 = 3'b011;
                led2 = 3'b011;
            end else begin
                led1 = 3'b000;
                led2 = 3'b000;
            end
            
            if(flash_cnt >= FLASH_PERIOD) begin
                flash_cnt = 0;            
            end 
        end
    end
endtask

// state machine
always @(posedge clk) begin
    if(!sw0) begin
        led1 <= 3'b000;
        led2 <= 3'b000;
        seg2 <= 7'b1111111;
        seg1 <= 7'b1111111;
    end else if (rst) begin
            state <= RED1;
            timer <= 15;        // red light lasts for 15 seconds
            led1 <= 3'b001;     // red light on for vehicle traffic on the current road
            led2 <= 3'b010;     // green light on for vehicle traffic on the intersecting road
            seg2 <= 7'b1111001; // 1
            seg1 <= 7'b0010010; // 5
            clk_cnt <= 0;
            pause <= 0;         // initialize pause to 0 (not paused)
            flash_yellow <= 0;  // initialzie flash yellow to 0 (not flashing)
            flash_cnt <= FLASH_PERIOD - 1;
    end else begin   
        pause_unpause(btn[0]); //call task to check pause/unpause
        if(!pause) begin
            if(!flash_yellow) begin
                if (clk_cnt == CLK_DIV - 1) begin
                    clk_cnt <= 0;
                    case (state)
                        RED1: begin                 // led1 still RED | led2 from GREEN to YELLOW
                            if (timer == 5) begin
                                state <= RED2;
                                timer <= 4;             // yellow light lasts for 5 seconds
                                led1 <= 3'b001;         // still red light for vehicle traffic on the current road
                                led2 <= 3'b011;         // yellow light on for vehicle traffic on the intersecting road
                                seg2 <= 7'b1000000;     // 0
                                seg1 <= 7'b0010010;     // 5
                            end else begin
                                timer <= timer - 1;
                                seg2 <= seg_display(timer / 10);
                                seg1 <= seg_display(timer % 10);                        
                            end 
                        end                
                        RED2: begin                 // led1 from RED to GREEN | led2 from YELLOW to RED
                            if (timer == 0) begin
                                state <= GREEN;
                                timer <= 10;        // green light lasts for 10 seconds
                                led1 <= 3'b010;     // green light on for vehicle traffic on the current road
                                led2 <= 3'b001;     // red light on for vehicle traffic on the intersecting road
                                seg2 <= 7'b1111001; // 1
                                seg1 <= 7'b1000000; // 0
                            end else begin
                                timer <= timer - 1;
                                seg2 <= seg_display(timer / 10);
                                seg1 <= seg_display(timer % 10);                         
                            end                             
                        end 
                        GREEN: begin                // led1 from GREEN to YELLOW | led2 still RED
                            if (timer == 0) begin 
                                state <= YELLOW; 
                                timer <= 5;         // yellow light lasts for 5 seconds 
                                led1 <= 3'b011;     // yellow light on for vehicle traffic on the current road 
                                led2 <= 3'b001;     // still red light for vehicle traffic on the intersecting road
                                seg2 <= 7'b1000000; // 0
                                seg1 <= 7'b0010010; // 5
                            end else begin 
                                timer <= timer - 1;
                                seg2 <= seg_display(timer / 10);
                                seg1 <= seg_display(timer % 10);                         
                            end  
                        end  
                        YELLOW: begin               // led1 from YELLOW to RED | led2 from RED to GREEN
                            if (timer == 0) begin  
                                state <= RED1;  
                                timer <= 15;        // red light lasts for 15 seconds  
                                led1 <= 3'b001;     // red light on for vehicle traffic on the current road 
                                led2 <= 3'b010;     // green light on for vehicle traffic on the intersecting road 
                                seg2 <= 7'b1111001; // 1
                                seg1 <= 7'b0010010; // 5
                            end else begin  
                                timer <= timer - 1;
                                seg2 <= seg_display(timer / 10);
                                seg1 <= seg_display(timer % 10);                         
                            end   
                        end                   
                    endcase   
                end else if (clk_cnt >= CLK_DIV) begin
                    clk_cnt <= 0;
                end else begin 
                    clk_cnt <= clk_cnt + 1; 
                end
            end
            flash_yellow_task(btn[2]);  //call task to check flashing yellow  
        end
    end 
end 

endmodule


