/*************************
*  Willard Wider
*  04-07-18
*  ELEC3800
*  final_project.v
*  building a tomselo CPU
*  with a cache
*************************/

/*
Current specs:
3 opcode bits (8 instructions total)
3 register bits (8 registers total) [register 0 is the nothing register]
32 bit register/bus width
format:   000__000 __ 000 __000 
add/mult: op __dest__src1 __src2
load:     op __dest__index__offset
store:    op __data__index__offset
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

module final_project #(parameter CPU_ID = 1'b0) (clk,cache_request,cache_data,cache_busy);
  //the clock. it's a clock. it does clock things.
  input clk;
  //CACHE INFO//
  //the cache request line
  output [21:0] cache_request;
  //the data line from the cache
  input [21:0] cache_data;
  //the signal if the cache has two requests at the same time and is busy
  input cache_busy;
  //////////////
  //the wires used for the operation bus
  //connects the instructon queue (top module for now)
  //to the reservation stations
  wire [2:0] opbus_opcode;
  wire [2:0] opbus_dest;
  wire [2:0] opbus_src_a;
  wire [2:0] opbus_src_b;
  wire [11:0] cache_address;
  
  //the wires used for the common data bus
  //connects the mux to the regfile and reservation statrions
  wire [2:0] cdbus_dest;
  wire [7:0] cdbus_dest_shift;
  wire [7:0] cdbus_data;
  wire cdbus_valid_data;
  
  //wires connecting the regfile to the reservation stations
  //one for each one (except load/store)
  wire [7:0] abus_wire_ld_st;
  wire [7:0] abus_wire_add;
  wire [7:0] abus_wire_mult;
  wire [7:0] abus_wire_int;
  wire [7:0] bbus_wire_ld_st;
  wire [7:0] bbus_wire_add;
  wire [7:0] bbus_wire_mult;
  wire [7:0] bbus_wire_int;
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
  wire [7:0] rs_ex_fp_abus_data;
  wire [7:0] rs_ex_fp_bbus_data;
  wire rs_ex_fp_add_is_busy;
  //FP_MULT
  wire [2:0] rs_ex_fp_mult_op_code;
  wire [2:0] rs_ex_fp_mult_d_select;
  wire [7:0] rs_ex_fp_mult_d_select_shift;
  wire [7:0] rs_ex_fp_mult_abus_data;
  wire [7:0] rs_ex_fp_mult_bbus_data;
  wire rs_ex_fp_mult_is_busy;
  //INT
  wire [2:0] rs_ex_int_op_code;
  wire [2:0] rs_ex_int_d_select;
  wire [7:0] rs_ex_int_d_select_shift;
  wire [7:0] rs_ex_int_abus_data;
  wire [7:0] rs_ex_int_bbus_data;
  wire rs_ex_int_is_busy;
  //LOAD
  wire [2:0] rs_ex_ld_op_code;
  wire [2:0] rs_ex_ld_d_select;
  wire [7:0] rs_ex_ld_d_select_shift;
  wire [7:0] rs_ex_ld_abus_data;
  wire [7:0] rs_ex_ld_bbus_data;
  //STORE
  wire [2:0] rs_ex_st_op_code;
  wire [2:0] rs_ex_st_d_select;
  wire [7:0] rs_ex_st_d_select_shift;
  wire [7:0] rs_ex_st_abus_data;
  wire [7:0] rs_ex_st_bbus_data;
  wire rs_ex_ld_st_is_busy;
  
  //wires connecting the execution units to the mux
  //FP_ADD
  wire FP_add_mux_valid_data;
  wire [2:0] FP_add_mux_d_select;
  wire [7:0] FP_add_mux_d_select_shift;
  wire [7:0] FP_add_mux_data;
  wire FP_add_mux_stall;
  //FP_MULT
  wire FP_mult_mux_valid_data;
  wire [2:0] FP_mult_mux_d_select;
  wire [7:0] FP_mult_mux_d_select_shift;
  wire [7:0] FP_mult_mux_data;
  wire FP_mult_mux_stall;
  //INT
  wire int_mux_valid_data;
  wire [2:0] int_mux_d_select;
  wire [7:0] int_mux_d_select_shift;
  wire [7:0] int_mux_data;
  wire int_mux_stall;
  //LOAD/STORE
  wire mem_mux_valid_data;
  wire [2:0] mem_mux_d_select;
  wire [7:0] mem_mux_d_select_shift;
  wire [7:0] mem_mux_data;
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
  //both
  wire [2:0] RS_load_mem_ofset;//b select
  wire [2:0] RS_store_mem_ofset;//b select
  wire [11:0] RS_load_address;//a data
  wire [11:0] RS_store_address;//a data
  //store
  wire RS_store_mux_stall;
  wire [7:0] RS_store_data;//dbus data
  //load
  wire [2:0] RS_load_dest;//d select
  wire [7:0] RS_load_dest_shift;//d select
  
  //the wires connect the lload and store RS to the mux
  wire [2:0] mem_ex_d_select;
  wire [7:0] mem_ex_d_select_shift;
  wire [2:0] mem_ex_b_offset;
  wire [7:0] mem_ex_dbus_data;
  wire [11:0] mem_ex_abus_address;
  wire [2:0] mem_ex_op_code;
  
  //the reg as the instruction queue
  //first bracket is how wide each register is
  //second bracket is now many in the array
  //we want 16 instruction queues of 12 bits wide
  reg [17:0] instruction_queue [15:0];
  reg [17:0] current_instruction;
  
  //counter for the dequeue for loop
  integer i;
  
  //the fake clocks used as delays
  reg fake_rs_clock;
  wire fake_mux_clock;
  wire fake_mux_snoop_clock;
  wire fake_meme_RS_mux_clock;
  
  //the control bit for setting the high bit for the regfile if the dest reg in use
  //width needs to be the number of regs
  reg [7:0] busy_select_shift;
  
  //wire for telling the execution unit which CPU_ID it is
  wire CPU_ID_WIRE;

  //register module instance
  regfile best_regfile_name_ever
  (
    //ins
    .clk(clk), .AselectAdd(a_select_wire_add), .AselectInt(a_select_wire_int), .AselectMult(a_select_wire_mult),
    .AselectLdSt(a_select_wire_ld_st), .BselectAdd(b_select_wire_add), .BselectInt(b_select_wire_int), .BselectMult(b_select_wire_mult),
    .BselectLdSt(b_select_wire_ld_st), .busySelect(busy_select_shift), .Dselect(cdbus_dest_shift), .dbus(cdbus_data),
    .validData(cdbus_valid_data),
    //outs
    .busyBus(busy_bus), .abusAdd(abus_wire_add), .abusMult(abus_wire_mult), .abusInt(abus_wire_int), .abusLdSt(abus_wire_ld_st),
    .bbusLdSt(bbus_wire_ld_st), .bbusMult(bbus_wire_mult), .bbusAdd(bbus_wire_add), .bbusInt(bbus_wire_int)
  );
  
  //reservation station instance for added
  //setting BUS_LENGTH to 3 means it makes 4 of them, indexed 0-3
  //ID=010=ADD
  reservation_station #(.BUS_LENGTH(3),.ID(3'b010)) FP_add_station
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
  //setting BUS_LENGTH to 1 means it makes 2 of them, indexed 0-1
  //ID=011=ST
  reservation_station #(.BUS_LENGTH(1),.ID(3'b011)) store_station
  (
    //ins
    .clk(clk), .fake_clock(fake_rs_clock), .fake_mux_clock(fake_mux_snoop_clock), .station_selected(store_selected_flag),
    .opbus_op(opbus_opcode), .opbus_dest(opbus_dest), .opbus_src_a(opbus_src_a), .opbus_src_b(opbus_src_b), .abus_in(abus_wire_ld_st),
    .bbus_in(bbus_wire_ld_st), .busy_bus(busy_bus), .execution_unit_busy(rs_ex_ld_st_is_busy), .cdbus_dest(cdbus_dest),
    .cdbus_dest_shift(cdbus_dest_shift), .cdbus_dest_data(cdbus_data), .cdbus_valid(cdbus_valid_data), .store_mux_stall(RS_store_mux_stall),
    .address_in(cache_address),
    //outs
    .a_select_out(a_select_wire_ld_st), .b_select_out(b_select_wire_ld_st), .station_full(store_full_flag), .d_select_out(rs_ex_st_d_select),
    .d_select_out_shift(rs_ex_st_d_select_shift), .address_out(RS_store_address), .bbus_out(RS_store_data),
    .op_code_out(rs_ex_st_op_code), .memory_offset_out(RS_store_mem_ofset), .valid_data(RS_store_valid_data)
  );
  
  //reservation station instance for store
  //setting BUS_LENGTH to 3 means it makes 4 of them, indexed 0-3
  //ID=100=LD
  reservation_station #(.BUS_LENGTH(3),.ID(3'b100)) load_station
  (
    //ins
    .clk(clk), .fake_clock(fake_rs_clock), .fake_mux_clock(fake_mux_snoop_clock), .station_selected(load_selected_flag),
    .opbus_op(opbus_opcode), .opbus_dest(opbus_dest), .opbus_src_a(opbus_src_a), .opbus_src_b(opbus_src_b), .abus_in(abus_wire_ld_st),
    .bbus_in(bbus_wire_ld_st), .busy_bus(busy_bus), .execution_unit_busy(rs_ex_ld_st_is_busy), .cdbus_dest(cdbus_dest),
    .cdbus_dest_shift(cdbus_dest_shift), .cdbus_dest_data(cdbus_data), .cdbus_valid(cdbus_valid_data), .address_in(cache_address),
    //outs
    .a_select_out(a_select_wire_ld_st), .b_select_out(b_select_wire_ld_st), .station_full(load_full_flag), .d_select_out(RS_load_dest),
    .d_select_out_shift(RS_load_dest_shift), .address_out(RS_load_address), .bbus_out(rs_ex_ld_bbus_data),
    .op_code_out(rs_ex_ld_op_code), .trigger_exes(fake_meme_RS_mux_clock), .memory_offset_out(RS_load_mem_ofset),
    .valid_data(RS_load_valid_data)
  );
  
  //mux instance for joining the two reservation stations
  partly_smart_mux psmux
(
  //in
  .fake_clock(fake_meme_RS_mux_clock), .load_d_select(RS_load_dest), .load_d_select_shift(RS_load_dest_shift),
  .load_address(RS_load_address), /*.load_offset(RS_load_mem_ofset),*/ .store_dbus_data(RS_store_data), .store_address(RS_store_address),
  /*.store_offset(RS_store_mem_ofset),*/ .valid_load_data(RS_load_valid_data), .valid_store_data(RS_store_valid_data),
  .load_op_code(rs_ex_ld_op_code), .store_op_code(rs_ex_st_op_code), .execution_unit_stall(rs_ex_ld_st_is_busy), .stall_by_mux(mem_mux_stall),
  //out
  .store_stall(RS_store_mux_stall), .exec_d_select(mem_ex_d_select), .exec_d_select_shift(mem_ex_d_select_shift),
  .exec_b_offset(mem_ex_b_offset), .exec_dbus_data(mem_ex_dbus_data), .exec_abus_address(mem_ex_abus_address), .exec_op_code(mem_ex_op_code)
);
  
  //execution unit instance for loading/storing
  //ID=11=LD/ST
  execution_unit #(.CYCLE_TIME(1),.ID(2'b11)) load_store_unit
  (
    //ins
    .clk(clk), .op_code_in(mem_ex_op_code), .d_select_in(mem_ex_d_select), .d_select_shift_in(mem_ex_d_select_shift), .cache_in(cache_data),
    /*.abus_data_in(mem_ex_abus_address),*/ .stall_by_mux(mem_mux_stall), .store_dbus_data_in(mem_ex_dbus_data),
    .cache_busy(cache_busy), .address_in(mem_ex_abus_address), .CPU_ID(CPU_ID_WIRE),
    //outs
    .is_busy(rs_ex_ld_st_is_busy), .valid_data(mem_mux_valid_data), .dbus_data_out(mem_mux_data),
    .d_select_out(mem_mux_d_select), .d_select_shift_out(mem_mux_d_select_shift), .cache_request(cache_request)
  );
  
  //execution unit instance for adding
  //ID=10=FP_ADD
  execution_unit #(.CYCLE_TIME(1),.ID(2'b10)) FP_add_unit
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
    int_full_full_flag = 0;
    //set the fake clock
    fake_rs_clock = 0;
    busy_select_shift = 8'b0;
    //set the current instructin to nothing
    current_instruction = 18'b0;
    /*
    Current specs:
    3 opcode bits (8 instructions total)
    3 register select bits for destination (source if store) (8 registers total) [register 0 is the nothing register]
    (if not load/store) 3 register select bits for source 1 (ra)
    (if not load/store) 3 register select bits for sourece 2 (rb)
    (if load/store) 12 address bits
    format (not load/store): 000__000 __000 __000 __000000
                             op __dest__src1__src2__not used
                             (12 bit width)
    format (load/store):     000__000 __000000000000
                   load:     op __dest__address
                  store:     op __src __address
                             (18 bit width)
    */
    /*
    Current Instruction List:
    NOP   000
    LD    001
    ST    010
    ADDF  011
    MULTF 100
    */
    //fill the instruction queue
    instruction_queue[0] [17:0] = 18'b001_001_010100000000;  //ld, r1,0x500
    instruction_queue[1] [17:0] = 18'b001_010_010100001000;  //ld, r2,0x508
    instruction_queue[2] [17:0] = 18'b011_011_001_010_000000;//add,r3,r1,r2
    instruction_queue[3] [17:0] = 18'b010_011_010100001000;  //st, r3,0x508
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
    //copy the instruction to the current instruction reg
    current_instruction[17:0] = instruction_queue[0];
    case (current_instruction[17:15])
      3'b000: begin
        //nop
        //don't select any execution units...
      end
      3'b001: begin
        //LOAD
        //if the corresponding RS is full, then don't set the corresponding selected flag to full
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
        busy_select_shift = (current_instruction[14:12] == 3'b0)? 8'b0 : 8'b00000001 << current_instruction[14:12];
      end
      //shift the entries down from the queue
      //act as the dequeue
      for(i = 0; i < 15; i=i+1) begin
        instruction_queue[i] = instruction_queue[i+1];
      end
      //fill the last one with zeros?
    end
    //invert the clock so that it #triggers the reservation station
    //while also giving the assigns enough time to work
    fake_rs_clock = ~fake_rs_clock;
  end
  
  //generic assign statemetns for the operation bus (opbus)
  assign opbus_opcode = (store_selected_flag||load_selected_flag||FP_add_selected_flag||FP_mult_selected_flag||int_selected_flag)? current_instruction[17:15] : 3'bz;
  assign opbus_dest = (store_selected_flag||load_selected_flag||FP_add_selected_flag||FP_mult_selected_flag||int_selected_flag)? current_instruction[14:12] : 3'bz;
  assign opbus_src_a = (FP_add_selected_flag||FP_mult_selected_flag||int_selected_flag)? current_instruction[11:9] : 3'bz;
  assign opbus_src_b = (FP_add_selected_flag||FP_mult_selected_flag||int_selected_flag)? current_instruction[8:6] : 3'bz;
  assign cache_address = (store_selected_flag||load_selected_flag)? current_instruction[11:0] : 12'bz;
  assign CPU_ID_WIRE = CPU_ID;
endmodule

//the module for creating the reservation stations
//default data iwdth is 1, can be changed to allow more width
module reservation_station #(parameter BUS_LENGTH = 1, ID=3'b000)
  (
    //ins
    clk, fake_clock, fake_mux_clock, station_selected, opbus_op, opbus_dest, opbus_src_a, opbus_src_b, abus_in, bbus_in, busy_bus,
    execution_unit_busy, cdbus_dest, cdbus_dest_shift, cdbus_dest_data, cdbus_valid, store_mux_stall, address_in,
    //outs
    a_select_out, b_select_out, d_select_out, d_select_out_shift, abus_out, bbus_out, op_code_out, station_full, trigger_exes,
    memory_offset_out, valid_data, address_out
  );
  //the regular good'ol clock
  input clk;
  //the delayed clock for triggering the alwyas block
  //it's the last thing done in the always block for the instruction dequeuing
  //delay clock from insturctuion queue
  input fake_clock;
  //delay clock for after the common data bus (cdbus) has put the data on the bus
  input fake_mux_clock;
  //determins if the station is selected to grab the next enqueued element
  //TODO: modify instructino queue to use this as trigger rather than a fake clock
  input station_selected;
  //link to the op bus components
  input [2:0] opbus_op;
  input [2:0] opbus_dest;
  input [2:0] opbus_src_a;
  input [2:0] opbus_src_b;
  //the inputs from the regfile
  input [7:0] abus_in,bbus_in;
  //the array of busy buses from the regfile. it's a wire here so always updated
  input [7:0] busy_bus;
  //flag for if the execution unit is busy
  input execution_unit_busy;
  //the common data bus for snooping
  input [2:0] cdbus_dest;
  input [7:0] cdbus_dest_shift;
  input [7:0] cdbus_dest_data;
  input cdbus_valid;
  input store_mux_stall;
  //for the load and store RS, the address input from the queue
  input [11:0] address_in;
  //the selector to the regfile for which register to use in the abus
  output reg [7:0] a_select_out;
  output reg [7:0] b_select_out;
  //the selector to the execution for which register to write to
  output reg [7:0] d_select_out_shift;
  output reg [2:0] d_select_out;
  //the output for the data from the abus and bbus data arrays
  output reg [7:0] abus_out, bbus_out;
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
  //for load/store RS, address output
  output reg [11:0] address_out;
  //INFO: it may be possible to later do this as a module array
  //array of busses acting as the queue
  //first bracket is how wide each register is
  //second bracket is now many in the array
  //TODO: stop storing the shift of the register selection like a scrub
  //TODO: make the storage one giant register to make it less code
  reg[2:0] op_code [BUS_LENGTH:0];
  reg[2:0] dest_reg [BUS_LENGTH:0];
  reg[7:0] dest_reg_shift [BUS_LENGTH:0];
  reg[2:0] src_a [BUS_LENGTH:0];
  reg[7:0] src_a_shift [BUS_LENGTH:0];
  reg[2:0] src_b [BUS_LENGTH:0];
  reg[7:0] src_b_shift [BUS_LENGTH:0];
  //the data from the regfile
  reg[7:0] abus_data[BUS_LENGTH:0];
  reg[7:0] bbus_data[BUS_LENGTH:0];
  //(if the load or store register) the bits that would be a register address
  //pre-calculated when stored
  reg[11:0] cache_address[BUS_LENGTH:0];
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
  reg from_cdb;
  
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
    address_out = 12'bz;
    abus_out = 8'bz;
    bbus_out = 8'bz;
    op_code_out = 3'bz;
    station_full = 0;
    counter = 0;
    output_bus_touched = 0;
    memory_offset_out = 3'bz;
    valid_data = 0;
    from_cdb = 0;
    repeat(BUS_LENGTH+1) begin
      op_code[counter] = 3'b0;
      dest_reg[counter] = 3'b0;
      dest_reg_shift[counter] = 8'b0;
      src_a[counter] = 3'b0;
      src_a_shift[counter] = 8'b0;
      src_b[counter] = 3'b0;
      src_b_shift[counter] = 8'b0;
      abus_data[counter] = 8'b0;
      bbus_data[counter] = 8'b0;
      operation_data_a_ready[counter] = 0;
      operation_data_b_ready[counter] = 0;
      station_in_use[counter] = 0;
      a_b_equal[counter] = 0;
      cache_address[counter] = 0;
      counter = counter+1;
    end
    counter = 0;
    counter2 = 0;
    counter3 = 0;
  end
  
  //use fake_clock to give a little delay
  //in theory it's listinigh for the change and therefore
  //happends after the blocking part
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
            //calculate the address here and store it
            //TODO: actually make it a calculate the address rather then just take the offset
            cache_address[counter] = address_in;
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
  
  //checks if data for each station is ready by first snooping, then checking the regfile
  always @(fake_mux_clock) begin
    counter = 0;
    //use a loop to incriment the counter  for checking if data is ready
    begin:data_check_break
      repeat(BUS_LENGTH+1) begin:data_check_continue
        from_cdb = 0;
        if(station_in_use[counter]) begin
          $display("RS ID=%d, station %d is in use", ID, counter);
          //loads and stores only check the destination busyBus
          //stores check snoop
          //all others do the regular thing
          case(op_code[counter])
            3'b010: begin//store cheks snoop (dog) bus
              //data (to store to mem) saved in bbus
              //load address from aselect into abus(TODO)
              //check the cdb
              //else check the register is checked out
              //then check for WAW
              //if the snopped data is relavent to this store
              if(!operation_data_b_ready[counter]) begin
                $display("RS ID=%d, store data for dest (regsiter %d) of station %d is not ready", ID, dest_reg[counter], counter);
                if(cdbus_dest == dest_reg[counter]) begin
                  $display("RS ID=%d, cdbus says store data is relavent (destination register %d) at station %d ", ID, dest_reg[counter], counter);
                  //save the data to the bbus to be used for storing (to mem) later
                  from_cdb = 1;
                  bbus_data[counter] = cdbus_dest_data;
                  operation_data_b_ready[counter]=1;
                end
                else if(!busy_bus[dest_reg[counter]]) begin
                  $display("RS ID=%d, busybus says register %d for b is up to date for station %d", ID, dest_reg[counter], counter);
                  operation_data_b_ready[counter]=1;
                end
                if(counter > 0) begin: WAW_check_break_store
                  counter3 = counter-1;
                  repeat(counter) begin
                    if(dest_reg[counter3] == dest_reg[counter])begin
                      $display("RS ID=%d, setting ready flag for source b of station %d back to false because hazard conflicts with destination of station %d", ID,counter,counter3);
                      operation_data_b_ready[counter]=0;
                    end
                    counter3 = counter3-1;
                  end
                end
                if(operation_data_b_ready[counter] && !from_cdb) begin
                  //it is ready, set the output address of a
                  //it will trigger the wire to put the value at the reg index onto the abus
                  b_select_out = dest_reg_shift[counter];
                  b_update_index = counter;
                  //bbus_data[counter] = bbus_in;//don't do this until the posedge part
                  //operation_data_b_ready[counter]=1;
                  b_update_index_flag = 1;
                end
              end
              //also set operation data ready for a since it does not apply
              operation_data_a_ready[counter] = 1;
            end
            3'b001: begin//load only checks busybus
              //load address from aselect into abus (TODO)
              //check if register is checked out(TODO)
              //then check for WAW
              if(!operation_data_b_ready[counter]) begin
                $display("RS ID=%d, load data for dest (regsiter %d) of station %d is not ready", ID, dest_reg[counter], counter);
                if(1) begin
                //if(!busy_bus[dest_reg[counter]]) begin
                  //$display("RS ID=%d, busybus says register %d for b is up to date for station %d", ID, dest_reg[counter], counter);
                  $display("RS ID=%d, load always true says register %d for b is up to date for station %d", ID, dest_reg[counter], counter);
                  operation_data_b_ready[counter]=1;
                  if(counter > 0) begin: WAW_check_break_load
                    counter3 = counter-1;
                    repeat(counter) begin
                      if(dest_reg[counter3] == dest_reg[counter])begin
                        $display("RS ID=%d, setting ready flag for source b of station %d back to false because hazard conflicts with destination of station %d", ID,counter,counter3);
                        operation_data_b_ready[counter]=0;
                      end
                      counter3 = counter3-1;
                    end
                  end
                  //don't need to actually trigger the bbus since we're writing into it from memory...
                  /*
                  if(operation_data_b_ready[counter]) begin
                    //it is ready, set the output address of a
                    //it will trigger the wire to put the value at the reg index onto the abus
                    b_select_out = dest_reg_shift[counter];
                    b_update_index = counter;
                    //bbus_data[counter] = bbus_in;//don't do this until the posedge part
                    //operation_data_b_ready[counter]=1;
                    b_update_index_flag = 1;
                  end
                  */
                end
              end
              //also set operation data ready for a since it does not apply
              operation_data_a_ready[counter] = 1;
            end
            default: begin
              //check the cdb
              //else check the register is checked out
              //else check if the src and dest are the same
              //then check for WAW
              if(!operation_data_a_ready[counter]) begin
                $display("RS ID=%d, data for a (regsiter %d) of station %d is not ready", ID, src_a[counter], counter);
                //if the snopped data is relavent to this reservation station
                if(cdbus_dest == src_a[counter]) begin
                  $display("RS ID=%d, cdbus says data is relavent (destination register %d) for source a at station %d ", ID, cdbus_dest, counter);
                  //update the value with the snopped value and set data ready flag
                  from_cdb = 1;
                  abus_data[counter] = cdbus_dest_data;
                  operation_data_a_ready[counter]=1;
                end
                else if(!busy_bus[src_a[counter]]) begin
                  $display("RS ID=%d, busybus says register %d for a is up to date for station %d", ID, src_a[counter], counter);
                  operation_data_a_ready[counter]=1;
                end
                else if(dest_reg[counter] == src_a[counter])begin
                  $display("RS ID=%d, dest_reg and src_a match (%d) for station %d, ignoring",ID, src_a[counter],counter);
                  operation_data_a_ready[counter]=1;
                end
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
                if(operation_data_a_ready[counter] && !from_cdb) begin
                  //it is ready, set the output address of a
                  //it will trigger the wire to put the value at the reg index onto the abus
                  a_select_out = src_a_shift[counter];
                  a_update_index = counter;
                  //abus_data[counter] = abus_in;//don't do this until the posedge part
                  a_update_index_flag = 1;
                end
              end
              if(src_a[counter] == src_b[counter]) begin
                $display("RS ID=%d, src_a and b match(%d), setting match bit and copying data, station %d", ID, src_b[counter], counter);
                a_b_equal[counter] = 1;
                operation_data_b_ready[counter] = 1;
                b_update_index_flag = 1;
                b_update_index = counter;
              end
              else if(!operation_data_b_ready[counter]) begin
                $display("RS ID=%d, data for b (regsiter %d) of station %d is not ready", ID, src_b[counter], counter);
                //check the cdb
                //else check the register is checked out
                //else check if the src and dest are the same
                //then check for WAW
                //if the snopped data is relavent to this reservation station
                from_cdb = 0;
                if(cdbus_dest == src_b[counter]) begin
                  $display("RS ID=%d, cdbus says data is relavent (destination register %d) for source b at station %d ", ID, src_b[counter], counter);
                  bbus_data[counter] = cdbus_dest_data;
                  from_cdb = 1;
                  operation_data_b_ready[counter]=1;
                end
                else if(!busy_bus[src_b[counter]]) begin
                  $display("RS ID=%d, busybus says register %d for b is up to date for station %d", ID, src_b[counter], counter);
                  operation_data_b_ready[counter]=1;
                end
                else if(dest_reg[counter] == src_b[counter])begin
                  $display("RS ID=%d, dest_reg and src_b match (%d) for station %d, ignoring",ID, src_b[counter],counter);
                  operation_data_b_ready[counter]=1;
                end
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
                if(operation_data_b_ready[counter] && !from_cdb)begin
                  //it is ready, set the output address of a
                  //it will trigger the wire to put the value at the reg index onto the abus
                  b_select_out = src_b_shift[counter];
                  b_update_index = counter;
                  //bbus_data[counter] = bbus_in;//don't do this until the posedge part
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
  
  //deques from the RS to give to the execution unit
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
        //if(station_in_use[counter])begin
        //$display("RS ID=%d, station %d is in use, operation_data_a_ready=%d, operation_data_b_ready=%d", ID,counter,operation_data_a_ready[counter],operation_data_b_ready[counter]);
        //end
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
          address_out = cache_address[counter];
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
          address_out = 12'bz;
        end
        else begin
          $display("RS ID=%d, no instructions ready for execution unit, closing outputs", ID);
          abus_out = 8'bz;
          bbus_out = 8'bz;
          d_select_out = 3'bz;
          d_select_out_shift = 8'bz;
          op_code_out = 3'bz;
          address_out = 12'bz;
        end
      end
    end
    trigger_exes = ~trigger_exes;
  end
endmodule

//the module for creating the execution units
//execution unit IDs: 001=MULT, 010=ADD, 011=LD/ST
module execution_unit #(parameter CYCLE_TIME = 1, ID = 2'b00)
  (
    //in
    clk, op_code_in, d_select_in, d_select_shift_in, abus_data_in, bbus_data_in, stall_by_mux, cache_in,
    store_dbus_data_in, cache_busy, address_in, CPU_ID,
    //out
    is_busy, valid_data, dbus_data_out, d_select_out, d_select_shift_out, fake_clock, cache_request
  );
  input clk;
  //the inputs from the reservation station
  input [2:0] op_code_in;
  input [2:0] d_select_in;
  input [7:0] d_select_shift_in;
  input [7:0] abus_data_in;
  input [7:0] bbus_data_in;
  //the input from the mux if there's two or more requests for the cdb and one execution needs to stall
  input stall_by_mux;
  //the cache input wire
  input [21:0] cache_in;
  //the data from the regfile to store, from the dbus
  input [7:0] store_dbus_data_in;
  //flag for if the cache is busy
  input cache_busy;
  //the address that needs to be parsed to the cache
  input [11:0] address_in;
  //the ID of this CPU
  input CPU_ID;
  //flag to determine if the execution unit is busy
  output reg is_busy;
  //flag for the regfile to verify it only accepts the final value at the correct time
  output reg valid_data;
  //the actual outputs for above, but in output form
  output reg [7:0] dbus_data_out;
  output reg [2:0] d_select_out;
  output reg [7:0] d_select_shift_out;
  output reg fake_clock;
  //the cache request for the memory storing or loading
  output reg [21:0] cache_request;
  //counter to use for determining the "cycle" of execution
  reg [31:0] counter;
  reg [31:0] counter_backup;
  //the actual cycle time.
  //for load/store, there is one execution cycle, and then an additional cycle for cache access
  //so load and store execution cycles are CYCLE_TIME+1 (cause need to wait a cycle for cache access)
  //but all other execution units are fine
  reg [31:0] actual_cycle_time;
  //reg current_cycle_has_request;
  
  initial begin
    //set all the stuffs to 0
    is_busy = 0;
    valid_data = 0;
    dbus_data_out = 0;
    d_select_out = 0;
    d_select_shift_out = 0;
    cache_request = 22'bz;
    fake_clock = 0;
    counter = 0;
    counter_backup = 0;
    //current_cycle_has_request = 0;
    actual_cycle_time = (ID==2'b11)? CYCLE_TIME+1 : CYCLE_TIME;
  end
  
  //runs the simulated execution as soon as possible (at the main clock)
  always @(posedge clk) begin
    valid_data = 0;
    //current_cycle_has_request = 0;
    if(is_busy) begin
      counter = counter + 1;
      $display("execution unit %d is busy, counter=%d",ID, counter);
      if(ID==2'b11)begin
        cache_request = 22'bz;
      end
    end
    else if(cache_busy)begin
      $display("cache reports busy, setting load/sotre ex unit to busy");
      is_busy = 1;
      counter = counter+1;
      cache_request = 22'bz;
    end
    if((!is_busy) && (op_code_in > 0)) begin
      $display("execution unit %d is not busy, accepts new instruction.",ID);
      //set the unit to busy
      is_busy = 1;
      //set the index outputs from the inputs
      d_select_out = d_select_in;
      d_select_shift_out = d_select_shift_in;
      case(ID)
        2'b00: begin//int subtract unit
          $display("ERROR: this execution unit (SUBT) is not complete yet");
          case(op_code_in)
            3'b101: begin
              dbus_data_out = abus_data_in - bbus_data_in;
            end
          endcase
        end
        2'b01: begin//int multiply unit
          case(op_code_in)
            3'b100: begin
              dbus_data_out = abus_data_in * bbus_data_in;
            end
          endcase
        end
        2'b10: begin//int add unit
          case(op_code_in)
            3'b011: begin
              //add
              dbus_data_out = abus_data_in + bbus_data_in;
            end
          endcase
        end
        2'b11: begin
          //load/store unit
          //the request line:
          //processor id (1 bit)
          //load-store flag (1 bit) (0=load, 1=store)
          //the tag (11 bits)
          //the block offset (1 bits)
          //the data (if a store from processor to memory) (8 bits)
          //current_cycle_has_request = 1;
          case(op_code_in)
            3'b001: begin
              //load (from "memory", to regfile)
              //send request, wait for return
              cache_request = {CPU_ID,1'b0,address_in[11:4],address_in[2:0],address_in[3],8'b0};
              $display("executino unit: sending new cache request");
            end
            3'b010: begin
              //store (to "memory", from regfile)
              //send request to store with data
              cache_request = {CPU_ID,1'b1,address_in[11:4],address_in[2:0],address_in[3],store_dbus_data_in};
              $display("executino unit: sending new cache request");
            end
          endcase
        end
      endcase
    end
    //if it equals, the exeuction unit is done
    //however, the mux may just have gotten two inputs
    if(counter == actual_cycle_time) begin
      $display("execution complete for execution unit %d",ID);
      //if load/store execution unit, check if the data sent from the cache is valid, and for this CPU
      if(ID==2'b11)begin
        if(cache_in >=0)begin
          $display("execution unit: cache_in is a valid value, (%b)",cache_in);
          if(cache_in[21]==CPU_ID)begin
            $display("execution unit: cache_in data is for this processor, ID=%d",CPU_ID);
            if(cache_in[20])begin//store to cache, no writeback
              dbus_data_out = 8'b0;
              d_select_out = 3'b0;
              d_select_shift_out = 8'b00000001;
            end
            else begin//load from cache, writeback data
              dbus_data_out = cache_in[7:0];
            end
            /*
            //set the output back to z to prevent additional cache accesses
            //ONLY if this cycle done NOT have a new cache request to send
            //does not work because it is a cycle behind, solution is to close the output every cycle
            if(!current_cycle_has_request)begin
              $display("execution unit: cache data loaded from previous cycle, and no request this cycle, closing output");
              cache_request = 22'bz;
            end
            */
          end
          else begin
            $display("execution unit: cache_in data is not for this processor, ID=%d",CPU_ID);
          end
        end
        else begin
          $display("cache_in is z");
        end
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
    else if(counter > actual_cycle_time) begin
      //valid data needs to stay true for mux to work...
      $display("(posedge clk) execution unit %d stalled by mux, setting valid back to true", ID);
      valid_data = 1;
    end
    fake_clock = ~fake_clock;
  end
  
  //stall trigger for the cdbus mux, disable the execution unit
  always @(posedge stall_by_mux) begin
    $display("(posedge stall_by_mux) posedge stall_by_mux detected for execution unit %d, set self to busy",ID);
    is_busy = 1;
    counter = counter_backup;
  end
  
  //trigger for the cdbus mux, this unit was selected to go next
  //can therefore execute next instruction
  always @(negedge stall_by_mux) begin
    if(counter > actual_cycle_time) begin
      $display("(negedge stall_by_mux) negedge stall_by_mux detected for execution unit %d with counter > CYCLE_TIME true, self no longer busy",ID);
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
  //delay clock from the FP mult unit
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
  input [7:0] mem_data;
  input [7:0] FP_mult_data;
  input [7:0] FP_add_data;
  input [7:0] int_data;
  //output flags for the execution units if their data was accepted
  output reg mem_stall;
  output reg FP_mult_stall;
  output reg FP_add_stall;
  output reg int_stall;
  //the output for the common data bus
  output reg [2:0] cdbus_d_select;
  output reg [7:0] cdbus_d_select_shift;
  output reg [7:0] cdbus_data;
  output reg cdbus_valid_data;
  output reg fake_mux_output_clock;
  
  //reg to count how many inputs we just got
  reg [7:0] how_many_inputs;
  
  initial begin
    how_many_inputs = 0;
    mem_stall = 0;
    FP_mult_stall = 0;
    FP_add_stall = 0;
    int_stall = 0;
    cdbus_valid_data = 0;
    fake_mux_output_clock = 0;
  end
  
  //deals with data collision/arbitration
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
      cdbus_data = 8'bz;
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
      $display("writing to common data bus: dest=%d, data=%b, valid_data=%b", cdbus_d_select, cdbus_data, cdbus_valid_data);
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
  //the fake clock from the reservation station
  input fake_clock;
  //the values from the reservation stations of load and store
  input [2:0] load_d_select;//d select
  input [7:0] load_d_select_shift;//d select shift
  input [11:0] load_address;//cache address (previously abus data)
  input [2:0] load_offset;//b code
  input [2:0] store_offset;//b code
  input [7:0] store_dbus_data;//dbus data
  input [11:0] store_address;//cache address (previously abus data)
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
  output reg [7:0] exec_dbus_data;
  output reg [11:0] exec_abus_address;
  output reg [2:0] exec_op_code;
  //counter for how many stations want to go
  reg [7:0] how_many_outputs;
  
  initial begin
    store_stall = 0;
    exec_d_select = 3'bz;
    exec_d_select_shift = 8'bz;
    exec_b_offset = 3'bz;
    exec_dbus_data = 8'bz;
    exec_abus_address = 12'bz;
    exec_op_code = 3'bz;
  end
  
  //handle mux selection/arbitration
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
        exec_dbus_data = 8'bz;
        exec_abus_address = 12'bz;
        exec_op_code = 3'bz;
      end
      else if(how_many_outputs == 1)begin
        $display("memory mux, one load/store reservation stations to output");
        store_stall = 0;
        if(valid_load_data > 0) begin
          //not matter
          exec_dbus_data = 8'b0;
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
        exec_dbus_data = 8'b0;
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
  input [7:0] dbus,//data in
  output [7:0] abusAdd,//data out
  output [7:0] abusInt,//data out
  output [7:0] abusMult,//data out
  output [7:0] abusLdSt,//data out
  output [7:0] bbusAdd,//data out
  output [7:0] bbusInt,//data out
  output [7:0] bbusMult,//data out
  output [7:0] bbusLdSt,//data out
  output [7:0] busyBus,//bus for each of the reg entries if it's busy or not
  input clk,
  input validData
  );
  //if it's requesting register 0 just output a 0
  assign abusAdd = AselectAdd[0] ? 8'b0 : 8'bz;
  assign bbusLdSt = BselectLdSt[0] ? 8'b0 : 8'bz;
  assign abusInt = AselectInt[0] ? 8'b0 : 8'bz;
  assign bbusAdd = BselectAdd[0] ? 8'b0 : 8'bz;
  assign abusLdSt = AselectLdSt[0] ? 8'b0 : 8'bz;
  assign bbusInt = BselectInt[0] ? 8'b0 : 8'bz;
  assign abusMult = AselectMult[0] ? 8'b0 : 8'bz;
  assign bbusMult = BselectMult[0] ? 8'b0 : 8'bz;
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
  dbus, abusAdd, abusInt, abusMult, abusLdSt, Dselect, BselectLdSt, BselectAdd, BselectInt, BselectMult, AselectAdd,
  AselectInt, AselectLdSt, AselectMult, bbusAdd, bbusInt, bbusMult, bbusLdSt, clk, busySelect, isBusy, validData
);
  input [7:0] dbus;
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
  output  [7:0] abusAdd;
  output  [7:0] abusInt;
  output  [7:0] abusMult;
  output  [7:0] abusLdSt;
  output  [7:0] bbusAdd;
  output  [7:0] bbusInt;
  output  [7:0] bbusMult;
  output  [7:0] bbusLdSt;
  reg [7:0] data;//the actual data for the register
  output reg isBusy;//TODO: make this a counter such that a load instruction can detect if it just checked out itself
  input validData;
  
  initial begin
  //start the registers empty
  data = 8'h00;
  isBusy = 0;
  end
  
  //at the change in this register for setting the dest register to be in use
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
  assign abusAdd = AselectAdd? data : 8'hzz;
  assign abusInt = AselectInt? data : 8'hzz;
  assign abusMult = AselectMult? data : 8'hzz;
  assign abusLdSt = AselectLdSt? data : 8'hzz;
  assign bbusAdd = BselectAdd? data : 8'hzz;
  assign bbusInt = BselectInt? data : 8'hzz;
  assign bbusMult = BselectMult? data : 8'hzz;
  assign bbusLdSt = BselectLdSt? data : 8'hzz;

endmodule
