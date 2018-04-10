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
  //SHARED//////////////////////////////////
  reg clk;
  //counter for the number of tests
  integer num_cycles, i;
  //////////////////////////////////////////
  
  //FOR TESTING BOTH TOGETHER///////////////
  //signal for both processors to know when the cache is busy
  wire cache_busy;
  //the request lines
  wire [21:0] p0_request, p1_request;
  //the data line out of the cache into both processors
  wire [21:0] data_out;
  //////////////////////////////////////////
  
  //FOR TESTING PROCESSOR///////////////////
  //module assignment_4(reset,clk,ibus,iaddrbus,databus,daddrbus,cdbus);
  //
  //////////////////////////////////////////
  
  //FOR TESTING CACHE///////////////////////
  //module cache(clk,p0_request,p1_request,data_out is_busy);
  /*
  wire [21:0] data_out;
  wire is_busy;
  //first bracket is how wide each register is
  //second bracket is now many in the array
  reg [21:0] request_from_p0 [3:0];
  reg [21:0] request_from_p1 [3:0];
  reg [21:0] temp_request_from_p0;
  reg [21:0] temp_request_from_p1;
  */
  //////////////////////////////////////////
  
  cache make_it_rain
  (
    .clk(clk),
    .p0_request(p0_request),
    .p1_request(p1_request),
    .data_out(data_out),
    .is_busy(cache_busy)
  );
  
  //module final_project(clk,cache_request,cache_data,cache_busy);
  final_project #(.CPU_ID(1'b0)) dut
  (
    .clk(clk),
    .cache_request(p0_request),
    .cache_data(data_out),
    .cache_busy(cache_busy)
  );
  
  
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
    $display("REFRENCE: reservation station IDs:  001=MULT, 010=ADD, 011=ST, 100=LD");
    $display("REFRENCE: execution unit IDs:       001=MULT, 010=ADD, 011=LD/ST");
    $display("REFRENCE: current instruction list: 000=NOP,  001=LD,  010=ST, 011=ADD, 100=MULT, 101=SUBT");
    $display("REFRENCE: the request line:\n processor id (1 bit)\n load-store flag (1 bit) (0=load, 1=store)\n the tag (11 bits)\n the block offset (1 bits)\n the data (8 bits)");
    $display("REFRENCE: the data_out line:\n the processor id (1 bit)\n the request type (load/store) (1 bit)\n the tag (11 bits)\n the block offset (1 bits)\n the data (if a load) (8 bits)");
    
    /*FOR TESTING CACHE/////////////////////////////////////////
    temp_request_from_p0 = 22'bz;
    temp_request_from_p1 = 22'bz;
    
    request_from_p0 [0] = 22'b0_1_01010000000_1_00000000;
    //request_from_p0 [1] = 22'b0_0_01011001000_0_00000000;
    request_from_p0 [1] = 22'bz;//simulates hold signal
    request_from_p0 [2] = 22'b0_0_01011010000_0_00000000;
    
    request_from_p1 [0] = 22'b1_0_01010000000_1_11111111;
    //request_from_p1 [1] = 22'b1_1_01011001000_0_00000000;
    request_from_p1 [1] = 22'bz;//simulates hold signal
    request_from_p1 [2] = 22'bz;
    ///////////////////////////////////////////////////////////*/
    
    num_cycles = 15;
    for(i=0;i < num_cycles; i= i+1) begin
      clk=0;
      $display ("\nTime=%t,  clk=%b", $realtime, clk);
      #5
      //temp_request_from_p0 = request_from_p0[i];
      //temp_request_from_p1 = request_from_p1[i];
      clk=1;
      $display ("\nTime=%t,  clk=%b, cycle=%d", $realtime, clk, i+1);
      #5;
    end
  end
endmodule