/*************************
*  Willard Wider
*  04-07-18
*  ELEC3800
*  cache.v
*  building a cache
*************************/

module cache(clk,p0_request,p1_request,data_out, is_busy);

  //the clock
  input clk;
  
  //the request line:
  //processor id (1 bit)
  //load-store flag (1 bit) (0=load, 1=store)
  //the tag (11 bits)
  //the block offset (1 bits)
  //the data (if a store from processor to memory) (8 bits)
  input [21:0] p0_request, p1_request;
  
  //the data_out line:
  //the processor id (1 bit)
  //the request type (load/store) (1 bit)
  //the tag (11 bits)
  //the block offset (1 bits)
  //the data (if a load) (8 bits)
  output reg [21:0] data_out;
  
  //flag to say if the cache can accept a new instruction
  output reg is_busy;
  
  //wires for parsing the cache incomming info
  //make maybe?

  //the actual cache lines
  //first bracket is how wide each register is
  //second bracket is now many in the array
  //we want 16 cache lines that are 16 bits long
  reg [15:0] cache_line [15:0];
  
  //addresses for the cache lines
  //we want 16 tag lines that are 22 bits long
  reg [21:0] address_line [15:0];
  
  //valid bit for the cache lines
  //we want 16 valid bit lines that are 2 bits long
  //not needed for this assignment
  reg [1:0] valid_line [15:0];
  
  //last used counter
  //TODO
  
  //other stuff here
  //reg to use as a counter for traversing the lines
  reg [3:0] counter;
  //reg to count how many (0, 1 or 2) requests for the cache have been recieved
  reg [1:0] requests;
  //reg to use as the arbiter for which processor gets the cache, in case both want it as the same time
  reg arbiter;
  //previous entry of request to know if the request has changed
  reg [21:0] previous_p0_request, previous_p1_request;
  //represents the request to process
  reg [21:0] request_to_process;
  //the address line to use for checking and later writing/reading data
  reg [21:0] temp_address_line;
  //the wires for the tags of block 0 and 1
  reg [10:0] address_tag0, address_tag1, selected_tag;
  //the address and cache bounds used for which part in the line you want to get data for
  //wire [4:0] upper_address_bound, lower_address_bound, upper_data_bound, lower_data_bound;
  
  //the block offset wire. makes it easier to refrence
  reg block_offset;
  
  //wire assignments
  //assign block_offset = (request_to_process[8] >=0) ? request_to_process[8]:1'bz;
  
  //assign address_tag0 = (temp_address_line[21:11]>=11'b0)? temp_address_line[21:11]:11'bz;
  //assign address_tag1 = (temp_address_line[10:0]>=11'b0)? temp_address_line[10:0]:11'bz;
  //assign selected_tag = (block_offset>=0)? ((block_offset)? address_tag1:address_tag0):11'bz;
  
  //init block
  initial begin
    is_busy = 0;
    arbiter = 0;
    counter = 0;
    requests = 0;
    temp_address_line = 22'bz;
    previous_p0_request = 22'bz;
    previous_p1_request = 22'bz;
    request_to_process = 22'bz;
    address_tag0 = 11'bz;
    address_tag1 = 11'bz;
    selected_tag = 11'bz;
    block_offset = 1'bz;
    data_out = 22'bz;
    //set up the cache
    //first index is the entry in the array
    //second is the actual bus in said array
    cache_line[0] [15:0] = 16'b0110_0100__0000_0000;
    cache_line[1] [15:0] = 16'b0110_0101__1111_1111;
    cache_line[2] [15:0] = 16'b0110_0110__1111_1110;
    cache_line[3] [15:0] = 16'b0110_0111__1111_1101;
    cache_line[4] [15:0] = 16'b0110_1000__1111_1100;
    cache_line[5] [15:0] = 16'b0110_1001__1111_1011;
    cache_line[6] [15:0] = 16'b0110_1010__1111_1010;
    cache_line[7] [15:0] = 16'b0110_1011__1111_1001;
    cache_line[8] [15:0] = 16'b0110_1100__1111_1000;
    cache_line[9] [15:0] = 16'b0110_1101__1111_0111;
    cache_line[10] [15:0] = 16'b0110_1110__1111_0110;
    cache_line[11] [15:0] = 16'b0110_1111__1111_0101;
    cache_line[12] [15:0] = 16'b0111_0000__1111_0100;
    cache_line[13] [15:0] = 16'b0111_0001__1111_0011;
    cache_line[14] [15:0] = 16'b0111_0010__1111_0010;
    cache_line[15] [15:0] = 16'b0111_0011__1111_0001;
    
    address_line[0] [21:0] = 22'b0101_0000_000__0101_0000_000;
    address_line[1] [21:0] = 22'b0101_0001_000__0101_0001_000;
    address_line[2] [21:0] = 22'b0101_0010_000__0101_0010_000;
    address_line[3] [21:0] = 22'b0101_0011_000__0101_0011_000;
    address_line[4] [21:0] = 22'b0101_0100_000__0101_0100_000;
    address_line[5] [21:0] = 22'b0101_0101_000__0101_0101_000;
    address_line[6] [21:0] = 22'b0101_0110_000__0101_0110_000;
    address_line[7] [21:0] = 22'b0101_0111_000__0101_0111_000;
    address_line[8] [21:0] = 22'b0101_1000_000__0101_1000_000;
    address_line[9] [21:0] = 22'b0101_1001_000__0101_1001_000;
    address_line[10] [21:0] = 22'b0101_1010_000__0101_1010_000;
    address_line[11] [21:0] = 22'b0101_1011_000__0101_1011_000;
    address_line[12] [21:0] = 22'b0101_1100_000__0101_1100_000;
    address_line[13] [21:0] = 22'b0101_1101_000__0101_1101_000;
    address_line[14] [21:0] = 22'b0101_1110_000__0101_1110_000;
    address_line[15] [21:0] = 22'b0101_1111_000__0101_1111_000;
  end

  always@(posedge clk)begin
    counter = 0;
    requests = 0;
    temp_address_line = 21'bz;
    data_out = 22'bz;
    //needs to be changed such that:
    //process requests
    //if 2 of them, set busy flag and only do one of them
    //in thoery it will stop the processors from sending data
    //on next run through, it will set busy flag back to false and the 1 cycle gap is achieved
    //remember to disconnect the data line if no output
    //---
    //check if the request has been updated
    //also check to make sure the request line is not z
    if(p0_request >= 0)begin
      $display("CACHE: p0_request is valid (%b)",p0_request);
      //if((previous_p0_request>=0) || (previous_p0_request != p0_request))begin
        $display("CACHE: request from p0 is valid and new");
        requests[0] = 1;
        previous_p0_request = p0_request;
      //end
    end
    else begin
      $display("CACHE: p0_request is invalid (%b)",p0_request);
    end
    if(p1_request >= 0)begin
      $display("CACHE: p1_request is valid (%b)",p1_request);
      //if((previous_p1_request>=0) || (previous_p1_request != p1_request))begin
        $display("CACHE: request from p1 is valid and new");
        requests[1] = 1;
        previous_p1_request = p1_request;
      //end
    end
    else begin
      $display("CACHE: p1_request is invalid (%b)",p1_request);
    end
    //check to see how many requests we have
    //if 2, arbitate and set requests to 1, and set busy flag to high
    if(requests == 2'b11)begin
      $display("CACHE: new requests from p0 and p1, arbiting (arbiter = %b)",arbiter);
      is_busy = 1;
      request_to_process = arbiter? p1_request:p0_request;
      arbiter = ~arbiter;
    end
    //if 1, select the new one and set busy flag to low
    else if (requests == 2'b01)begin
      $display("CACHE: new request from p0");
      is_busy = 0;
      request_to_process = p0_request;
    end
    else if (requests == 2'b10)begin
      $display("CACHE: new request from p1");
      is_busy = 0;
      request_to_process = p1_request;
    end
    else if ((requests == 2'b00) && is_busy)begin
      $display("CACHE: processing second request due to busy signal");
      request_to_process = arbiter? previous_p1_request:previous_p0_request;
    end
    //if 0, don't do anything
    if(requests > 0 || is_busy)begin
      //actually handle the request now
      //request_to_process[21] = processor id
      //request_to_process[20] = load/store bit
      //request_to_process[19:9] = tag/address (11 bits)
      //request_to_process[8] = block offset (1 bits)
      //request_to_process[7:0] = data (8 bits)
      $display("CACHE: processing request (p_id=%b, load/store=%b, tag=%b, offset=%b, data=%b)",
      request_to_process[21],request_to_process[20],request_to_process[19:9],request_to_process[8],request_to_process[7:0]);
      //there are 16 lines, use a ternary with the block offset to specify which line (first half or second half) to search
      //match the tag first to address_line
      //reg [15:0] cache_line [15:0]; 16 bits long each data line
      //reg [21:0] address_line [15:0]; 22 bits long each tag/address line
      begin:tag_search_break;
        repeat(16)begin:tag_search_continue
          //block offset of 0 is the left(higher indexes), block offset of 1 is the right(lower indexes)
          //setting the temp address line reg will trigger the 3 tag wires above to select the correct tag to use
          //they can be made wires if need be
          temp_address_line = address_line[counter];
          //$display("DEBUG: temp_address_line=%b, address_line[%d]=%b",temp_address_line,counter,address_line[counter]);
          address_tag0 = temp_address_line[21:11];
          address_tag1 = temp_address_line[10:0];
          //$display("DEBUG: address_tag0=%b, address_tag1=%b",address_tag0,address_tag1);
          selected_tag = (block_offset)? address_tag1:address_tag0;
          block_offset = request_to_process[8];
          $display("CACHE: searching line %d, tag=%b, block_offset=%b,",counter,selected_tag,block_offset);
          if(request_to_process[19:9] == selected_tag)begin
            $display("CACHE: match found at line %d, saving counter location",counter);
            disable tag_search_break;
          end
          counter = counter+1;
        end//TODO: handle case of missing cache info
      end
      //the data_out line has the following:
      //the processor id (1 bit)
      //the request type (load/store) (1 bit)
      //the tag (11 bits)
      //the block offset (1 bits)
      //the data (if a load) (8 bits)
      case(request_to_process[20])
        1'b1: begin//store
          //write the data
          $display("CACHE: mode is store, writing data=%b and new address=%b (even tho address is same)",request_to_process[7:0],selected_tag);
          if(block_offset)begin
            cache_line[counter] [7:0] = request_to_process[7:0];
            //report on the data line
            data_out = {request_to_process[21],request_to_process[20],selected_tag,block_offset,cache_line[counter] [7:0]};
          end
          else begin
            cache_line[counter] [15:8] = request_to_process[7:0];
            //report on the data line
            data_out = {request_to_process[21],request_to_process[20],selected_tag,block_offset,cache_line[counter] [15:8]};
          end
        end
        1'b0: begin//load
          //load the data and report on the data line
          //https://www.nandland.com/verilog/examples/example-concatenation-operator.html
          if(block_offset)begin
            $display("CACHE: mode is load, loading data=%b to dataline from address %b",cache_line[counter] [7:0],selected_tag);
            data_out = {request_to_process[21],request_to_process[20],selected_tag,block_offset,cache_line[counter] [7:0]};
          end
          else begin
            $display("CACHE: mode is load, loading data=%b to dataline from address %b",cache_line[counter] [15:8],selected_tag);
            data_out = {request_to_process[21],request_to_process[20],selected_tag,block_offset,cache_line[counter] [15:8]};
          end
        end
      endcase
      //set busy back down so that the processors know they can send again
      if((requests == 2'b00) && is_busy)begin
        $display("CACHE: finished with second request from is_busy state, setting it back to false");
        is_busy =0;
      end
    end
    else begin
      $display("CACHE: 0 requesets, nothing to do, closing output");
      data_out = 22'bz;
    end
  end
endmodule