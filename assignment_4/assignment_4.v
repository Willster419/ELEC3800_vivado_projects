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

/*
ID is as follows:
00 = integer unit
01 = FP multiplier unit
10 = FP adder unit
11 = load/store unit
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
  //connects the mux to the regfile and reservation statrions
  wire [2:0] cdbus_dest;
  wire [7:0] cdbus_dest_shift;
  wire [31:0] cdbus_data;
  wire cdbus_valid_data;
  
  //wires connecting the regfile to the reservation station
  wire [31:0] abus_wire_ld_st;
  wire [31:0] abus_wire_add;
  wire [31:0] abus_wire_mult;
  wire [31:0] abus_wire_int;
  wire [31:0] bbus_wire_ld_st;
  wire [31:0] bbus_wire_add;
  wire [31:0] bbus_wire_mult;
  wire [31:0] bbus_wire_int;
  wire [7:0] a_select_wire_ld_st;
  wire [7:0] a_select_wire_add;
  wire [7:0] a_select_wire_mult;
  wire [7:0] a_select_wire_int;
  wire [7:0] b_select_wire_ld_st;
  wire [7:0] b_select_wire_add;
  wire [7:0] b_select_wire_mult;
  wire [7:0] b_select_wire_int;
  wire [7:0] busy_bus;
  
  //wires connecting the reservation stations to the execution units
  //FP_ADD
  wire [2:0] rs_ex_fp_op_code;
  wire [2:0] rs_ex_fp_d_select;
  wire [7:0] rs_ex_fp_d_select_shift;
  wire [31:0] rs_ex_fp_abus_data;
  wire [31:0] rs_ex_fp_bbus_data;
  wire rs_ex_fp_add_is_busy;
  //FP_MULT
  wire [2:0] rs_ex_fp_mult_op_code;
  wire [2:0] rs_ex_fp_mult_d_select;
  wire [7:0] rs_ex_fp_mult_d_select_shift;
  wire [31:0] rs_ex_fp_mult_abus_data;
  wire [31:0] rs_ex_fp_mult_bbus_data;
  wire rs_ex_fp_mult_is_busy;
  //INT
  wire [2:0] rs_ex_int_op_code;
  wire [2:0] rs_ex_int_d_select;
  wire [7:0] rs_ex_int_d_select_shift;
  wire [31:0] rs_ex_int_abus_data;
  wire [31:0] rs_ex_int_bbus_data;
  wire rs_ex_int_is_busy;
  //LOAD
  wire [2:0] rs_ex_ld_op_code;
  wire [2:0] rs_ex_ld_d_select;
  wire [7:0] rs_ex_ld_d_select_shift;
  wire [31:0] rs_ex_ld_abus_data;
  wire [31:0] rs_ex_ld_bbus_data;
  //wire rs_ex_ld_is_busy;
  //STORE
  wire [2:0] rs_ex_st_op_code;
  wire [2:0] rs_ex_st_d_select;
  wire [7:0] rs_ex_st_d_select_shift;
  wire [31:0] rs_ex_st_abus_data;
  wire [31:0] rs_ex_st_bbus_data;
  //wire rs_ex_st_is_busy;
  wire rs_ex_ld_st_is_busy;
  
  //wires connecting the execution units to the mux
  //FP_ADD
  wire FP_add_mux_valid_data;
  wire [2:0] FP_add_mux_d_select;
  wire [7:0] FP_add_mux_d_select_shift;
  wire [31:0] FP_add_mux_data;
  wire FP_add_mux_stall;
  //FP_MULT
  wire FP_mult_mux_valid_data;
  wire [2:0] FP_mult_mux_d_select;
  wire [7:0] FP_mult_mux_d_select_shift;
  wire [31:0] FP_mult_mux_data;
  wire FP_mult_mux_stall;
  //INT
  wire int_mux_valid_data;
  wire [2:0] int_mux_d_select;
  wire [7:0] int_mux_d_select_shift;
  wire [31:0] int_mux_data;
  wire int_mux_stall;
  //LOAD/STORE
  wire mem_mux_valid_data;
  wire [2:0] mem_mux_d_select;
  wire [7:0] mem_mux_d_select_shift;
  wire [31:0] mem_mux_data;
  wire mem_mux_stall;
  
  //the reg flags for the execution units, if selected for the incoming deququed instruction
  reg load_selected_flag;
  reg store_selected_flag;
  reg FP_add_selected_flag;
  reg FP_mult_selected_flag;
  reg int_selected_flag;
  
  //the wires for connecting the flags if RS is full
  wire load_full_flag;
  wire store_full_flag;
  wire FP_mult_full_flag;
  reg int_full_full_flag;
  wire FP_add_full_flag;
  
  //the wires for connecting the valid input flags of the RS mem/load to the mux
  wire RS_load_valid_data;
  wire RS_store_valid_data;
  
  //wires for connecting the additional memory components
  wire [2:0] RS_load_mem_ofset;//b select
  wire [2:0] RS_store_mem_ofset;//b select
  wire [31:0] RS_load_address;//a data
  wire [31:0] RS_store_address;//a data
  
  wire RS_store_mux_stall;
  wire [31:0] RS_store_data;//dbus data
  wire [2:0] RS_load_dest;
  wire [7:0] RS_load_dest_shift;
  
  wire [2:0] mem_ex_d_select;
  wire [7:0] mem_ex_d_select_shift;
  wire [2:0] mem_ex_b_offset;
  wire [31:0] mem_ex_dbus_data;
  wire [31:0] mem_ex_abus_address;
  wire [2:0] mem_ex_op_code;
  
  //the reg as the instruction queue
  //first bracket is how wide each register is
  //second bracket is now many in the array
  //we want 6 instruction queues of 12 bits wide
  reg [11:0] instruction_queue [5:0];
  reg [11:0] current_instruction;
  
  //the memory interfacing
  wire [31:0] memory_address;
  reg [31:0] memory [3:0];
  wire [2:0] load_store;
  wire [31:0] store_data;
  reg [31:0] load_data;
  
  //counter for the dequeue for loop
  integer i;
  
  //the fake clocks used as delays
  reg fake_rs_clock;
  wire fake_mux_clock;
  wire fake_mux_snoop_clock;
  wire fake_meme_RS_mux_clock;
  
  //the control bit for setting the high bit for the regfile if the dest reg in use
  reg [7:0] busy_select_shift;

  //register module instance
  regfile best_regfile_name_ever
  (
    //ins
    .clk(clk), .AselectAdd(a_select_wire_add), .AselectInt(a_select_wire_int), .AselectMult(a_select_wire_mult),
    .AselectLdSt(a_select_wire_ld_st), .BselectAdd(b_select_wire_add), .BselectInt(b_select_wire_int), .BselectMult(b_select_wire_mult),
    .BselectLdSt(b_select_wire_ld_st), .busySelect(busy_select_shift),
    .Dselect(cdbus_dest_shift), .dbus(cdbus_data), .validData(cdbus_valid_data),
    //outs
    .busyBus(busy_bus), .abusAdd(abus_wire_add),
    .abusMult(abus_wire_mult),
    .abusInt(abus_wire_int),
    .abusLdSt(abus_wire_ld_st),    .bbusLdSt(bbus_wire_ld_st),.bbusMult(bbus_wire_mult),.bbusAdd(bbus_wire_add),.bbusInt(bbus_wire_int)
  );
  
  //reservation station instance for added
  //setting BUS_LENGTH to 2 means it makes 3 of them, indexed 0-2
  //ID=010=ADD
  reservation_station #(.BUS_LENGTH(2),.ID(3'b010)) FP_add_station
  (
    //ins
    .clk(clk), .fake_clock(fake_rs_clock), .fake_mux_clock(fake_mux_snoop_clock), .station_selected(FP_add_selected_flag),
    .opbus_op(opbus_opcode), .opbus_dest(opbus_dest), .opbus_src_a(opbus_src_a), .opbus_src_b(opbus_src_b), .abus_in(abus_wire_add),
    .bbus_in(bbus_wire_add), .busy_bus(busy_bus), .execution_unit_busy(rs_ex_fp_add_is_busy), .cdbus_dest(cdbus_dest),
    .cdbus_dest_shift(cdbus_dest_shift), .cdbus_dest_data(cdbus_data), .cdbus_valid(cdbus_valid_data),
    //outs
    .a_select_out(a_select_wire_add), .b_select_out(b_select_wire_add), .station_full(FP_add_full_flag), .d_select_out(rs_ex_fp_d_select),
    .d_select_out_shift(rs_ex_fp_d_select_shift), .abus_out(rs_ex_fp_abus_data), .bbus_out(rs_ex_fp_bbus_data),
    .op_code_out(rs_ex_fp_op_code)
  );
  
  //reservation station instance for mult
  //setting BUS_LENGTH to 1 means it makes 2 of them, indexed 0-1
  //ID=001=MULT
  reservation_station #(.BUS_LENGTH(1),.ID(3'b001)) FP_mult_station
  (
    //ins
    .clk(clk), .fake_clock(fake_rs_clock), .fake_mux_clock(fake_mux_snoop_clock), .station_selected(FP_mult_selected_flag),
    .opbus_op(opbus_opcode), .opbus_dest(opbus_dest), .opbus_src_a(opbus_src_a), .opbus_src_b(opbus_src_b), .abus_in(abus_wire_mult),
    .bbus_in(bbus_wire_mult), .busy_bus(busy_bus), .execution_unit_busy(rs_ex_fp_mult_is_busy), .cdbus_dest(cdbus_dest),
    .cdbus_dest_shift(cdbus_dest_shift), .cdbus_dest_data(cdbus_data), .cdbus_valid(cdbus_valid_data),
    //outs
    .a_select_out(a_select_wire_mult), .b_select_out(b_select_wire_mult), .station_full(FP_mult_full_flag), .d_select_out(rs_ex_fp_mult_d_select),
    .d_select_out_shift(rs_ex_fp_mult_d_select_shift), .abus_out(rs_ex_fp_mult_abus_data), .bbus_out(rs_ex_fp_mult_bbus_data),
    .op_code_out(rs_ex_fp_mult_op_code)
  );
  
  //reservation station instance for load
  //setting BUS_LENGTH to 2 means it makes 3 of them, indexed 0-2
  //ID=011=ST
  reservation_station #(.BUS_LENGTH(2),.ID(3'b011)) store_station
  (
    //ins
    .clk(clk), .fake_clock(fake_rs_clock), .fake_mux_clock(fake_mux_snoop_clock), .station_selected(store_selected_flag),
    .opbus_op(opbus_opcode), .opbus_dest(opbus_dest), .opbus_src_a(opbus_src_a), .opbus_src_b(opbus_src_b), .abus_in(abus_wire_ld_st),
    .bbus_in(bbus_wire_ld_st), .busy_bus(busy_bus), .execution_unit_busy(rs_ex_ld_st_is_busy), .cdbus_dest(cdbus_dest),
    .cdbus_dest_shift(cdbus_dest_shift), .cdbus_dest_data(cdbus_data), .cdbus_valid(cdbus_valid_data), .store_mux_stall(RS_store_mux_stall),
    //outs
    .a_select_out(a_select_wire_ld_st), .b_select_out(b_select_wire_ld_st), .station_full(store_full_flag), .d_select_out(rs_ex_st_d_select),
    .d_select_out_shift(rs_ex_st_d_select_shift), .abus_out(RS_store_address), .bbus_out(RS_store_data),
    .op_code_out(rs_ex_st_op_code), .memory_offset_out(RS_store_mem_ofset), .valid_data(RS_store_valid_data)
  );
  
  //reservation station instance for store
  //setting BUS_LENGTH to 2 means it makes 3 of them, indexed 0-2
  //ID=100=LD
  reservation_station #(.BUS_LENGTH(2),.ID(3'b100)) load_station
  (
    //ins
    .clk(clk), .fake_clock(fake_rs_clock), .fake_mux_clock(fake_mux_snoop_clock), .station_selected(load_selected_flag),
    .opbus_op(opbus_opcode), .opbus_dest(opbus_dest), .opbus_src_a(opbus_src_a), .opbus_src_b(opbus_src_b), .abus_in(abus_wire_ld_st),
    .bbus_in(bbus_wire_ld_st), .busy_bus(busy_bus), .execution_unit_busy(rs_ex_ld_st_is_busy), .cdbus_dest(cdbus_dest),
    .cdbus_dest_shift(cdbus_dest_shift), .cdbus_dest_data(cdbus_data), .cdbus_valid(cdbus_valid_data),
    //outs
    .a_select_out(a_select_wire_ld_st), .b_select_out(b_select_wire_ld_st), .station_full(load_full_flag), .d_select_out(RS_load_dest),
    .d_select_out_shift(RS_load_dest_shift), .abus_out(RS_load_address), .bbus_out(rs_ex_ld_bbus_data),
    .op_code_out(rs_ex_ld_op_code), .trigger_exes(fake_meme_RS_mux_clock), .memory_offset_out(RS_load_mem_ofset),
    .valid_data(RS_load_valid_data)
  );
  
  //mux instance for joining the two reservation stations
  partly_smart_mux psmux
(
  //in
  .fake_clock(fake_meme_RS_mux_clock), .load_d_select(RS_load_dest), .load_d_select_shift(RS_load_dest_shift),
  .load_address(RS_load_address), .load_offset(RS_load_mem_ofset), .store_dbus_data(RS_store_data), .store_address(RS_store_address),
  .store_offset(RS_store_mem_ofset), .valid_load_data(RS_load_valid_data), .valid_store_data(RS_store_valid_data),
  .load_op_code(rs_ex_ld_op_code), .store_op_code(rs_ex_st_op_code), .execution_unit_stall(rs_ex_ld_st_is_busy), .stall_by_mux(mem_mux_stall),
  //out
  .store_stall(RS_store_mux_stall), .exec_d_select(mem_ex_d_select), .exec_d_select_shift(mem_ex_d_select_shift),
  .exec_b_offset(mem_ex_b_offset), .exec_dbus_data(mem_ex_dbus_data), .exec_abus_address(mem_ex_abus_address), .exec_op_code(mem_ex_op_code)
);
  
  //execution unit instance for loading/storing
  //ID=11=LD/ST
  execution_unit #(.CYCLE_TIME(2),.ID(2'b11)) load_store_unit
  (
    //ins
    .clk(clk), .op_code_in(mem_ex_op_code), .d_select_in(mem_ex_d_select), .d_select_shift_in(mem_ex_d_select_shift),
    .abus_data_in(mem_ex_abus_address), .stall_by_mux(mem_mux_stall), .offset_in(mem_ex_b_offset), .memory_in(load_data),
    .store_dbus_data_in(mem_ex_dbus_data),
    //outs
    .is_busy(rs_ex_ld_st_is_busy), .valid_data(mem_mux_valid_data), .dbus_data_out(mem_mux_data),
    .d_select_out(mem_mux_d_select), .d_select_shift_out(mem_mux_d_select_shift), .memory_address(memory_address), .memory_out(store_data),
    .op_code_out(load_store)
  );
  
  //execution unit instance for adding
  //ID=10=FP_ADD
  execution_unit #(.CYCLE_TIME(3),.ID(2'b10)) FP_add_unit
  (
    //ins
    .clk(clk), .op_code_in(rs_ex_fp_op_code), .d_select_in(rs_ex_fp_d_select), .d_select_shift_in(rs_ex_fp_d_select_shift),
    .abus_data_in(rs_ex_fp_abus_data), .bbus_data_in(rs_ex_fp_bbus_data), .stall_by_mux(FP_add_mux_stall),
    //outs
    .is_busy(rs_ex_fp_add_is_busy), .valid_data(FP_add_mux_valid_data), .dbus_data_out(FP_add_mux_data),
    .d_select_out(FP_add_mux_d_select), .d_select_shift_out(FP_add_mux_d_select_shift)
  );
  
  //execution unit instance for multing
  //ID=01=FP_MULT
  execution_unit #(.CYCLE_TIME(5),.ID(2'b01)) FP_mult_unit
  (
    //ins
    .clk(clk), .op_code_in(rs_ex_fp_mult_op_code), .d_select_in(rs_ex_fp_mult_d_select), .d_select_shift_in(rs_ex_fp_mult_d_select_shift),
    .abus_data_in(rs_ex_fp_mult_abus_data), .bbus_data_in(rs_ex_fp_mult_bbus_data), .stall_by_mux(FP_mult_mux_stall),
    //outs
    .is_busy(rs_ex_fp_mult_is_busy), .valid_data(FP_mult_mux_valid_data), .dbus_data_out(FP_mult_mux_data),
    .d_select_out(FP_mult_mux_d_select), .d_select_shift_out(FP_mult_mux_d_select_shift), .fake_clock(fake_mux_clock)
  );
  
  //mux instance
  smart_mux smux
  (
    //in
    .fake_clock(fake_mux_clock), .mem_valid(mem_mux_valid_data), .FP_mult_valid(FP_mult_mux_valid_data),
    .FP_add_valid(FP_add_mux_valid_data), .int_valid(int_mux_valid_data), .mem_d_select(mem_mux_d_select),
    .FP_mult_d_select(FP_mult_mux_d_select), .FP_add_d_select(FP_add_mux_d_select), .int_d_select(int_mux_d_select),
    .mem_d_select_shift(mem_mux_d_select_shift), .FP_mult_d_select_shift(FP_mult_mux_d_select_shift),
    .FP_add_d_select_shift(FP_add_mux_d_select_shift), .int_d_select_shift(int_mux_d_select_shift), .mem_data(mem_mux_data),
    .FP_mult_data(FP_mult_mux_data), .FP_add_data(FP_add_mux_data), .int_data(int_mux_data),
    //out
    .mem_stall(mem_mux_stall), .FP_mult_stall(FP_mult_mux_stall), .FP_add_stall(FP_add_mux_stall), .int_stall(int_mux_stall),
    .cdbus_d_select(cdbus_dest), .cdbus_d_select_shift(cdbus_dest_shift), .cdbus_data(cdbus_data), .cdbus_valid_data(cdbus_valid_data),
    .fake_mux_output_clock(fake_mux_snoop_clock)
  );
  
  initial begin
    //set all the execution flags to 0
    store_selected_flag = 0;
    load_selected_flag = 0;
    FP_add_selected_flag = 0;
    FP_mult_selected_flag = 0;
    int_selected_flag = 0;
    //mem_full_flag = 0;
    //FP_add_full_flag = 0;
    //FP_mult_full_flag = 0;
    int_full_full_flag = 0;
    //set the fake clocks
    fake_rs_clock = 0;
    //fake_mux_clock = 0;
    //set the busy_select to 0
    busy_select_shift = 8'b0;
    //set the current instructin to nothing
    current_instruction = 12'b0;
    load_data = 32'bz;
    /*
    Current Instruction List:
    NOP   000
    LD    001
    ST    010
    ADDF  011
    MULTF 100
    */
    //fill the instruction queue
    instruction_queue[0] [11:0] = 12'b100_010_001_000;//mult, r2, r1, r0 (r2=0)
    instruction_queue[1] [11:0] = 12'b011_011_010_001;//add, r3, r2, r1 (r3=1)
    instruction_queue[2] [11:0] = 12'b011_100_001_011;//add, r4, r1, r3 (r4=2)
    instruction_queue[3] [11:0] = 12'b000_000_000_000;//
    instruction_queue[4] [11:0] = 12'b000_000_000_000;//
    instruction_queue[5] [11:0] = 12'b000_000_000_000;//
    
    //memory pre-load
    memory[0] [31:0] = 32'hDEADBEEF;
    memory[1] [31:0] = 32'b0;
    memory[2] [31:0] = 32'b0;
    memory[3] [31:0] = 32'b0;
  end
  
  always @(posedge clk) begin
    //decode the instruction
    //set the flags to 0
    store_selected_flag = 0;
    load_selected_flag = 0;
    FP_add_selected_flag = 0;
    FP_mult_selected_flag = 0;
    int_selected_flag = 0;
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
        //don't select any execution units...
      end
      3'b001: begin
        //LOAD
        load_selected_flag = (load_full_flag)? 0 : 1;
      end
      3'b010: begin
        //STORE
        store_selected_flag = (store_full_flag)? 0 : 1;
      end
      3'b011: begin
        //ADDF
        FP_add_selected_flag = (FP_add_full_flag)? 0 : 1;
      end
      3'b100: begin
        //MULTF
        FP_mult_selected_flag = (FP_mult_full_flag)? 0 : 1;
      end
    endcase
    if(store_selected_flag||load_selected_flag||FP_add_selected_flag||FP_mult_selected_flag||int_selected_flag) begin
      //set the busyBus for the regfile
      //if the destination is r0, don't bother cause it's the 0 register
      //also don't set it for stores
      if(!store_selected_flag) begin
        busy_select_shift = (current_instruction[8:6] == 3'b0)? 8'b0 : 8'b00000001 << current_instruction[8:6];
      end
      //busy_select_shift = 8'b00000001 << current_instruction[8:6];
      //shift the entries down from the queue
      //act as the dequeue
      for(i = 0; i < 5; i=i+1) begin
        instruction_queue[i] = instruction_queue[i+1];
      end
      //and fill the last one with zeros
      instruction_queue[5] = 12'b0;
    end
    //invert the clock so that it #triggers the reservation station
    //while also giving the assigns enough time to work
    fake_rs_clock = ~fake_rs_clock;
  end
  
  //memory address updating block
  always @(memory_address) begin
    //filter out all the z and x
    $display("request for memory started, memory_address=%d, load_store=%d", memory_address, load_store);
    if((memory_address >= 0) && (load_store > 3'b000)) begin
      load_data = 32'bz;
      case(load_store)
        3'b001: begin
          //load from memory
          load_data = memory[memory_address];
        end
        3'b010: begin
          //store to memory
          memory[memory_address] = store_data;
        end
      endcase
    end
  end
  
  assign opbus_opcode = (store_selected_flag||load_selected_flag||FP_add_selected_flag||FP_mult_selected_flag||int_selected_flag)? current_instruction[11:9] : 3'bz;
  assign opbus_dest = (store_selected_flag||load_selected_flag||FP_add_selected_flag||FP_mult_selected_flag||int_selected_flag)? current_instruction[8:6] : 3'bz;
  assign opbus_src_a = (store_selected_flag||load_selected_flag||FP_add_selected_flag||FP_mult_selected_flag||int_selected_flag)? current_instruction[5:3] : 3'bz;
  assign opbus_src_b = (store_selected_flag||load_selected_flag||FP_add_selected_flag||FP_mult_selected_flag||int_selected_flag)? current_instruction[2:0] : 3'bz;
  //assign busy_select_shift = (mem_selected_flag||FP_add_selected_flag||FP_mult_selected_flag||int_selected_flag)? 8'b00000001 << opbus_dest : 8'b0;
endmodule

//the module for creating the reservation stations
//default data iwdth is 1, can be changed to allow more width
module reservation_station #(parameter BUS_LENGTH = 1, ID=3'b000)
  (
    //ins
    clk, fake_clock, fake_mux_clock, station_selected, opbus_op, opbus_dest, opbus_src_a, opbus_src_b, abus_in, bbus_in, busy_bus,
    execution_unit_busy, cdbus_dest, cdbus_dest_shift, cdbus_dest_data, cdbus_valid, store_mux_stall,
    //outs
    a_select_out, b_select_out, d_select_out, d_select_out_shift, abus_out, bbus_out, op_code_out, station_full, trigger_exes,
    memory_offset_out, valid_data
  );
  //the regular good'ol clock
  input clk;
  //the delayed clock for triggering the alwyas block
  //it's the last thing done in the always block for the instruction dequeuing
  input fake_clock;
  input fake_mux_clock;
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
  //the common data bus for snooping
  input [2:0] cdbus_dest;
  input [7:0] cdbus_dest_shift;
  input [31:0] cdbus_dest_data;
  input cdbus_valid;
  input store_mux_stall;
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
  //the offset for load and store (actually b_src)
  output reg [2:0] memory_offset_out;
  output reg valid_data;
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
  reg[BUS_LENGTH:0] a_b_equal;
  //the counter to traverse the array of stations
  //used as the index location for where to enqueue the instruction
  reg[31:0] counter;
  reg[31:0] counter2;
  reg[31:0] counter3;
  
  //indexs saying which station index a and b data to update at the positive edge
  reg[31:0] a_update_index;
  reg[31:0] b_update_index;
  reg a_update_index_flag;
  reg b_update_index_flag;
  reg output_bus_touched;
  
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
    output_bus_touched = 0;
    memory_offset_out = 3'bz;
    valid_data = 0;
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
      a_b_equal[counter] = 0;
      counter = counter+1;
    end
    counter = 0;
    counter2 = 0;
    counter3 = 0;
  end
  
  //use fake_clock to give a little delay
  //in theory it's listinigh for the change and therefore
  //won't *have* to happen during the blocking part
  always @(fake_clock) begin
    //only run this if the station is not full
    counter = 0;
    counter2 = 0;
    counter3 = 0;
    a_update_index_flag = 0;
    b_update_index_flag = 0;
    //extra if statement check, in theory not needed
    if(!station_full) begin
      //use a loop to incriment the counter to determine the next available station
      //at this point we know that the station has at least one slot available
      if(station_selected) begin:enqueue_op_break
        repeat(BUS_LENGTH+1) begin:enqueue_op_continue
          if(!station_in_use[counter]) begin
            $display("RS ID=%d, station %d is not in use, filling", ID, counter);
            //update hte value in that counter
            op_code[counter] [2:0] = opbus_op;
            dest_reg_shift[counter] [7:0] = 8'b00000001 << opbus_dest;
            dest_reg[counter] [2:0] = opbus_dest;
            src_a[counter] [2:0] = opbus_src_a;
            src_b[counter] [2:0] = opbus_src_b;
            src_a_shift[counter] [7:0] = 8'b00000001 << opbus_src_a;
            src_b_shift[counter] [7:0] = 8'b00000001 << opbus_src_b;
            a_b_equal[counter] = 0;
            operation_data_a_ready[counter] = 0;
            operation_data_b_ready[counter] = 0;
            station_in_use[counter] = 1;
            //also check if it's the last reservation station
            if(counter == BUS_LENGTH) begin
              station_full = 1;
              $display("RS ID=%d, reservation station is full", ID);
            end
            //and disable the loop to prevent accidental updating any more values
            disable enqueue_op_break;
          end
          counter = counter+1;
        end
      end
    end
  end
  
  always @(fake_mux_clock) begin
    counter = 0;
    //use a loop to incriment the counter  for checking if data is ready
    begin:data_check_break
      repeat(BUS_LENGTH+1) begin:data_check_continue
        if(station_in_use[counter]) begin
          $display("RS ID=%d, station %d is in use", ID, counter);
          //check if the value for each src is ready
          //first check via snooping
          if(!operation_data_a_ready[counter]) begin
            $display("RS ID=%d, data for a (regsiter %d) of station %d is not ready", ID, src_a[counter], counter);
            //if the snopped data is relavent to this reservation station
            //$display("testing for common data bus: cdbus_dest=%d, src_a[counter]=%d",cdbus_dest,src_a[counter]);
            if(dest_reg[counter] == src_a[counter])begin
              $display("RS ID=%d, dest_reg and src_a match (%d) for station %d, ignoring",ID, src_a[counter],counter);
              operation_data_a_ready[counter]=1;
            end
            else if(cdbus_dest == src_a[counter]) begin
              $display("RS ID=%d, cdbus says data is relavent (destination register %d) for source a at station %d ", ID, cdbus_dest, counter);
              //update the value with the snopped value and set data ready flag
              abus_data[counter] = cdbus_dest_data;
              operation_data_a_ready[counter]=1;
              //TODO:
              //but also check down below the queue that any destination registers don't match (WAW)
              //loop to check down
              //if dest==src_a
              //op_data_a_ready = 0;
              if(counter > 0) begin: WAW_check_break_a
                counter3 = counter-1;
                repeat(counter) begin
                  if(dest_reg[counter3] == src_a[counter])begin
                    $display("RS ID=%d, setting ready flag for source a of station %d back to false because hazard conflicts with destination of station %d", ID,counter,counter3);
                    operation_data_a_ready[counter]=0;
                  end
                  counter3 = counter3-1;
                end
              end
            end
            else if(!busy_bus[src_a[counter]]) begin
              $display("RS ID=%d, busybus says register %d for a is up to date for station %d", ID, src_a[counter], counter);
              //it is ready, set the output address of a
              //it will trigger the wire to put the value at the reg index onto the abus
              a_select_out = src_a_shift[counter];
              a_update_index = counter;
              //abus_data[counter] = abus_in;//don't do this until the posedge part
              operation_data_a_ready[counter]=1;
              a_update_index_flag = 1;
            end
          end
          //loads do not need this, stores need d,
          case(op_code[counter])
            3'b001: begin
              //set operation data of b to be ready. we don't care about it anyways
              operation_data_b_ready[counter]=1;
            end
            3'b010: begin
              //check it for d
              if(!operation_data_b_ready[counter]) begin
                $display("RS ID=%d, store data for d (regsiter %d) of station %d is not ready", ID, dest_reg[counter], counter);
                //if the snopped data is relavent to this reservation station
                if(cdbus_dest == dest_reg[counter]) begin
                  $display("RS ID=%d, cdbus says data is relavent (destination register %d) for load source d at station %d ", ID, dest_reg[counter], counter);
                  bbus_data[counter] = cdbus_dest_data;
                  operation_data_b_ready[counter]=1;
                  if(counter > 0) begin: WAW_check_break_b_store
                    counter3 = counter-1;
                    repeat(counter) begin
                      if(dest_reg[counter3] == dest_reg[counter])begin
                        $display("RS ID=%d, setting ready flag for source b of station %d back to false because hazard conflicts with destination of station %d", ID,counter,counter3);
                        operation_data_b_ready[counter]=0;
                      end
                      counter3 = counter3-1;
                    end
                  end
                end
                else if(!busy_bus[dest_reg[counter]]) begin
                  $display("RS ID=%d, busybus says register %d for b is up to date for station %d", ID, dest_reg[counter], counter);
                  //it is ready, set the output address of a
                  //it will trigger the wire to put the value at the reg index onto the abus
                  b_select_out = dest_reg_shift[counter];
                  b_update_index = counter;
                  //bbus_data[counter] = bbus_in;//don't do this until the posedge part
                  operation_data_b_ready[counter]=1;
                  b_update_index_flag = 1;
                end
              end
            end
            default: begin
              if(src_a[counter] == src_b[counter]) begin
                $display("RS ID=%d, src_a and b match(%d), setting match bit and copying data, station %d", ID, src_b[counter], counter);
                a_b_equal[counter] = 1;
                operation_data_b_ready[counter] = 1;
                b_update_index_flag = 1;
                b_update_index = counter;
              end
              else if(!operation_data_b_ready[counter]) begin
                $display("RS ID=%d, data for b (regsiter %d) of station %d is not ready", ID, src_b[counter], counter);
                //if the snopped data is relavent to this reservation station
                if(dest_reg[counter] == src_b[counter])begin
                  $display("RS ID=%d, dest_reg and src_b match (%d) for station %d, ignoring",ID, src_b[counter],counter);
                  operation_data_b_ready[counter]=1;
                end
                if(cdbus_dest == src_b[counter]) begin
                  $display("RS ID=%d, cdbus says data is relavent (destination register %d) for source b at station %d ", ID, src_b[counter], counter);
                  bbus_data[counter] = cdbus_dest_data;
                  operation_data_b_ready[counter]=1;
                  if(counter > 0) begin: WAW_check_break_b
                    counter3 = counter-1;
                    repeat(counter) begin
                      if(dest_reg[counter3] == src_b[counter])begin
                        $display("RS ID=%d, setting ready flag for source b of station %d back to false because hazard conflicts with destination of station %d", ID,counter,counter3);
                        operation_data_b_ready[counter]=0;
                      end
                      counter3 = counter3-1;
                    end
                  end
                end
                else if(!busy_bus[src_b[counter]]) begin
                  $display("RS ID=%d, busybus says register %d for b is up to date for station %d", ID, src_b[counter], counter);
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
          endcase
          
        end
        counter = counter+1;
      end
    end
  end
  
  always @(negedge clk) begin
    counter = 0;
    output_bus_touched = 0;
    valid_data = 0;
    //update the values from the data index saved earlier
    if(a_update_index_flag) begin
      abus_data[a_update_index] = abus_in;
    end
    if(b_update_index_flag) begin
      if(a_b_equal[counter]) begin
      bbus_data[b_update_index] = abus_in;
      end
      else begin
      bbus_data[b_update_index] = bbus_in;
      end
    end
    a_update_index_flag = 0;
    b_update_index_flag = 0;
    begin:data_output_break
      //only touch the output bus if you have to!
      repeat(BUS_LENGTH+1) begin:data_output_continue
        if(station_in_use[counter] && operation_data_a_ready[counter] && operation_data_b_ready[counter] && !execution_unit_busy) begin
          if((ID==3'b010) && (store_mux_stall))begin
            $display("RS ID=%d, stalled due to waiting on mux", ID);
            valid_data = 1;
            disable data_output_break;
          end
          //set all the stuff and touch the output buses
          $display("RS ID=%d, station %d is in use, and operation data is ready, dequeuing for execution", ID,counter);
          output_bus_touched = 1;
          valid_data = 1;
          abus_out = abus_data[counter];
          bbus_out = bbus_data[counter];
          d_select_out = dest_reg[counter];
          d_select_out_shift = dest_reg_shift[counter];
          op_code_out = op_code[counter];
          memory_offset_out = src_b[counter];
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
            a_b_equal[counter2] = a_b_equal[counter2+1];
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
          a_b_equal[BUS_LENGTH] = 0;
          //and also set the station full flag to low
          if(station_full) begin
            $display("RS ID=%d, reservation station is no longer full", ID);
          end
          station_full = 0;
          disable data_output_break;
        end
        counter = counter+1;
      end
      //else close the output to stop the execution units
      if(!output_bus_touched) begin
        if((ID==3'b011)||(ID==3'b100)) begin
          $display("RS ID=%d, no instructions ready for execution unit, setting valid data to false", ID);
          valid_data =0;
        end
        else begin
          $display("RS ID=%d, no instructions ready for execution unit, closing outputs", ID);
          abus_out = 32'bz;
          bbus_out = 32'bz;
          d_select_out = 3'bz;
          d_select_out_shift = 8'bz;
          op_code_out = 3'bz;
        end
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
11 = load/store unit
*/
/*
Current Instruction List:
NOP   000
LD    001
ST    010
ADDF  011
MULTF 100
*/
module execution_unit #(parameter CYCLE_TIME = 1, ID = 2'b00)
  (
    //in
    clk, op_code_in, d_select_in, d_select_shift_in, abus_data_in, bbus_data_in, stall_by_mux, offset_in, memory_in, store_dbus_data_in,
    //out
    is_busy, valid_data, dbus_data_out, d_select_out, d_select_shift_out, fake_clock, memory_address, memory_out, op_code_out
  );
  //fake clock that happends at the end of the posedge reservation station
  //^not true
  input clk;
  //the inputs from the reservation station
  input [2:0] op_code_in;
  input [2:0] d_select_in;
  input [7:0] d_select_shift_in;
  input [31:0] abus_data_in;
  input [31:0] bbus_data_in;
  //the input from the mux if there's two or more requests for the cdb and one execution needs to stall
  input stall_by_mux;
  //the offset for load and store (actually the b instruction)
  input [2:0] offset_in;
  //the memory input wire
  input [31:0] memory_in;
  //the data from the regfile to store, from the dbus
  input [31:0] store_dbus_data_in;
  //flag to determine if the execution unit is busy
  output reg is_busy;
  //flag for the regfile to verify it only accepts the final value at the correct time
  output reg valid_data;
  //the actual outputs for above, but in output form
  output reg [31:0] dbus_data_out;
  output reg [2:0] d_select_out;
  output reg [7:0] d_select_shift_out;
  output reg fake_clock;
  //the memory address for the memory storing or loading
  //NOTE: it is 32 bit like the rest of data, but only use 0-3 for memory testing
  output reg [31:0] memory_address;
  //the actual value to store to the memory
  output reg [31:0] memory_out;
  output reg [2:0] op_code_out;
  //counter to use for determining the "cycle" of execution
  reg [31:0] counter;
  reg [31:0] counter_backup;
  reg [2:0] saved_op_code;
  
  initial begin
    //set all the stuffs to 0
    is_busy = 0;
    valid_data = 0;
    dbus_data_out = 0;
    d_select_out = 0;
    d_select_shift_out = 0;
    memory_address = 32'bz;
    memory_out = 32'bz;
    fake_clock = 0;
    counter = 0;
    counter_backup = 0;
    op_code_out = 3'bz;
    saved_op_code = 3'bz;
  end
  
  always @(posedge clk) begin
    valid_data = 0;
    memory_address = 31'bz;
    memory_out = 32'bz;
    op_code_out = 3'bz;
    if(is_busy) begin
      counter = counter + 1;
      $display("execution unit %d is busy, counter=%d",ID, counter);
    end
    if((!is_busy) && (op_code_in > 0)) begin
      $display("execution unit %d is not busy, accepts new instruction.",ID);
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
        2'b11: begin
          //load/store unit
          case(op_code_in)
            3'b001: begin
              //load (from "memory", to regfile)
              //will trigger memory address to return the value
              op_code_out = op_code_in;
              saved_op_code = op_code_in;
              memory_address = abus_data_in + offset_in;
            end
            3'b010: begin
              //store (to "memory", from regfile)
              op_code_out = op_code_in;
              saved_op_code = op_code_in;
              memory_out = store_dbus_data_in;
              memory_address = abus_data_in + offset_in;
            end
          endcase
        end
      endcase
    end
    //if it equals, the exeuction unit is done
    //however, the mux may just have gotten two inputs
    if(counter == CYCLE_TIME) begin
      $display("execution complete for execution unit %d, valid data is high",ID);
      if(saved_op_code == 3'b001) begin
        //actually load the data
        dbus_data_out = memory_in;
        saved_op_code = 3'bz;
      end
      else if(saved_op_code == 3'b010) begin
        //store should have no regfile writeback, write to nothing register
        dbus_data_out = 32'b0;
        d_select_out = 3'b0;
        d_select_shift_out = 8'b00000001;
        saved_op_code = 3'bz;
      end
      //reset the counter and the busy flag
      is_busy = 0;
      counter_backup = counter;
      counter = 0;
      //set the write data flag to high
      //the reg will pick it up at the neg edge
      valid_data = 1;
    end
    //hear means that it was stalled by the mux not being ready
    else if(counter > CYCLE_TIME) begin
      //valid data needs to stay true for mux to work...
      $display("(posedge clk) execution unit %d stalled by mux, setting valid back to true", ID);
      valid_data = 1;
    end
    fake_clock = ~fake_clock;
  end
  
  always @(posedge stall_by_mux) begin
    $display("(posedge stall_by_mux) stall_by_mux detected for execution unit %d",ID);
    is_busy = 1;
    counter = counter_backup;
  end
  
  always @(negedge stall_by_mux) begin
    if(counter > CYCLE_TIME) begin
      $display("(negedge stall_by_mux) stall_by_mux detected for execution unit %d with counter > CYCLE_TIME true",ID);
      //mux just put it's data on the bus, can set busy to false
      is_busy = 0;
      counter = 0;
      counter_backup = 0;
    end
  end
endmodule

//the mux to use as the bit arbitor
module smart_mux
(
  //in
  fake_clock, mem_valid, FP_mult_valid, FP_add_valid, int_valid, mem_d_select, FP_mult_d_select, FP_add_d_select,
  int_d_select, mem_d_select_shift, FP_mult_d_select_shift, FP_add_d_select_shift, int_d_select_shift, mem_data,
  FP_mult_data, FP_add_data, int_data,
  //out
  mem_stall, FP_mult_stall, FP_add_stall, int_stall, cdbus_d_select, cdbus_d_select_shift, cdbus_data, cdbus_valid_data,
  fake_mux_output_clock
);
  //the clock that is set at the end of the fp mult execution unit in hopes of getting a delay
  input fake_clock;
  //the 4 flags to state if we have valid input to process
  input mem_valid;
  input FP_mult_valid;
  input FP_add_valid;
  input int_valid;
  //the 4 d_select values
  input [2:0] mem_d_select;
  input [2:0] FP_mult_d_select;
  input [2:0] FP_add_d_select;
  input [2:0] int_d_select;
  //the 4 d_select_shift values
  input [7:0] mem_d_select_shift;
  input [7:0] FP_mult_d_select_shift;
  input [7:0] FP_add_d_select_shift;
  input [7:0] int_d_select_shift;
  //the 4 data values
  input [31:0] mem_data;
  input [31:0] FP_mult_data;
  input [31:0] FP_add_data;
  input [31:0] int_data;
  //output flags for the execution units if their data was accepted
  output reg mem_stall;
  output reg FP_mult_stall;
  output reg FP_add_stall;
  output reg int_stall;
  //the output for the common data bus
  output reg [2:0] cdbus_d_select;
  output reg [7:0] cdbus_d_select_shift;
  output reg [31:0] cdbus_data;
  output reg cdbus_valid_data;
  output reg fake_mux_output_clock;
  
  //reg to count how many inputs we just got
  reg [31:0] how_many_inputs;
  
  initial begin
    how_many_inputs = 0;
    mem_stall = 0;
    FP_mult_stall = 0;
    FP_add_stall = 0;
    int_stall = 0;
    cdbus_valid_data = 0;
    fake_mux_output_clock = 0;
  end
  
  always @(fake_clock) begin
    how_many_inputs = 0;
    //check how many inputs we actually have
    if(mem_valid)
      how_many_inputs = how_many_inputs +1;
    if(FP_mult_valid)
      how_many_inputs = how_many_inputs +1;
    if(FP_add_valid)
      how_many_inputs = how_many_inputs +1;
    if(int_valid)
      how_many_inputs = how_many_inputs +1;
    if(how_many_inputs == 0) begin
      $display("mux says 0 inputs, nothing to do");
      cdbus_valid_data = 0;
      cdbus_d_select = 3'bz;
      cdbus_d_select_shift = 8'bz;
      cdbus_data = 32'bz;
      mem_stall = 0;
      FP_mult_stall = 0;
      FP_add_stall = 0;
      int_stall = 0;
    end
    else if(how_many_inputs == 1) begin
      $display("mux says 1 inputs, set cdbus, no stalling required");
      mem_stall = 0;
      FP_mult_stall = 0;
      FP_add_stall = 0;
      int_stall = 0;
      cdbus_valid_data = 1;
      //only one of them has valid data, just find it and put it on the bus
      if(FP_mult_valid) begin
        cdbus_d_select = FP_mult_d_select;
        cdbus_d_select_shift = FP_mult_d_select_shift;
        cdbus_data = FP_mult_data;
      end
      else if(FP_add_valid) begin
        cdbus_d_select = FP_add_d_select;
        cdbus_d_select_shift = FP_add_d_select_shift;
        cdbus_data = FP_add_data;
      end
      else if(mem_valid) begin
        cdbus_d_select = mem_d_select;
        cdbus_d_select_shift = mem_d_select_shift;
        cdbus_data = mem_data;
      end
      else if(int_valid) begin
        cdbus_d_select = int_d_select;
        cdbus_d_select_shift = int_d_select_shift;
        cdbus_data = int_data;
      end
    end
    //go in the order of the if else blocks
    else if(how_many_inputs > 1) begin
      $display("mux says %d inputs, set cdbus, stalling required", how_many_inputs);
      $display("before arbitration, FP_mult_valid=%b, FP_add_valid=%b, mem_valid=%b, int_valid=%b",FP_mult_valid,FP_add_valid,mem_valid,int_valid);
      $display("before arbitration, FP_mult_stall=%b, FP_add_stall=%b, mem_stall=%b, int_stall=%b", FP_mult_stall, FP_add_stall, mem_stall,int_stall);
      if(FP_mult_valid) begin
        cdbus_d_select = FP_mult_d_select;
        cdbus_d_select_shift = FP_mult_d_select_shift;
        cdbus_data = FP_mult_data;
        mem_stall = mem_valid? 1 : 0;
        FP_add_stall = FP_add_valid? 1:0;
        int_stall = int_valid? 1:0;
      end
      else if(FP_add_valid) begin
        cdbus_d_select = FP_add_d_select;
        cdbus_d_select_shift = FP_add_d_select_shift;
        cdbus_data = FP_add_data;
        mem_stall = mem_valid? 1 : 0;
        FP_mult_stall = FP_mult_valid? 1:0;
        int_stall = int_valid? 1:0;
      end
      else if(mem_valid) begin
        cdbus_d_select = mem_d_select;
        cdbus_d_select_shift = mem_d_select_shift;
        cdbus_data = mem_data;
        FP_mult_stall = FP_mult_valid? 1 : 0;
        FP_add_stall = FP_add_valid? 1:0;
        int_stall = int_valid? 1:0;
      end
      $display("after arbitration, FP_mult_stall=%b, FP_add_stall=%b, mem_stall=%b, int_stall=%b", FP_mult_stall, FP_add_stall, mem_stall,int_stall);
    end
    if(how_many_inputs > 0) begin
      $display("writing to common data bus: dest=%d, data=%X", cdbus_d_select, cdbus_data);
    end
    fake_mux_output_clock = ~fake_mux_output_clock;
  end
endmodule

//the mux module for choosing between the load and store RS
module partly_smart_mux
(
  //in
  fake_clock, load_d_select, load_d_select_shift, load_address, load_offset, store_dbus_data, store_address, store_offset,
  valid_load_data, valid_store_data, load_op_code, store_op_code, execution_unit_stall, stall_by_mux,
  //out
  store_stall, exec_d_select, exec_d_select_shift, exec_b_offset, exec_dbus_data, exec_abus_address, exec_op_code
);
  //the fake clock from the address calculator
  input fake_clock;
  //the values from the reservation stations of load and store
  input [2:0] load_d_select;//d select
  input [7:0] load_d_select_shift;//d select shift
  input [31:0] load_address;//abus data
  input [2:0] load_offset;//b code
  input [2:0] store_offset;//b code
  input [31:0] store_dbus_data;//dbus data
  input [31:0] store_address;//abus data
  input valid_load_data;
  input valid_store_data;
  input [2:0] load_op_code;
  input [2:0] store_op_code;
  input execution_unit_stall;
  input stall_by_mux;
  //the outputs for stalling the store reservation station
  output reg store_stall;
  output reg [2:0] exec_d_select;
  output reg [7:0] exec_d_select_shift;
  output reg [2:0] exec_b_offset;
  output reg [31:0] exec_dbus_data;
  output reg [31:0] exec_abus_address;
  output reg [2:0] exec_op_code;
  
  initial begin
    store_stall = 0;
    exec_d_select = 3'bz;
    exec_d_select_shift = 8'bz;
    exec_b_offset = 3'bz;
    exec_dbus_data = 32'bz;
    exec_abus_address = 32'bz;
    exec_op_code = 3'bz;
  end
  
  reg [31:0] how_many_outputs;
  
  always @(fake_clock)begin
    if(execution_unit_stall && stall_by_mux) begin
      $display("partly smart mux stalled due to execution/mux stall");
    end
    else begin
      how_many_outputs = 0;
      if(valid_load_data > 0) begin
        how_many_outputs = how_many_outputs+1;
      end
      if(valid_store_data > 0) begin
        how_many_outputs = how_many_outputs+1;
      end
      if(how_many_outputs ==0) begin
        $display("memory mux, no load/store reservation stations to output");
        store_stall = 0;
        exec_d_select = 3'bz;
        exec_b_offset = 3'bz;
        exec_d_select_shift = 8'bz;
        exec_dbus_data = 32'bz;
        exec_abus_address = 32'bz;
        exec_op_code = 3'bz;
      end
      else if(how_many_outputs == 1)begin
        $display("memory mux, one load/store reservation stations to output");
        store_stall = 0;
        if(valid_load_data > 0) begin
          //not matter
          exec_dbus_data = 32'b0;
          //matter
          exec_b_offset = load_offset;
          exec_d_select = load_d_select;
          exec_d_select_shift = load_d_select_shift;
          exec_abus_address = load_address;
          exec_op_code = load_op_code;
        end
        else if(valid_store_data > 0) begin
          //not matter
          exec_d_select = 3'b0;
          exec_d_select_shift = 8'b00000001;
          //matter
          exec_b_offset = store_offset;
          exec_dbus_data = store_dbus_data;
          exec_abus_address = store_address;
          exec_op_code = store_op_code;
        end
      end
      else if(how_many_outputs > 1)begin
        $display("memory mux, two load/store reservation stations to output, stall stores");
        store_stall = 1;
        //not matter
        exec_dbus_data = 32'b0;
        //matter
        exec_b_offset = load_offset;
        exec_d_select = load_d_select;
        exec_d_select_shift = load_d_select_shift;
        exec_abus_address = load_address;
        exec_op_code = load_op_code;
      end
    end
    
  end
endmodule

//the reg file
//registers are 32 bit length
//there are 8 of them
//register 0 is the null register
/*
.AselectAdd(a_select_wire_add), .AselectInt(a_select_wireInt), .AselectMult(a_select_wire_mult),
    .AselectLdSt(a_select_wire_ld_st), .BselectAdd(b_select_wire_add), .BselectInt(b_select_wire_int), .BselectMult(b_select_wire_mult),
    .BselectLdSt(b_select_wire_ld_st),
    */
module regfile(
  input [7:0] AselectAdd,//select the register index to read from to store into abus
  input [7:0] AselectInt,//select the register index to read from to store into abus
  input [7:0] AselectMult,//select the register index to read from to store into abus
  input [7:0] AselectLdSt,//select the register index to read from to store into abus
  input [7:0] BselectAdd,//select the register index to read from to store into bbus
  input [7:0] BselectInt,//select the register index to read from to store into bbus
  input [7:0] BselectMult,//select the register index to read from to store into bbus
  input [7:0] BselectLdSt,//select the register index to read from to store into bbus
  input [7:0] Dselect,//select the register to write to from dbus
  input [7:0] busySelect,//flag for each flipflop to say if it is open
  input [31:0] dbus,//data in
  output [31:0] abusAdd,//data out
  output [31:0] abusInt,//data out
  output [31:0] abusMult,//data out
  output [31:0] abusLdSt,//data out
  output [31:0] bbusAdd,//data out
  output [31:0] bbusInt,//data out
  output [31:0] bbusMult,//data out
  output [31:0] bbusLdSt,//data out
  output [7:0] busyBus,//bus for each of the reg entries if it's busy or not
  input clk,
  input validData
  );
  //if it's requesting register 0 just output a 0
  assign abusAdd = AselectAdd[0] ? 32'b0 : 32'bz;
  assign bbusLdSt = BselectLdSt[0] ? 32'b0 : 32'bz;
  assign abusInt = AselectInt[0] ? 32'b0 : 32'bz;
  assign bbusAdd = BselectAdd[0] ? 32'b0 : 32'bz;
  assign abusLdSt = AselectLdSt[0] ? 32'b0 : 32'bz;
  assign bbusInt = BselectInt[0] ? 32'b0 : 32'bz;
  assign abusMult = AselectMult[0] ? 32'b0 : 32'bz;
  assign bbusMult = BselectMult[0] ? 32'b0 : 32'bz;
  assign busyBus[0] = 0;
  //only 8 of these for now
  DNegflipFlop myFlips[6:0](
    .dbus(dbus),
    .abusAdd(abusAdd),
    .abusInt(abusInt),
    .abusMult(abusMult),
    .abusLdSt(abusLdSt),
    .Dselect(Dselect[7:1]),//doing this means that index 7 of Deslect will go to DNegflipFlop index 7
    .BselectLdSt(BselectLdSt[7:1]),
    .BselectAdd(BselectAdd[7:1]),
    .BselectInt(BselectInt[7:1]),
    .BselectMult(BselectMult[7:1]),
    .AselectAdd(AselectAdd[7:1]),
    .AselectInt(AselectInt[7:1]),
    .AselectLdSt(AselectLdSt[7:1]),
    .AselectMult(AselectMult[7:1]),
    .busySelect(busySelect[7:1]),
    .bbusAdd(bbusAdd),
    .bbusInt(bbusInt),
    .bbusMult(bbusMult),
    .bbusLdSt(bbusLdSt),
    .isBusy(busyBus[7:1]),
    .clk(clk),
    .validData(validData)
    );
endmodule

module DNegflipFlop
(
  dbus,
  abusAdd,
  abusInt,
  abusMult,
  abusLdSt,
  Dselect,
  BselectLdSt,
  BselectAdd,
  BselectInt,
  BselectMult,
  AselectAdd,
  AselectInt,
  AselectLdSt,
  AselectMult,
  bbusAdd,
  bbusInt,
  bbusMult,
  bbusLdSt,
  clk,
  busySelect,
  isBusy,
  validData
);
  input [31:0] dbus;
  input Dselect;//the select write bit for this register
  input BselectLdSt;//the select read bit for this register
  input BselectAdd;//the select read bit for this register
  input BselectInt;//the select read bit for this register
  input BselectMult;//the select read bit for this register
  input AselectAdd;//the other select read bit for this register
  input AselectInt;//the other select read bit for this register
  input AselectLdSt;//the other select read bit for this register
  input AselectMult;//the other select read bit for this register
  input busySelect;
  input clk;
  output  [31:0] abusAdd;
  output  [31:0] abusInt;
  output  [31:0] abusMult;
  output  [31:0] abusLdSt;
  output  [31:0] bbusAdd;
  output  [31:0] bbusInt;
  output  [31:0] bbusMult;
  output  [31:0] bbusLdSt;
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
  assign abusAdd = AselectAdd? data : 32'hzzzzzzzz;
  assign abusInt = AselectInt? data : 32'hzzzzzzzz;
  assign abusMult = AselectMult? data : 32'hzzzzzzzz;
  assign abusLdSt = AselectLdSt? data : 32'hzzzzzzzz;
  assign bbusAdd = BselectAdd? data : 32'hzzzzzzzz;
  assign bbusInt = BselectInt? data : 32'hzzzzzzzz;
  assign bbusMult = BselectMult? data : 32'hzzzzzzzz;
  assign bbusLdSt = BselectLdSt? data : 32'hzzzzzzzz;

endmodule
