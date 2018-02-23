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

module assignment_4_tb();
  //module assignment_4(reset,clk,ibus,iaddrbus,databus,daddrbus,cdbus);
  //reset not yet used
  reg clk;
  //ibus not yet used
  //iaddrbus not yet used
  wire [31:0] databus;//todo more later for assign stuff
  //see marpaung testbench
  //TODO
  //daddrbus not yet used
  wire [31:0] cdbus;
  //counter for the number of tests
  reg [32:0] numtests, error;
  assignment_4 dut
  (
    .clk(clk)
    
  );
  initial begin
    //TODO: test this and actually make it work
    //NOTE: he set us up for a 25MHz clock
    //ns is nanosecond
    //ps is picosecond
    //1000ps = 1ns
    //hz = full clock cycle
    //1Mhz = 1000ns
    //25MHz = 40ns
    //40MHz = 25ns
    //20MHz = 50ns
    clk=1;
    $display ("Time=%t\n  clk=%b", $realtime, clk);
    #5//5ns delay
    clk=0;
    $display ("Time=%t\n  clk=%b", $realtime, clk);
    #5
    clk=1;
    $display ("Time=%t\n  clk=%b", $realtime, clk);
    #5
    clk=0;
    $display ("Time=%t\n  clk=%b", $realtime, clk);
    #5
    clk=1;
    $display ("Time=%t\n  clk=%b", $realtime, clk);
    #5
    clk=0;
    $display ("Time=%t\n  clk=%b", $realtime, clk);
    #5
    clk=1;
    $display ("Time=%t\n  clk=%b", $realtime, clk);
    #5
    clk=0;
    $display ("Time=%t\n  clk=%b", $realtime, clk);
    #5;
  end
endmodule