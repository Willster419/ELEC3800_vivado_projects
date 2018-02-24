/*************************
*  Willard Wider
*  02-21-18
*  ELEC3800
*  assignment_4.v
*  building a tomselo CPU
*************************/

/*
Current specs:
3 opcode bits (8 instructions total)
3 register bits (8 registers total) [register 0 is the nothing register]
32 bit register/bus width
format: 000__000 __000 __000 
        op __dest__src1__src2
        (12 bit width)
*/

/*
Current Instruction List:
NOP   000
LD    001
ST    010
ADDF  011
MULTF 100
*/


module assignment_4(reset,clk,ibus,iaddrbus,databus,daddrbus);
  //NOT YET USED//////////////////////////////////////////////////
  //a reset for the CPU. Sets the program counter back to 0
  //PC = reset? 0: PC+4
  //not used for now
  input reset;
  //the instruction bus. sends instructions into the instruction queue
  //not used for now
  //not sure if it will ever be used
  input [11:0] ibus;
  //the address output of the program counter
  //not used for now
  output [31:0] iaddrbus;
  ////////////////////////////////////////////////////////////////
  
  //the clock. it's a clock
  input clk;
  
  //the databus or loading and storing data to (big bad) memeory
  inout  [31:0] databus;
  //the output calculated value of the the data address bus
  output [31:0] daddrbus;
  
  //the wires used for the operation bus
  wire [2:0] opbus_opcode;
  wire [2:0] opbus_dest;
  wire [2:0] opbus_src_a;
  wire [2:0] opbus_src_b;
  
  //the wires used for the common data bus
  wire [2:0] cdbus_dest;
  wire [7:0] cdbus_dest_shift;//assign it to be always shifted value of cdbus_dest
  wire [31:0] cdbus_data;
  
  //wires for reg
  wire [7:0] busy_bus;
  
  //wires connectingthe regfile to the reservation station
  wire [31:0] abus_wire;
  wire [31:0] bbus_wire;
  wire [7:0] a_select_wire;
  wire [7:0] b_select_wire;
  
  //the reg flags for the execution units
  reg mem_flag;
  reg FP_add_flag;
  reg FP_mult_flag;
  reg int_flag;
  
  //the wires for connecting the units full flags
  reg mem_full_flag;
  wire FP_add_full_flag;
  reg FP_mult_full_flag;
  reg int_full_full_flag;
  
  //the reg as the instruction queue
  //first bracket is how wide each register is
  //second bracket is now many in the array
  //we want 6 instruction queues of 12 bits wide
  reg [11:0] instruction_queue [5:0];
  reg [11:0] current_instruction;
  
  //the fake clock
  reg fake_clock;
  
  //counter for the dequeue for loop
  integer i;
  
  //the control bit for setting the high bit for if the register is high
  reg [7:0] busy_select_shift;
  
  //register module instance
  regfile best_regfile_name_ever
  (
    //ins
    .clk(clk),
    .Aselect(a_select_wire),
    .Bselect(b_select_wire),
    .busySelect(busy_select_shift),
    //outs
    .busyBus(busy_bus),
    .abus(abus_wire),
    .bbus(bbus_wire)
    //not useds
    /*
      .Dselect(),
      .dbus()
    */
  );
  
  //reservation station instance for added
  reservation_station #(.BUS_LENGTH(4)) FP_add_station
  (
    //ins
    .fake_clock(fake_clock), .station_selected(FP_add_flag), .opbus_op(opbus_opcode), .opbus_dest(opbus_dest), .opbus_src_a(opbus_src_a),
    .opbus_src_b(opbus_src_b), .abus_in(abus_wire), .bbus_in(bbus_wire), .busy_bus(busy_bus),
    //outs
    .a_select_out(a_select_wire), .b_select_out(b_select_wire), .station_full(FP_add_full_flag)
    //not useds
    /*
      .execution_unit_busy(), .d_select_out(), .d_select_out_shift(), .abus_out(), .bbus_out(), .op_code_out(),
    */
  );
  
  initial begin
    //set all the execution flags to 0
    mem_flag = 0;
    FP_add_flag = 0;
    FP_mult_flag = 0;
    int_flag = 0;
    mem_full_flag = 0;
    //FP_add_full_flag = 0;
    FP_mult_full_flag = 0;
    int_full_full_flag = 0;
    //set the fake clock
    fake_clock = 0;
    //set the busy_select to 0
    busy_select_shift = 8'b0;
    //set the current instructin to nothing
    current_instruction = 12'b0;
    //fill the instruction queue
    instruction_queue[0] [11:0] = 12'b011_011_010_001;
    //instruction_queue[1] [11:0] = 12'b100_000_101_100;
    instruction_queue[1] [11:0] = 12'b000_000_000_000;
    instruction_queue[2] [11:0] = 12'b000_000_000_000;
    instruction_queue[3] [11:0] = 12'b000_000_000_000;
    instruction_queue[4] [11:0] = 12'b000_000_000_000;
    instruction_queue[5] [11:0] = 12'b000_000_000_000;
  end
  
  always @(negedge clk) begin
    //decode the instruction
    //set the flags to 0
    mem_flag = 0;
    FP_add_flag = 0;
    FP_mult_flag = 0;
    int_flag = 0;
    //set the busy_select to 0. it only triggers on the posedge so it won't be an issue
    busy_select_shift = 8'b0;
    //copy the instruction to the current reg
    current_instruction[11:0] = instruction_queue[0];
    /*
    Current Instruction List:
    NOP   000
    LD    001
    ST    010
    ADDF  011
    MULTF 100
    */
    case (current_instruction[11:9])
      3'b000: begin
        //nop
        //don't set any flags...
      end
      3'b001: begin
        //LOAD
        /*
        if(!mem_full_flag) begin
          mem_flag = 1;
        end
        */
        mem_flag = (mem_full_flag)? 0 : 1;
      end
      3'b010: begin
        //STORE
        mem_flag = (mem_full_flag)? 0 : 1;
      end
      3'b011: begin
        //ADDF
        FP_add_flag = (FP_add_full_flag)? 0 : 1;
      end
      3'b100: begin
        //MULTF
        FP_mult_flag = (FP_mult_full_flag)? 0 : 1;
      end
    endcase
    if(mem_flag||FP_add_flag||FP_mult_flag||int_flag) begin
      //set the busyBus for the regfile
      busy_select_shift = 8'b00000001 << current_instruction[8:6];
      //shift the entries down from the queue
      //act as the dequeue
      for(i = 0; i < 5; i=i+1) begin
        instruction_queue[i] = instruction_queue[i+1];
      end
    end
    //invert the clock so that it #triggers the reservation station
    fake_clock = ~fake_clock;
  end
  assign opbus_opcode = (mem_flag|FP_add_flag|FP_mult_flag|int_flag)? current_instruction[11:9] : 3'bz;
  assign opbus_dest = (mem_flag|FP_add_flag|FP_mult_flag|int_flag)? current_instruction[8:6] : 3'bz;
  assign opbus_src_a = (mem_flag|FP_add_flag|FP_mult_flag|int_flag)? current_instruction[5:3] : 3'bz;
  assign opbus_src_b = (mem_flag|FP_add_flag|FP_mult_flag|int_flag)? current_instruction[2:0] : 3'bz;
  //assign busy_select_shift = (mem_flag|FP_add_flag|FP_mult_flag|int_flag)? 8'b00000001 << opbus_dest : 8'b0;
endmodule

//the module for creating the reservation stations
//default data iwdth is 1, can be changed to allow more width
module reservation_station #(parameter BUS_LENGTH = 1)
  (
    //ins
    fake_clock, station_selected, opbus_op, opbus_dest, opbus_src_a, opbus_src_b, abus_in, bbus_in, busy_bus, execution_unit_busy,
    //outs
    a_select_out, b_select_out, d_select_out, d_select_out_shift, abus_out, bbus_out, op_code_out, station_full
  );
  //the delayed clock for triggering the alwyas block
  //it's the last thing done in the always block for the instruction dequeuing
  input fake_clock;
  //determins if the station is selected to grab the next enqueued element
  input station_selected;
  //link to the op bus components
  input [2:0] opbus_op;
  input [2:0] opbus_dest;
  input [2:0] opbus_src_a;
  input [2:0] opbus_src_b;
  //the inputs from the regfile
  input [31:0] abus_in,bbus_in;
  //the array of busy buses from the regfile. it's a wire here so always updated
  input [7:0] busy_bus;
  //flag for if the execution unit is busy
  input execution_unit_busy;
  //the selector to the regfile for which register to use in the abus
  output reg [7:0] a_select_out;
  output reg [7:0] b_select_out;
  //the selector to the execution for which register to write to
  output reg [7:0] d_select_out_shift;
  output reg [2:0] d_select_out;
  //the output for the data from the abus and bbus data arrays
  output reg [31:0] abus_out, bbus_out;
  //the opcode for the execution
  output reg [2:0] op_code_out;
  //flag to tell wether the station is full
  output reg station_full;
  //INFO: it may be possible to later do this as a module array
  //array of busses acting as the queue
  reg[BUS_LENGTH:0] op_code [2:0];
  reg[BUS_LENGTH:0] dest_reg [2:0];
  reg[BUS_LENGTH:0] dest_reg_shift [7:0];
  reg[BUS_LENGTH:0] src_a [2:0];
  reg[BUS_LENGTH:0] src_a_shift [7:0];
  reg[BUS_LENGTH:0] src_b [2:0];
  reg[BUS_LENGTH:0] src_b_shift [7:0];
  //the data from the regfile
  reg[BUS_LENGTH:0] abus_data[31:0];
  reg[BUS_LENGTH:0] bbus_data[31:0];
  //array of bits if the instruction at the index is ready
  //if a and b have the data yet
  reg[BUS_LENGTH:0] operation_data_a_ready;
  reg[BUS_LENGTH:0] operation_data_b_ready;
  //array of bits if the station at the index is in use
  reg[BUS_LENGTH:0] station_in_use;
  //the counter to traverse the array of stations
  //used as the index location for where to enqueue the instruction
  reg[31:0] counter;
  reg[31:0] counter2;
  
  //for simulation purposes, simlulate the common data bus
  reg[31:0] cdb_data;
  reg[2:0] cdb_dest;
  reg[7:0] cdb_dest_shift;
  
  initial begin
    //init everyting to 0
    a_select_out = 8'bz;
    b_select_out = 8'bz;
    d_select_out = 8'bz;
    abus_out = 32'bz;
    bbus_out = 32'bz;
    op_code_out = 3'b0;//NOP
    station_full = 0;
    counter = 0;
    //TODO: figure out if this works
    operation_data_a_ready = 0;
    operation_data_b_ready = 0;
    station_in_use = 0;
    //TODO: figure out how to write all double arrays
  end
  
  //use fake_clock to give a little delay
  //in theory it's listinigh for the change and therefore
  //won't *have* to happen during the blocking part
  always @(fake_clock) begin
    //only run this if the station is not full
    counter = 0;
    //extra if statement check, in theory not needed
    if(!station_full) begin
      //use a loop to incriment the counter to determine the next available station
      //at this point we know that the station has at least one slot available
      if(station_selected) begin:enqueue_op_break
        repeat(BUS_LENGTH) begin:enqueue_op_continue
          if(!station_in_use[counter]) begin
            //update hte value in that counter
            op_code[counter] [2:0] = opbus_op;
            dest_reg_shift[counter] [7:0] = 8'b00000001 << opbus_dest;
            dest_reg[counter] [2:0] = opbus_dest;
            src_a[counter] [2:0] = opbus_src_a;
            src_b[counter] [2:0] = opbus_src_b;
            src_a_shift[counter] [7:0] = 8'b00000001 << opbus_src_a;
            src_b_shift[counter] [7:0] = 8'b00000001 << opbus_src_b;
            //don't need to do this part here since it's taken care of in the next loop
            operation_data_a_ready[counter] = 0;
            operation_data_b_ready[counter] = 0;
            //also check if it's the last reservation station
            if(counter+1 == BUS_LENGTH) begin
              station_full = 1;
            end
            //and disable the loop to prevent accidental updating any more values
            disable enqueue_op_break;
          end
          counter = counter+1;
        end
      end
    end
    counter = 0;
    //use a loop to incriment the counter  for checking if data is ready
    begin:data_check_break
      repeat(BUS_LENGTH) begin:data_check_continue
        if(station_in_use[counter]) begin
          //check if the value for each src is ready
          //first check via snooping
          if(!operation_data_a_ready[counter]) begin
            //if the snopped data is relavent to this reservation station
            if(0) begin
              //don't snoop for now, cdb not connected...
              operation_data_a_ready[counter]=1;
            end
            else if(!busy_bus[src_a[counter]]) begin
              //it is ready, set the output address of a
              //it will trigger the wire to put the value at the reg index onto the abus
              a_select_out = src_a_shift[counter];
              abus_data[counter] = abus_in;
              operation_data_a_ready[counter]=1;
            end
          end
          if(!operation_data_b_ready[counter]) begin
            //if the snopped data is relavent to this reservation station
            if(0) begin
              //don't snoop for now, cdb not connected...
              operation_data_b_ready[counter]=1;
            end
            else if(!busy_bus[src_b[counter]]) begin
              //it is ready, set the output address of a
              //it will trigger the wire to put the value at the reg index onto the abus
              b_select_out = src_b_shift[counter];
              bbus_data[counter] = bbus_in;
              operation_data_b_ready[counter]=1;
            end
          end
        end
        counter = counter+1;
      end
    end
    //use a loop to enqueue the next value onto the output bus
    counter = 0;
    begin:data_output_break
      //only touch the output bus if you have to!
      repeat(BUS_LENGTH) begin:data_output_continue
        if(station_in_use[counter] && operation_data_a_ready[counter] && operation_data_b_ready[counter]) begin
          //set all the stuff and touch the output buses
          abus_out = abus_data[counter];
          bbus_out = bbus_data[counter];
          d_select_out = dest_reg[counter];
          d_select_out_shift = dest_reg_shift[counter];
          op_code_out = op_code[counter];
          //then shift all the values down in the queue
          /*
            example: if this is index 1 and it is ready
            then shift all values down one "unit"
            without touching the values below it (like unit 0)
            and the top will therefore be filled with zeors
          */
          //regs to shift:
          /*
            reg[BUS_LENGTH:0] op_code [2:0];
            reg[BUS_LENGTH:0] dest_reg [2:0];
            reg[BUS_LENGTH:0] dest_reg_shift [7:0];
            reg[BUS_LENGTH:0] src_a [2:0];
            reg[BUS_LENGTH:0] src_a_shift [7:0];
            reg[BUS_LENGTH:0] src_b [2:0];
            reg[BUG_LENGTH:0] src_b_shift [7:0];
            reg[BUG_LENGTH:0] abus_data[31:0];
            reg[BUG_LENGTH:0] bbus_data[31:0];
            reg[BUS_LENGTH:0] operation_data_a_ready;
            reg[BUS_LENGTH:0] operation_data_b_ready;
            reg[BUS_LENGTH:0] station_in_use;
          */
          counter2 = counter;
          repeat(BUS_LENGTH - counter - 1)begin
            op_code[counter2] = op_code[counter2+1];
            dest_reg[counter2] = dest_reg[counter2+1];
            dest_reg_shift[counter2] = dest_reg_shift[counter2+1];
            src_a[counter2] = src_a[counter2+1];
            src_a_shift[counter2] = src_a_shift[counter2+1];
            src_b[counter2] = src_b[counter2+1];
            src_b_shift[counter2] = src_b_shift[counter2+1];
            abus_data[counter2] = abus_data[counter2+1];
            bbus_data[counter2] = bbus_data[counter2+1];
            operation_data_a_ready[counter2] = operation_data_a_ready[counter2+1];
            operation_data_b_ready[counter2] = operation_data_b_ready[counter2+1];
            station_in_use[counter2] = station_in_use[counter2+1];
            counter2 = counter2+1;
          end
          //and also set the station full flag to low
          station_full = 0;
          disable data_output_break;
        end
        counter = counter+1;
      end
    end
  end
endmodule

//the module for creating the execution units
//may need to make seperate ones later
/*
ID is as follows:
00 = integer unit
01 = FP multiplier unit
10 = FP adder unit

module execution_unit #(parameter CYCLE_TIME = 1, ID = 2'b00)(operation,dselect_index,abus_data,bbus_data,clk,is_busy,write_data,reg_index_out,processed_data_out);
  //the input from the reservation station
  input [2:0] operation, dselect_index;
  //the data from the regfile from the reservation station
  //NOTE: data from the regfile may be different at this point
  input [31:0] abus_data, bbus_data;
  //it's the clock lol
  input clk;
  //flag to determine if the execution unit is busy
  output reg is_busy;
  //flag for the regfile to verify it only accepts the final value at the correct time
  output reg write_data;
  //counter to use for determining the "cycle" of execution
  reg [2:0] counter;
  //the holder for the regfile index
  reg [7:0] reg_index;
  //the holder for the processed data
  reg [31:0] processed_data;
  //the actual outputs for above, but in output form
  output reg [7:0] reg_index_out;
  output reg [31:0] processed_data_out;
  initial begin
    //set all the stuffs to 0
    is_busy = 0;
    counter = 3'b0;
    reg_index = 8'b0;
    processed_data = 0;
    write_data = 0;
    //it's going to a dumb register anyway
    reg_index_out = 8'b0;
    processed_data_out = 0;
  end
  always @(posedge clk) begin
    write_data = 0;
    counter = counter + 1'b1;
    if(!is_busy)begin
      //set the unit to busy
      is_busy = 1;
      //set the actual registry index value
      //set it to 0 first to make sure it actually works
      reg_index = 8'b0;
      reg_index = 1'b1 << dselect_index;
      //accept the new value
      /*
      Current Instruction List:
      NOP   000
      LD    001
      ST    010
      ADDF  011
      MULTF 100
      
      case(ID)
        2'b00: begin
          //integer execution unit
          //nothing yet...
        end
        2'b01: begin
          //FP multiplier unit
          case(operation)
            3'b100: begin
              //adding floating point
              processed_data = abus_data + bbus_data;
            end
          endcase
        end
        2'b10: begin
          //FP adder unit
          case(operation)
            3'b011: begin
              //multiplying floating point
              processed_data = abus_data * bbus_data;
            end
          endcase
        end
      endcase
    end
    if(counter == CYCLE_TIME) begin
      //reset the counter and the busy flag
      is_busy = 0;
      counter = 3'b0;
      //set the write data flag to high
      //the reg will pick it up at the neg edge
      write_data = 1;
      //actually write the select and data on the output
      reg_index_out = reg_index;
      processed_data_out = processed_data;
    end
  end
endmodule

//the module for dealing with the memory
module memory_unit()
  
endmodule
*/
//the reg file
//registers are 32 bit length
//there are 8 of them
//register 0 is the null register
module regfile(
  input [7:0] Aselect,//select the register index to read from to store into abus
  input [7:0] Bselect,//select the register index to read from to store into bbus
  input [7:0] Dselect,//select the register to write to from dbus
  input [7:0] busySelect,//flag for each flipflop to say if it is open
  input [31:0] dbus,//data in
  output [31:0] abus,//data out
  output [31:0] bbus,//data out
  output [7:0] busyBus,//bus for each of the reg entries if it's busy or not
  input clk
  );
  //if it's requesting register 0 just output a 0
  assign abus = Aselect[0] ? 32'b0 : 32'bz;
  assign bbus = Bselect[0] ? 32'b0 : 32'bz;
  //only 8 of these for now
  DNegflipFlop myFlips[7:0](
    .dbus(dbus),
    .abus(abus),
    .Dselect(Dselect[7:0]),//doing this means that index 7 of Deslect will go to DNegflipFlop index 7
    .Bselect(Bselect[7:0]),
    .Aselect(Aselect[7:0]),
    .busySelect(busySelect[7:0]),
    .bbus(bbus),
    .isBusy(busyBus[7:0]),
    .clk(clk)
    );
endmodule

module DNegflipFlop(dbus, abus, Dselect, Bselect, Aselect, bbus, clk, busySelect, isBusy);
  input [31:0] dbus;
  input Dselect;//the select write bit for this register
  input Bselect;//the select read bit for this register
  input Aselect;//the other select read bit for this register
  input busySelect;
  input clk;
  output [31:0] abus;
  output [31:0] bbus;
  reg [31:0] data;//the actual data for the register
  output reg isBusy;
  
  initial begin
  //start the registers empty
  data = 32'h00000001;
  isBusy = 0;
  end
  
  //at the change in this register
  always @(posedge busySelect) begin
    isBusy = 1;
  end
  
  always @(negedge clk) begin
    //if this register has d select high, update the data from the dbus
    if(Dselect) begin
      data = dbus;
      isBusy = 0;
    end
  end
  //if this register has a or b select high, update the a and b bus
  assign abus = Aselect? data : 32'hzzzzzzzzzzzzzzzz;
  assign bbus = Bselect? data : 32'hzzzzzzzzzzzzzzzz;
endmodule
