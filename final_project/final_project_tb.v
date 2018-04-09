/*************************
*  Willard Wider
*  02-21-18
*  ELEC3800
*  assignment_4_tb.v
*  testing a tomselo CPU
*************************/

//time scale explanation:
//`timescale <reference_time>/ <precision>
//the first number is to use for reference (in the time simulation)
//the delay values are written as value * 1ns
//so #5 means a 5ns delay
//the second is the simulation resolution
`timescale 1ns/10ps

//general tb stuff
//inputs are registers
//outputs are wires

module final_project_tb();
  //FOR TESTING BOTH////////////////////////
  reg clk;
  reg [32:0] numtests, error;
  //counter for the number of tests
  integer num_cycles, i;
  //////////////////////////////////////////
  
  //FOR TESTING PROCESSOR///////////////////
  //module assignment_4(reset,clk,ibus,iaddrbus,databus,daddrbus,cdbus);
  //reset not yet used
  //ibus not yet used
  //iaddrbus not yet used
  wire [31:0] databus;//todo more later for assign stuff
  //see marpaung testbench
  //TODO
  //daddrbus not yet used
  wire [31:0] cdbus;
  //////////////////////////////////////////
  
  //FOR TESTING CACHE///////////////////////
  //module cache(clk,p0_request,p1_request,data_out is_busy);
  
  wire [21:0] data_out;
  wire is_busy;
  //first bracket is how wide each register is
  //second bracket is now many in the array
  reg [21:0] request_from_p0 [3:0];
  reg [21:0] request_from_p1 [3:0];
  reg [21:0] temp_request_from_p0;
  reg [21:0] temp_request_from_p1;
  
  cache make_it_rain
  (
    .clk(clk),
    .p0_request(temp_request_from_p0),
    .p1_request(temp_request_from_p1),
    .data_out(data_out),
    .is_busy(is_busy)
  );
  
  final_project dut
  (
    //.clk(clk)
    
  );
  
  //////////////////////////////////////////
  
  initial begin
    //NOTE: he set us up for a 25MHz clock
    //ns is nanosecond
    //ps is picosecond
    //1000ps = 1ns
    //hz = full clock cycle
    //1Mhz = 1000ns
    //25MHz = 40ns
    //40MHz = 25ns
    //20MHz = 50ns
    //$display("reservation station IDs: 001=MULT, 010=ADD, 011=ST, 100=LD");
    //$display("execution unit IDs:      001=MULT, 010=ADD, 011=LD/ST");
    $display("REFRENCE: the request line:\n processor id (1 bit)\n load-store flag (1 bit) (0=load, 1=store)\n the tag (11 bits)\n the block offset (1 bits)\n the data (8 bits)");
    $display("REFRENCE: the data_out line:\n the processor id (1 bit)\n the request type (load/store) (1 bit)\n the tag (11 bits)\n the block offset (1 bits)\n the data (if a load) (8 bits)");
    //the request line:
    //processor id (1 bit)
    //load-store flag (1 bit) (0=load, 1=store)
    //the tag (11 bits)
    //the block offset (1 bits)
    //the data (if a store from processor to memory) (8 bits)
    temp_request_from_p0 = 22'bz;
    temp_request_from_p1 = 22'bz;
    request_from_p0 [0] = 22'b0_1_01010000000_1_01010101;
    request_from_p0 [1] = 22'b0_0_01011001000_0_00000000;
    
    request_from_p1 [0] = 22'b1_0_01010000000_1_01010101;
    //request_from_p1 [1] = 22'b1_1_01011001000_0_00000000;
    request_from_p1 [1] = 22'bz;
    num_cycles = 2;
    for(i=0;i < num_cycles; i= i+1) begin
      clk=0;
      $display ("\nTime=%t,  clk=%b", $realtime, clk);
      #5
      temp_request_from_p1 = request_from_p1[i];
      clk=1;
      $display ("\nTime=%t,  clk=%b, cycle=%d", $realtime, clk, i+1);
      #5;//5ns delay
    end
  end
endmodule