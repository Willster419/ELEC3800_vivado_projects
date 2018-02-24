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
  
  //the clock. it's a clock. it does clock things.
  input clk;
  
  //the databus or loading and storing data to (big bad) memeory
  inout  [31:0] databus;
  //the output calculated value of the the data address bus
  output [31:0] daddrbus;
  
  //the wires used for the operation bus
  //connects the instructon queue (top module for now)
  //to the reservation stations
  wire [2:0] opbus_opcode;
  wire [2:0] opbus_dest;
  wire [2:0] opbus_src_a;
  wire [2:0] opbus_src_b;
  
  //the wires used for the common data bus
  //connects the execution units to the regfile and
  //to the reservation stations
  wire [2:0] cdbus_dest;
  wire [7:0] cdbus_dest_shift;
  wire [31:0] cdbus_data;
  wire cdbus_valid_data;
  
  //wires connecting the regfile to the reservation station
  wire [31:0] abus_wire;
  wire [31:0] bbus_wire;
  wire [7:0] a_select_wire;
  wire [7:0] b_select_wire;
  wire [7:0] busy_bus;
  
  //wires connecting the reservation station and the execution unit
  wire [2:0] rs_ex_op_code;
  wire [2:0] rs_ex_d_select;
  wire [7:0] rs_ex_d_select_shift;
  wire [31:0] rs_ex_abus_data;
  wire [31:0] rs_ex_bbus_data;
  wire rs_ex_fp_add_is_busy;
  
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
    .clk(clk), .Aselect(a_select_wire), .Bselect(b_select_wire), .busySelect(busy_select_shift),
    .Dselect(cdbus_dest_shift), .dbus(cdbus_data), .validData(cdbus_valid_data),
    //outs
    .busyBus(busy_bus), .abus(abus_wire), .bbus(bbus_wire)
    //not useds
    
  );
  
  //reservation station instance for added
  reservation_station #(.BUS_LENGTH(5)) FP_add_station
  (
    //ins
    .clk(clk), .fake_clock(fake_clock), .station_selected(FP_add_flag), .opbus_op(opbus_opcode), .opbus_dest(opbus_dest),
    .opbus_src_a(opbus_src_a), .opbus_src_b(opbus_src_b), .abus_in(abus_wire), .bbus_in(bbus_wire), .busy_bus(busy_bus),
    //outs
    .a_select_out(a_select_wire), .b_select_out(b_select_wire), .station_full(FP_add_full_flag),
    .execution_unit_busy(rs_ex_fp_add_is_busy), .d_select_out(rs_ex_d_select), .d_select_out_shift(rs_ex_d_select_shift),
    .abus_out(rs_ex_abus_data), .bbus_out(rs_ex_bbus_data), .op_code_out(rs_ex_op_code)
    //not useds
    
  );
  //execution unit instance for adding
  //ID=10=FP_ADD
  execution_unit #(.CYCLE_TIME(3),.ID(2'b10)) FP_add_unit
  (
    //ins
    .clk(clk), .op_code_in(rs_ex_op_code), .d_select_in(rs_ex_d_select), .d_select_shift_in(rs_ex_d_select_shift),
    .abus_data_in(rs_ex_abus_data), .bbus_data_in(rs_ex_bbus_data),
    //outs
    .is_busy(rs_ex_fp_add_is_busy), .valid_data(cdbus_valid_data), .dbus_data_out(cdbus_data), .d_select_out(cdbus_dest),
    .d_select_shift_out(cdbus_dest_shift)
    //not useds
    
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
  
  always @(posedge clk) begin
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
      //and fill the last one with zeros
      instruction_queue[5] = 12'b0;
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
    clk, fake_clock, station_selected, opbus_op, opbus_dest, opbus_src_a, opbus_src_b, abus_in, bbus_in, busy_bus, execution_unit_busy,
    //outs
    a_select_out, b_select_out, d_select_out, d_select_out_shift, abus_out, bbus_out, op_code_out, station_full, trigger_exes
  );
  //the regular good'ol clock
  input clk;
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
  //output to trigger the execution, happends at the end of the posedge block here
  //so it acts as a dealy
  output reg trigger_exes;
  //INFO: it may be possible to later do this as a module array
  //array of busses acting as the queue
  //first bracket is how wide each register is
  //second bracket is now many in the array
  reg[2:0] op_code [BUS_LENGTH:0];
  reg[2:0] dest_reg [BUS_LENGTH:0];
  reg[7:0] dest_reg_shift [BUS_LENGTH:0];
  reg[2:0] src_a [BUS_LENGTH:0];
  reg[7:0] src_a_shift [BUS_LENGTH:0];
  reg[2:0] src_b [BUS_LENGTH:0];
  reg[7:0] src_b_shift [BUS_LENGTH:0];
  //the data from the regfile
  reg[31:0] abus_data[BUS_LENGTH:0];
  reg[31:0] bbus_data[BUS_LENGTH:0];
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
  
  //indexs saying which station index a and b data to update at the positive edge
  reg[31:0] a_update_index;
  reg[31:0] b_update_index;
  reg a_update_index_flag;
  reg b_update_index_flag;
  
  initial begin
    trigger_exes = 0;
    a_update_index = 0;
    b_update_index = 0;
    a_update_index_flag = 0;
    b_update_index_flag = 0;
    //init everyting to 0
    a_select_out = 8'bz;
    b_select_out = 8'bz;
    d_select_out = 8'bz;
    d_select_out_shift = 8'bz;
    abus_out = 32'bz;
    bbus_out = 32'bz;
    op_code_out = 3'bz;
    station_full = 0;
    counter = 0;
    repeat(BUS_LENGTH+1) begin
      op_code[counter] = 3'b0;
      dest_reg[counter] = 3'b0;
      dest_reg_shift[counter] = 8'b0;
      src_a[counter] = 3'b0;
      src_a_shift[counter] = 8'b0;
      src_b[counter] = 3'b0;
      src_b_shift[counter] = 8'b0;
      abus_data[counter] = 32'b0;
      bbus_data[counter] = 32'b0;
      operation_data_a_ready[counter] = 0;
      operation_data_b_ready[counter] = 0;
      station_in_use[counter] = 0;
      counter = counter+1;
    end
    counter = 0;
    counter2 = 0;
  end
  
  //use fake_clock to give a little delay
  //in theory it's listinigh for the change and therefore
  //won't *have* to happen during the blocking part
  always @(fake_clock) begin
    //only run this if the station is not full
    counter = 0;
    counter2 = 0;
    a_update_index_flag = 0;
    b_update_index_flag = 0;
    //extra if statement check, in theory not needed
    if(!station_full) begin
      //use a loop to incriment the counter to determine the next available station
      //at this point we know that the station has at least one slot available
      if(station_selected) begin:enqueue_op_break
        repeat(BUS_LENGTH+1) begin:enqueue_op_continue
          if(!station_in_use[counter]) begin
            $display("station %d is not in use, filling", counter);
            //update hte value in that counter
            op_code[counter] [2:0] = opbus_op;
            dest_reg_shift[counter] [7:0] = 8'b00000001 << opbus_dest;
            dest_reg[counter] [2:0] = opbus_dest;
            src_a[counter] [2:0] = opbus_src_a;
            src_b[counter] [2:0] = opbus_src_b;
            src_a_shift[counter] [7:0] = 8'b00000001 << opbus_src_a;
            src_b_shift[counter] [7:0] = 8'b00000001 << opbus_src_b;
            operation_data_a_ready[counter] = 0;
            operation_data_b_ready[counter] = 0;
            station_in_use[counter] = 1;
            //also check if it's the last reservation station
            if(counter == BUS_LENGTH) begin
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
      repeat(BUS_LENGTH+1) begin:data_check_continue
        if(station_in_use[counter]) begin
          $display("station %d is in use", counter);
          //check if the value for each src is ready
          //first check via snooping
          if(!operation_data_a_ready[counter]) begin
            $display("data for a is not ready");
            //if the snopped data is relavent to this reservation station
            if(0) begin
              //don't snoop for now, cdb not connected...
              //update the value with the snopped value and set data ready flag
              operation_data_a_ready[counter]=1;
              //TODO:
              //but also check down below the queue that any destination registers don't match (WAW)
              //loop to check down
              //if dest==src_a
              //op_data_a_ready = 0;
            end
            //NOTE: not sure if the +1 needs to be there
            else if(!busy_bus[src_a[counter]]) begin
              $display("busy bus says regfile index of %d is up to date", src_a[counter]);
              //it is ready, set the output address of a
              //it will trigger the wire to put the value at the reg index onto the abus
              a_select_out = src_a_shift[counter];
              a_update_index = counter;
              //abus_data[counter] = abus_in;//don't do this until the posedge part
              operation_data_a_ready[counter]=1;
              a_update_index_flag = 1;
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
              b_update_index = counter;
              //bbus_data[counter] = bbus_in;//don't do this until the posedge part
              operation_data_b_ready[counter]=1;
              b_update_index_flag = 1;
            end
          end
        end
        counter = counter+1;
      end
    end
    
  end
  always @(negedge clk) begin
    counter = 0;
    //update the values from the data index saved earlier
    if(a_update_index_flag) begin
      abus_data[a_update_index] = abus_in;
    end
    if(b_update_index_flag) begin
      bbus_data[b_update_index] = bbus_in;
    end
    a_update_index_flag = 0;
    b_update_index_flag = 0;
    begin:data_output_break
      //only touch the output bus if you have to!
      repeat(BUS_LENGTH+1) begin:data_output_continue
        if(station_in_use[counter] && operation_data_a_ready[counter] && operation_data_b_ready[counter]) begin
          //set all the stuff and touch the output buses
          $display("station %d is in use, and operation data is ready",counter);
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
          counter2 = counter;
          repeat(BUS_LENGTH - counter)begin
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
          //then set the values of the last one to 0
          op_code[BUS_LENGTH] = 0;
          dest_reg[BUS_LENGTH] = 0;
          dest_reg_shift[BUS_LENGTH] = 0;
          src_a[BUS_LENGTH] = 0;
          src_a_shift[BUS_LENGTH] = 0;
          src_b[BUS_LENGTH] = 0;
          src_b_shift[BUS_LENGTH] = 0;
          abus_data[BUS_LENGTH] = 0;
          bbus_data[BUS_LENGTH] = 0;
          operation_data_a_ready[BUS_LENGTH] = 0;
          operation_data_b_ready[BUS_LENGTH] = 0;
          station_in_use[BUS_LENGTH] = 0;
          //and also set the station full flag to low
          station_full = 0;
          disable data_output_break;
        end
        counter = counter+1;
      end
    end
    trigger_exes = ~trigger_exes;
  end
endmodule

//the module for creating the execution units
//may need to make seperate ones later
/*
ID is as follows:
00 = integer unit
01 = FP multiplier unit
10 = FP adder unit
*/
module execution_unit #(parameter CYCLE_TIME = 1, ID = 2'b00)
  (
    //in
    clk, op_code_in, d_select_in, d_select_shift_in, abus_data_in, bbus_data_in,
    //out
    is_busy, valid_data, dbus_data_out, d_select_out, d_select_shift_out
  );
  //fake clock that happends at the end of the posedge reservation station
  input clk;
  //the inputs from the reservation station
  input [2:0] op_code_in;
  input [2:0] d_select_in;
  input [7:0] d_select_shift_in;
  input [31:0] abus_data_in;
  input [31:0] bbus_data_in;
  //flag to determine if the execution unit is busy
  output reg is_busy;
  //flag for the regfile to verify it only accepts the final value at the correct time
  output reg valid_data;
  //the actual outputs for above, but in output form
  output reg [31:0] dbus_data_out;
  output reg [2:0] d_select_out;
  output reg [7:0] d_select_shift_out;
  //counter to use for determining the "cycle" of execution
  reg [31:0] counter;
  
  initial begin
    //set all the stuffs to 0
    is_busy = 0;
    valid_data = 0;
    dbus_data_out = 0;
    d_select_out = 0;
    d_select_shift_out = 0;
    counter = 0;
  end
  //the clock is actually the fake clock from the reservation station
  always @(posedge clk) begin
    valid_data = 0;
    if(op_code_in > 0) begin
      counter = counter + 1;
      if(!is_busy)begin
        //set the unit to busy
        is_busy = 1;
        //set the index outputs from the inputs
        d_select_out = d_select_in;
        d_select_shift_out = d_select_shift_in;
        case(ID)
          2'b00: begin
            //integer execution unit
            //nothing yet...
          end
          2'b01: begin
            //FP multiplier unit
            case(op_code_in)
              3'b100: begin
                //multing floating point
                dbus_data_out = abus_data_in * bbus_data_in;
              end
            endcase
          end
          2'b10: begin
            //FP adder unit
            case(op_code_in)
              3'b011: begin
                //add floating point
                dbus_data_out = abus_data_in + bbus_data_in;
              end
            endcase
          end
        endcase
      end
    end
    if(counter == CYCLE_TIME) begin
      //reset the counter and the busy flag
      is_busy = 0;
      counter = 0;
      //set the write data flag to high
      //the reg will pick it up at the neg edge
      valid_data = 1;
    end
  end
endmodule

//the module for dealing with the memory
module memory_unit();
  
endmodule

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
  input clk,
  input validData
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
    .clk(clk),
    .validData(validData)
    );
endmodule

module DNegflipFlop(dbus, abus, Dselect, Bselect, Aselect, bbus, clk, busySelect, isBusy, validData);
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
  input validData;
  
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
    if(Dselect && validData) begin
      data = dbus;
      isBusy = 0;
    end
  end
  //if this register has a or b select high, update the a and b bus
  assign abus = Aselect? data : 32'hzzzzzzzz;
  assign bbus = Bselect? data : 32'hzzzzzzzz;
endmodule
